package sync

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// Regression: a command that failed on the server every time returned
// {results:[], retry_from:0} forever and the commands queued behind it never
// ran. After MaxCommandAttempts failures it is stored as rejected and the
// batch moves on.
func TestSubmitBatchDeadLettersAfterRepeatedFailures(t *testing.T) {
	e := newEnv(t, nil)
	calls := newCounter()
	registerFakeHandlers(e, calls, ids.New())
	e.deps.Commands.Register("Broken", func(_ context.Context, _ auth.Principal, c commands.Command) (commands.Result, error) {
		calls.inc(c.ID.String())
		return commands.Result{}, errors.New("insert farmer: connection reset")
	})

	batch := []commands.Command{cmd(t, "Broken", ids.New()), cmd(t, "Apply", ids.New())}
	for attempt := 1; attempt < MaxCommandAttempts; attempt++ {
		res, err := e.svc.SubmitBatch(e.ctx(), batch)
		require.NoError(t, err)
		require.NotNil(t, res.RetryFrom, "attempt %d", attempt)
		assert.Equal(t, 0, *res.RetryFrom)
		assert.Empty(t, res.Outcomes)
		assert.Equal(t, 0, calls.get(batch[1].ID.String()), "commands behind the failing one wait")
	}
	assert.Equal(t, 0, e.countCommands(t))

	res, err := e.svc.SubmitBatch(e.ctx(), batch)
	require.NoError(t, err)
	assert.Nil(t, res.RetryFrom)
	require.Len(t, res.Outcomes, 2)
	assert.Equal(t, commands.StatusRejected, res.Outcomes[0].Result.Status)
	require.NotNil(t, res.Outcomes[0].Result.Error)
	assert.Equal(t, ReasonServerCouldNotApply, *res.Outcomes[0].Result.Error)
	assert.Equal(t, commands.StatusApplied, res.Outcomes[1].Result.Status, "the queue moved on")
	assert.Equal(t, MaxCommandAttempts, calls.get(batch[0].ID.String()))
	assert.Equal(t, 1, e.identity.count())

	// A resend is answered from the store; the broken handler is not called again.
	again, err := e.svc.SubmitBatch(e.ctx(), batch)
	require.NoError(t, err)
	assert.Equal(t, res.Outcomes, again.Outcomes)
	assert.Equal(t, MaxCommandAttempts, calls.get(batch[0].ID.String()))

	// HO sees it in the admin list, with the attempts and the server error.
	page, err := e.svc.ListCommands(testutil.Ctx(testutil.HO(auth.RoleOps)), Filter{Status: ptr(commands.StatusRejected)}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	got := page.Items[0]
	assert.Equal(t, batch[0].ID, got.ID)
	require.NotNil(t, got.FailedAttempts)
	assert.Equal(t, int32(MaxCommandAttempts), *got.FailedAttempts)
	require.NotNil(t, got.LastError)
	assert.Contains(t, *got.LastError, "connection reset")
}

// A command that failed a few times and then went through is applied
// normally; the failure count stays visible to HO.
func TestSubmitBatchRecoversBeforeDeadLetter(t *testing.T) {
	e := newEnv(t, nil)
	failing := true
	e.deps.Commands.Register("Flaky", func(context.Context, auth.Principal, commands.Command) (commands.Result, error) {
		if failing {
			return commands.Result{}, errors.New("timeout")
		}
		return commands.Applied(ids.New()), nil
	})
	c := cmd(t, "Flaky", ids.New())
	for range MaxCommandAttempts - 1 {
		res, err := e.svc.SubmitBatch(e.ctx(), []commands.Command{c})
		require.NoError(t, err)
		require.NotNil(t, res.RetryFrom)
	}
	failing = false
	res, err := e.svc.SubmitBatch(e.ctx(), []commands.Command{c})
	require.NoError(t, err)
	require.Len(t, res.Outcomes, 1)
	assert.Equal(t, commands.StatusApplied, res.Outcomes[0].Result.Status)

	page, err := e.svc.ListCommands(testutil.Ctx(testutil.HO(auth.RoleAdmin)), Filter{}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	require.NotNil(t, page.Items[0].FailedAttempts)
	assert.Equal(t, int32(MaxCommandAttempts-1), *page.Items[0].FailedAttempts)
}

func TestPruneCommands(t *testing.T) {
	e := newEnv(t, nil)
	ctx := context.Background()
	now := e.deps.Clock.Now()
	insert := func(status string, age time.Duration) {
		_, err := e.pool.Exec(ctx, `INSERT INTO sync_commands (id, fa_id, type, payload, status, result, received_at)
			VALUES ($1, $2, 'X', '{}', $3, '{}', $4)`, ids.New(), e.fa.ID, status, now.Add(-age))
		require.NoError(t, err)
	}
	day := 24 * time.Hour
	insert("applied", 181*day) // deleted
	insert("merged", 200*day)  // deleted
	insert("applied", 170*day) // kept
	insert("rejected", 200*day)
	insert("conflict", 300*day)
	insert("rejected", 366*day) // deleted
	insert("conflict", 400*day) // deleted

	n, err := e.svc.PruneCommands(ctx)
	require.NoError(t, err)
	assert.Equal(t, int64(4), n)
	assert.Equal(t, 3, e.countCommands(t))
}

func ptr[T any](v T) *T { return &v }

// Regression: a payload with a \u0000 escape was rejected by the handler, but
// storing it failed (jsonb refuses NUL, SQLSTATE 22P05), so the batch stopped
// with retry_from on every resend. The stored copy swaps NUL for U+FFFD.
func TestSubmitBatchStoresPayloadWithNUL(t *testing.T) {
	e := newEnv(t, nil)
	calls := newCounter()
	registerFakeHandlers(e, calls, ids.New())
	e.deps.Commands.Register("Named", commands.Typed(func(context.Context, auth.Principal, commands.Command, struct {
		Name string `json:"name"`
	}) (commands.Result, error) {
		return commands.Applied(ids.New()), nil
	}))

	bad := cmd(t, "Named", ids.New())
	bad.Payload = []byte(`{"name":"Bad\u0000Name"}`)
	batch := []commands.Command{bad, cmd(t, "Apply", ids.New())}

	res, err := e.svc.SubmitBatch(e.ctx(), batch)
	require.NoError(t, err)
	assert.Nil(t, res.RetryFrom)
	assert.Equal(t, []commands.Status{commands.StatusRejected, commands.StatusApplied}, statuses(res))
	assert.Equal(t, 2, e.countCommands(t))

	again, err := e.svc.SubmitBatch(e.ctx(), batch)
	require.NoError(t, err)
	assert.Equal(t, res.Outcomes, again.Outcomes, "a resend is answered from the store")
}
