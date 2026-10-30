package commands

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
)

type cancelVisit struct {
	VisitID uuid.UUID `json:"visit_id"`
	Reason  *string   `json:"reason"`
}

func TestDispatch(t *testing.T) {
	r := NewRegistry()
	visit := uuid.New()
	var seen auth.Principal
	r.Register("CancelVisit", Typed(func(_ context.Context, p auth.Principal, _ Command, in cancelVisit) (Result, error) {
		seen = p
		if in.VisitID == uuid.Nil {
			return Result{}, apperr.Validation("visit_id", "required")
		}
		return Applied(in.VisitID), nil
	}))
	r.Register("Boom", func(context.Context, auth.Principal, Command) (Result, error) {
		return Result{}, errors.New("db down")
	})
	assert.Equal(t, []string{"Boom", "CancelVisit"}, r.Types())

	fa := auth.Principal{Kind: auth.KindFA, ID: uuid.New()}
	ctx := context.Background()

	payload, _ := json.Marshal(cancelVisit{VisitID: visit})
	res, err := r.Dispatch(ctx, fa, Command{ID: uuid.New(), Type: "CancelVisit", Payload: payload})
	require.NoError(t, err)
	assert.Equal(t, Applied(visit), res)
	assert.Equal(t, fa, seen)

	res, err = r.Dispatch(ctx, fa, Command{Type: "CancelVisit", Payload: json.RawMessage(`{}`)})
	require.NoError(t, err)
	assert.Equal(t, StatusRejected, res.Status)
	assert.Contains(t, *res.Error, "visit_id")

	res, err = r.Dispatch(ctx, fa, Command{Type: "CancelVisit", Payload: json.RawMessage(`[1,2]`)})
	require.NoError(t, err)
	assert.Equal(t, StatusRejected, res.Status)

	res, err = r.Dispatch(ctx, fa, Command{Type: "Nope"})
	require.NoError(t, err)
	assert.Equal(t, StatusRejected, res.Status)

	_, err = r.Dispatch(ctx, fa, Command{Type: "Boom"})
	require.Error(t, err, "infrastructure errors pass through so sync can retry")
}

func TestRegisterDuplicatePanics(t *testing.T) {
	r := NewRegistry()
	h := func(context.Context, auth.Principal, Command) (Result, error) { return Result{}, nil }
	r.Register("X", h)
	assert.Panics(t, func() { r.Register("X", h) })
}

func TestResultJSON(t *testing.T) {
	into := uuid.MustParse("01900000-0000-7000-8000-000000000001")
	b, err := json.Marshal(Merged(uuid.MustParse("01900000-0000-7000-8000-000000000002"), into))
	require.NoError(t, err)
	assert.JSONEq(t, `{"status":"merged","entity_id":"01900000-0000-7000-8000-000000000002","merged_into":"01900000-0000-7000-8000-000000000001"}`, string(b))
}

type enrol struct {
	Name string            `json:"name"`
	Tags []string          `json:"tags"`
	Meta map[string]string `json:"meta"`
}

// Regression: a name containing \u0000 failed in Postgres (22021) on every
// retry and blocked the FA's queue. Typed must reject it before the handler.
func TestTypedRejectsNUL(t *testing.T) {
	r := NewRegistry()
	called := 0
	r.Register("EnrolFarmer", Typed(func(context.Context, auth.Principal, Command, enrol) (Result, error) {
		called++
		return Applied(uuid.New()), nil
	}))
	ctx := context.Background()
	fa := auth.Principal{Kind: auth.KindFA, ID: uuid.New()}
	for _, payload := range []string{
		`{"name":"Ra\u0000mu"}`,
		`{"name":"ok","tags":["a","b\u0000"]}`,
		`{"name":"ok","meta":{"k\u0000":"v"}}`,
	} {
		res, err := r.Dispatch(ctx, fa, Command{ID: uuid.New(), Type: "EnrolFarmer", Payload: json.RawMessage(payload)})
		require.NoError(t, err, payload)
		assert.Equal(t, StatusRejected, res.Status, payload)
		assert.Contains(t, *res.Error, "NUL", payload)
	}
	assert.Zero(t, called)

	// An escaped backslash followed by u0000 is not a NUL.
	res, err := r.Dispatch(ctx, fa, Command{ID: uuid.New(), Type: "EnrolFarmer", Payload: json.RawMessage(`{"name":"a\\u0000b"}`)})
	require.NoError(t, err)
	assert.Equal(t, StatusApplied, res.Status)
	assert.Equal(t, 1, called)
}

// Regression: Postgres data (22xxx) and constraint (23xxx) errors are the
// payload's fault and must become rejected results without SQL detail; other
// SQLSTATEs (e.g. 40001, 57P01) stay infrastructure errors.
func TestDispatchMapsPgDataErrors(t *testing.T) {
	ctx := context.Background()
	fa := auth.Principal{Kind: auth.KindFA, ID: uuid.New()}
	cases := []struct {
		code     string
		rejected bool
	}{
		{"22021", true}, {"22P02", true}, {"22003", true},
		{"23505", true}, {"23503", true}, {"23514", true}, {"23502", true},
		{"40001", false}, {"57P01", false}, {"08006", false},
	}
	for _, c := range cases {
		r := NewRegistry()
		r.Register("X", func(context.Context, auth.Principal, Command) (Result, error) {
			return Result{EntityID: uuid.Nil}, fmt.Errorf("insert farmer: %w", &pgconn.PgError{
				Code: c.code, Message: "secret detail", ConstraintName: "farmers_phone_key",
			})
		})
		res, err := r.Dispatch(ctx, fa, Command{ID: uuid.New(), Type: "X"})
		if !c.rejected {
			require.Error(t, err, c.code)
			continue
		}
		require.NoError(t, err, c.code)
		assert.Equal(t, StatusRejected, res.Status, c.code)
		assert.NotContains(t, *res.Error, "secret", c.code)
		assert.NotContains(t, *res.Error, "farmers_phone_key", c.code)
	}
}
