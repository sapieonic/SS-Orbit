package audit_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/reqctx"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"

	platformaudit "github.com/sapionic/orbit/backend/internal/platform/audit"
)

// Integration test against Postgres: write with platform/audit.Record (as
// every module does) and read back through the audit module.
func TestRecordAndRead(t *testing.T) {
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	m := audit.New(deps, &audit.Ports{})
	svc := m.Service()

	fa := testutil.FA()
	farmer := ids.New()
	plot := ids.New()
	faCtx := auth.WithOnBehalfOf(testutil.Ctx(fa), farmer)

	record := func(ctx context.Context, e platformaudit.Entry) {
		t.Helper()
		err := db.WithTx(ctx, pool, func(tx pgx.Tx) error {
			_, err := platformaudit.Record(ctx, tx, e)
			return err
		})
		require.NoError(t, err)
	}
	record(faCtx, platformaudit.Entry{Action: "farmers.enrolled", EntityType: "farmer", EntityID: farmer, FarmerID: farmer,
		After: map[string]any{"name": "Ravi"}})
	record(faCtx, platformaudit.Entry{Action: "farmers.plot_saved", EntityType: "plot", EntityID: plot, FarmerID: farmer, PlotID: plot,
		After: map[string]any{"area_acres": 2.5}})
	record(context.Background(), platformaudit.Entry{Action: "farmers.stage_updated", EntityType: "plot", EntityID: plot, FarmerID: farmer,
		Before: map[string]any{"stage": "seedling"}, After: map[string]any{"stage": "square"}})

	admin := testutil.Ctx(testutil.HO(auth.RoleAdmin))

	// Filter by farmer, newest first.
	page, err := svc.List(admin, audit.Filter{FarmerID: &farmer}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 3)
	assert.Equal(t, "farmers.stage_updated", page.Items[0].Action)
	assert.Equal(t, "system", page.Items[0].ActorKind, "no principal means a system actor")

	first := page.Items[2]
	assert.Equal(t, "farmers.enrolled", first.Action)
	assert.Equal(t, "fa", first.ActorKind)
	assert.Equal(t, fa.ID, *first.ActorID)
	assert.Equal(t, farmer, *first.OnBehalfOf)
	assert.Equal(t, fa.DeviceID.String(), *first.DeviceID)
	require.NotNil(t, first.IP)
	assert.Equal(t, "127.0.0.1", *first.IP)
	require.NotNil(t, first.RequestID)
	assert.JSONEq(t, `{"name":"Ravi"}`, string(first.After))
	assert.Nil(t, first.Before)

	// Action prefix and entity filters.
	prefix := "farmers.plot"
	page, err = svc.List(admin, audit.Filter{ActionPrefix: &prefix}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	typ := "farmer"
	page, err = svc.List(admin, audit.Filter{EntityType: &typ}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)

	// Time window excludes everything in the future.
	future := time.Now().Add(time.Hour)
	page, err = svc.List(admin, audit.Filter{From: &future}, nil, nil)
	require.NoError(t, err)
	assert.Empty(t, page.Items)

	// Keyset pagination walks every row exactly once.
	seen := map[uuid.UUID]bool{}
	var cursor *string
	one := 1
	for range 10 {
		page, err = svc.List(admin, audit.Filter{}, &one, cursor)
		require.NoError(t, err)
		for _, e := range page.Items {
			assert.False(t, seen[e.ID], "duplicate across pages")
			seen[e.ID] = true
		}
		if page.NextCursor == nil {
			break
		}
		cursor = page.NextCursor
	}
	assert.Len(t, seen, 3)

	// Chain for the plot, oldest first.
	chain, err := svc.Chain(admin, "plot", plot, nil, nil)
	require.NoError(t, err)
	require.Len(t, chain.Items, 2)
	assert.Equal(t, "farmers.plot_saved", chain.Items[0].Action)
	assert.Equal(t, "farmers.stage_updated", chain.Items[1].Action)
}

func TestAuditLogIsAppendOnly(t *testing.T) {
	pool := testutil.NewDB(t)
	ctx := reqctx.With(context.Background(), reqctx.Meta{RequestID: "r1"})
	var id uuid.UUID
	require.NoError(t, db.WithTx(ctx, pool, func(tx pgx.Tx) error {
		var err error
		id, err = platformaudit.Record(ctx, tx, platformaudit.Entry{Action: "test.done", EntityType: "test"})
		return err
	}))
	_, err := pool.Exec(ctx, `UPDATE audit_log SET action = 'x' WHERE id = $1`, id)
	require.ErrorContains(t, err, "append-only")
	_, err = pool.Exec(ctx, `DELETE FROM audit_log WHERE id = $1`, id)
	require.ErrorContains(t, err, "append-only")
}
