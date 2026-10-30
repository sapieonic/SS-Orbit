package sync

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

type entityPayload struct {
	EntityID uuid.UUID `json:"entity_id"`
}

// registerFakeHandlers registers one handler per outcome. Every call is
// counted by command ID. "Apply" bumps the FA's territory like a real write.
func registerFakeHandlers(e *env, calls *counter, mergedInto uuid.UUID) {
	reg := e.deps.Commands
	reg.Register("Apply", commands.Typed(func(ctx context.Context, p auth.Principal, cmd commands.Command, pl entityPayload) (commands.Result, error) {
		calls.inc(cmd.ID.String())
		if err := db.WithTx(ctx, e.pool, func(tx pgx.Tx) error { return territory.Bump(ctx, tx, p.ID) }); err != nil {
			return commands.Result{}, err
		}
		return commands.Applied(pl.EntityID), nil
	}))
	reg.Register("Merge", commands.Typed(func(_ context.Context, _ auth.Principal, cmd commands.Command, pl entityPayload) (commands.Result, error) {
		calls.inc(cmd.ID.String())
		return commands.Merged(pl.EntityID, mergedInto), nil
	}))
	reg.Register("Conflict", commands.Typed(func(_ context.Context, _ auth.Principal, cmd commands.Command, pl entityPayload) (commands.Result, error) {
		calls.inc(cmd.ID.String())
		return commands.Conflicted(pl.EntityID, commands.Conflict{Field: "area_acres", Yours: 1.75, Theirs: 2.0}), nil
	}))
	reg.Register("Invalid", func(_ context.Context, _ auth.Principal, cmd commands.Command) (commands.Result, error) {
		calls.inc(cmd.ID.String())
		return commands.Result{}, apperr.Validation("phone", "is not a valid mobile number")
	})
}

func cmd(t *testing.T, typ string, entity uuid.UUID) commands.Command {
	at := time.Date(2026, 10, 29, 11, 2, 0, 0, time.UTC)
	return commands.Command{ID: ids.New(), Type: typ, Payload: mustJSON(t, entityPayload{EntityID: entity}), ClientCreatedAt: &at}
}

func statuses(r BatchResult) []commands.Status {
	out := make([]commands.Status, len(r.Outcomes))
	for i, o := range r.Outcomes {
		out[i] = o.Result.Status
	}
	return out
}

func TestSubmitBatchMixedResultsAndIdempotentRetry(t *testing.T) {
	e := newEnv(t, nil)
	calls := newCounter()
	into := ids.New()
	registerFakeHandlers(e, calls, into)

	ent := []uuid.UUID{ids.New(), ids.New(), ids.New(), ids.New(), ids.New()}
	batch := []commands.Command{
		cmd(t, "Apply", ent[0]),
		cmd(t, "Merge", ent[1]),
		cmd(t, "Conflict", ent[2]),
		cmd(t, "Invalid", ent[3]),
		cmd(t, "NoSuchCommand", ent[4]),
	}

	res, err := e.svc.SubmitBatch(e.ctx(), batch)
	require.NoError(t, err)
	assert.Nil(t, res.RetryFrom)
	assert.Equal(t, []commands.Status{commands.StatusApplied, commands.StatusMerged, commands.StatusConflict,
		commands.StatusRejected, commands.StatusRejected}, statuses(res))
	assert.Equal(t, Versions{Territory: 1, Masters: 7}, res.Versions, "read after the batch: Apply bumped once")
	assert.Equal(t, ent[0], res.Outcomes[0].Result.EntityID)
	assert.Equal(t, &into, res.Outcomes[1].Result.MergedInto)
	require.NotNil(t, res.Outcomes[2].Result.Conflict)
	assert.Equal(t, "area_acres", res.Outcomes[2].Result.Conflict.Field)
	require.NotNil(t, res.Outcomes[3].Result.Error)
	assert.Contains(t, *res.Outcomes[4].Result.Error, "unknown command type")
	assert.Equal(t, 5, e.countCommands(t), "every outcome is stored, rejections included")
	assert.Equal(t, 1, e.identity.count())
	assert.Equal(t, e.fa.DeviceID, e.identity.calls[0].DeviceID)

	// Stored row carries device, status and the client time.
	var dev uuid.UUID
	var status string
	var clientAt time.Time
	require.NoError(t, e.pool.QueryRow(context.Background(),
		`SELECT device_id, status, client_created_at FROM sync_commands WHERE id = $1`, batch[2].ID).Scan(&dev, &status, &clientAt))
	assert.Equal(t, e.fa.DeviceID, dev)
	assert.Equal(t, "conflict", status)
	assert.True(t, clientAt.Equal(*batch[2].ClientCreatedAt))

	// The phone did not get the response and resends the whole batch: stored
	// results come back, nothing is dispatched again.
	again, err := e.svc.SubmitBatch(e.ctx(), batch)
	require.NoError(t, err)
	assert.Equal(t, res.Outcomes, again.Outcomes)
	for _, c := range batch[:4] {
		assert.Equal(t, 1, calls.get(c.ID.String()), "command %s dispatched again", c.Type)
	}
	assert.Equal(t, int64(1), again.Versions.Territory, "replay wrote nothing")
	assert.Equal(t, 5, e.countCommands(t))
	assert.Equal(t, 2, e.identity.count())
}

func TestSubmitBatchInfraErrorStopsBatch(t *testing.T) {
	e := newEnv(t, nil)
	calls := newCounter()
	registerFakeHandlers(e, calls, ids.New())
	failing := true
	e.deps.Commands.Register("Flaky", func(_ context.Context, _ auth.Principal, c commands.Command) (commands.Result, error) {
		calls.inc(c.ID.String())
		if failing {
			return commands.Result{}, errors.New("connection reset by peer")
		}
		return commands.Applied(ids.New()), nil
	})

	batch := []commands.Command{cmd(t, "Apply", ids.New()), cmd(t, "Flaky", ids.New()), cmd(t, "Apply", ids.New())}
	res, err := e.svc.SubmitBatch(e.ctx(), batch)
	require.NoError(t, err)
	require.NotNil(t, res.RetryFrom)
	assert.Equal(t, 1, *res.RetryFrom)
	assert.Equal(t, []commands.Status{commands.StatusApplied}, statuses(res))
	assert.Equal(t, 0, calls.get(batch[2].ID.String()), "commands after the failure are not run")
	assert.Equal(t, 1, e.countCommands(t), "nothing stored for the failed command")
	assert.Equal(t, int64(1), res.Versions.Territory)
	assert.Equal(t, 0, e.identity.count(), "an incomplete batch is not a sync")

	// Later the phone resends from retry_from (here: the whole batch, which
	// must also work).
	failing = false
	res, err = e.svc.SubmitBatch(e.ctx(), batch)
	require.NoError(t, err)
	assert.Nil(t, res.RetryFrom)
	assert.Equal(t, []commands.Status{commands.StatusApplied, commands.StatusApplied, commands.StatusApplied}, statuses(res))
	assert.Equal(t, 1, calls.get(batch[0].ID.String()), "first command answered from the store")
	assert.Equal(t, 2, calls.get(batch[1].ID.String()))
	assert.Equal(t, 3, e.countCommands(t))
	assert.Equal(t, 1, e.identity.count())
}

func TestSubmitBatchInvalidHandlerStatusIsInfraError(t *testing.T) {
	e := newEnv(t, nil)
	e.deps.Commands.Register("Buggy", func(context.Context, auth.Principal, commands.Command) (commands.Result, error) {
		return commands.Result{}, nil // empty status
	})
	res, err := e.svc.SubmitBatch(e.ctx(), []commands.Command{cmd(t, "Buggy", ids.New())})
	require.NoError(t, err)
	require.NotNil(t, res.RetryFrom)
	assert.Equal(t, 0, *res.RetryFrom)
	assert.Empty(t, res.Outcomes)
	assert.Equal(t, 0, e.countCommands(t))
}

func TestSubmitBatchCommandIDOfAnotherFA(t *testing.T) {
	e := newEnv(t, nil)
	calls := newCounter()
	registerFakeHandlers(e, calls, ids.New())

	c := cmd(t, "Apply", ids.New())
	_, err := e.svc.SubmitBatch(e.ctx(), []commands.Command{c})
	require.NoError(t, err)

	other := e.newFA(t)
	res, err := e.svc.SubmitBatch(testutil.Ctx(other), []commands.Command{c})
	require.NoError(t, err)
	require.Len(t, res.Outcomes, 1)
	assert.Equal(t, commands.StatusRejected, res.Outcomes[0].Result.Status)
	assert.Equal(t, uuid.Nil, res.Outcomes[0].Result.EntityID, "nothing about the owner's entity leaks")
	assert.Equal(t, 1, calls.get(c.ID.String()))

	var owner uuid.UUID
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT fa_id FROM sync_commands WHERE id = $1`, c.ID).Scan(&owner))
	assert.Equal(t, e.fa.ID, owner)
}

func TestSubmitBatchDuplicateIDInOneBatch(t *testing.T) {
	e := newEnv(t, nil)
	calls := newCounter()
	registerFakeHandlers(e, calls, ids.New())
	c := cmd(t, "Apply", ids.New())

	res, err := e.svc.SubmitBatch(e.ctx(), []commands.Command{c, c})
	require.NoError(t, err)
	require.Len(t, res.Outcomes, 2)
	assert.Equal(t, res.Outcomes[0], res.Outcomes[1])
	assert.Equal(t, 1, calls.get(c.ID.String()))
}

// The phone retries while the first request is still running: both requests
// are inside the handler at once. The first insert wins; the other request
// returns the stored result even though its own dispatch said something else.
func TestSubmitBatchConcurrentDuplicate(t *testing.T) {
	e := newEnv(t, nil)
	entity := ids.New()
	arrived := make(chan struct{}, 2)
	release := make(chan struct{})
	var calls atomic.Int32
	e.deps.Commands.Register("Slow", func(_ context.Context, _ auth.Principal, c commands.Command) (commands.Result, error) {
		arrived <- struct{}{}
		<-release
		if calls.Add(1) == 1 {
			return commands.Applied(entity), nil
		}
		// A replay the handler recognises as already done.
		return commands.Merged(entity, entity), nil
	})

	c := cmd(t, "Slow", entity)
	type out struct {
		res BatchResult
		err error
	}
	results := make(chan out, 2)
	for range 2 {
		go func() {
			r, err := e.svc.SubmitBatch(e.ctx(), []commands.Command{c})
			results <- out{r, err}
		}()
	}
	for range 2 {
		select {
		case <-arrived:
		case <-time.After(10 * time.Second):
			t.Fatal("both requests should reach the handler")
		}
	}
	close(release)
	a, b := <-results, <-results
	require.NoError(t, a.err)
	require.NoError(t, b.err)
	require.Len(t, a.res.Outcomes, 1)
	require.Len(t, b.res.Outcomes, 1)
	assert.Equal(t, a.res.Outcomes[0], b.res.Outcomes[0], "both requests answer with the stored row")
	assert.Equal(t, 1, e.countCommands(t))
}

func TestSubmitBatchRequiresFA(t *testing.T) {
	e := newEnv(t, nil)
	_, err := e.svc.SubmitBatch(testutil.Ctx(testutil.HO(auth.RoleAdmin)), []commands.Command{cmd(t, "Apply", ids.New())})
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "%v", err)
}

func cmds(t *testing.T, types ...string) []commands.Command {
	out := make([]commands.Command, len(types))
	for i, typ := range types {
		out[i] = cmd(t, typ, ids.New())
	}
	return out
}
