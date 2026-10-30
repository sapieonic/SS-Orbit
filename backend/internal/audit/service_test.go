package audit

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/audit/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// fakeQueries records the params it was called with and returns canned rows.
type fakeQueries struct {
	rows      []store.AuditLog
	listArgs  store.ListAuditEventsParams
	chainArgs store.ListEntityChainParams
}

func (f *fakeQueries) ListAuditEvents(_ context.Context, arg store.ListAuditEventsParams) ([]store.AuditLog, error) {
	f.listArgs = arg
	return limitRows(f.rows, arg.RowLimit), nil
}

func (f *fakeQueries) ListEntityChain(_ context.Context, arg store.ListEntityChainParams) ([]store.AuditLog, error) {
	f.chainArgs = arg
	return limitRows(f.rows, arg.RowLimit), nil
}

func limitRows(rows []store.AuditLog, n int32) []store.AuditLog {
	if int(n) < len(rows) {
		return rows[:n]
	}
	return rows
}

func sampleRows(n int) []store.AuditLog {
	base := time.Date(2026, 10, 1, 10, 0, 0, 0, time.UTC)
	out := make([]store.AuditLog, n)
	for i := range out {
		out[i] = store.AuditLog{
			ID: ids.New(), OccurredAt: base.Add(-time.Duration(i) * time.Minute),
			ActorKind: "ho", Action: "farmers.enrolled", EntityType: "farmer",
			EntityID: uuid.NullUUID{UUID: ids.New(), Valid: true},
		}
	}
	return out
}

func TestAuthorization(t *testing.T) {
	svc := NewService(&fakeQueries{}, nil)
	district := ids.New()
	cases := []struct {
		name string
		ctx  context.Context
		kind apperr.Kind // "" = allowed
	}{
		{"no principal", context.Background(), apperr.KindUnauthorized},
		{"admin", testutil.Ctx(testutil.HO(auth.RoleAdmin)), ""},
		{"finance", testutil.Ctx(testutil.HO(auth.RoleFinance)), ""},
		{"ops", testutil.Ctx(testutil.HO(auth.RoleOps)), ""},
		{"agronomy", testutil.Ctx(testutil.HO(auth.RoleAgronomy)), apperr.KindForbidden},
		{"area-scoped ops", testutil.Ctx(testutil.HO(auth.RoleOps, district)), apperr.KindForbidden},
		{"fa", testutil.Ctx(testutil.FA()), apperr.KindForbidden},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := svc.List(c.ctx, Filter{}, nil, nil)
			_, chainErr := svc.Chain(c.ctx, "farmer", ids.New(), nil, nil)
			if c.kind == "" {
				assert.NoError(t, err)
				assert.NoError(t, chainErr)
				return
			}
			assert.True(t, apperr.Is(err, c.kind), "list: got %v", err)
			assert.True(t, apperr.Is(chainErr, c.kind), "chain: got %v", chainErr)
		})
	}
}

func TestListPassesFiltersAndPaginates(t *testing.T) {
	fq := &fakeQueries{rows: sampleRows(5)}
	svc := NewService(fq, nil)
	ctx := testutil.Ctx(testutil.HO(auth.RoleAdmin))

	entity, actor := ids.New(), ids.New()
	from := time.Date(2026, 9, 1, 0, 0, 0, 0, time.FixedZone("IST", 5*3600+1800))
	typ, prefix := "farmer", "farmers."
	limit := 2
	page, err := svc.List(ctx, Filter{EntityType: &typ, EntityID: &entity, ActorID: &actor, ActionPrefix: &prefix, From: &from}, &limit, nil)
	require.NoError(t, err)

	assert.Equal(t, int32(3), fq.listArgs.RowLimit, "fetches limit+1")
	assert.Equal(t, uuid.NullUUID{UUID: entity, Valid: true}, fq.listArgs.EntityID)
	assert.Equal(t, uuid.NullUUID{UUID: actor, Valid: true}, fq.listArgs.ActorID)
	assert.False(t, fq.listArgs.FarmerID.Valid)
	assert.Equal(t, "farmers.", *fq.listArgs.ActionPrefix)
	assert.Equal(t, time.UTC, fq.listArgs.FromTime.Location(), "times are passed in UTC")
	assert.Nil(t, fq.listArgs.CursorAt, "first page has no cursor")

	require.Len(t, page.Items, 2)
	require.NotNil(t, page.NextCursor)
	cur, err := paging.Decode(page.NextCursor)
	require.NoError(t, err)
	assert.Equal(t, fq.rows[1].ID, cur.ID, "cursor points at the last returned row")

	// Next page passes the cursor through.
	_, err = svc.List(ctx, Filter{}, &limit, page.NextCursor)
	require.NoError(t, err)
	require.NotNil(t, fq.listArgs.CursorAt)
	assert.Equal(t, fq.rows[1].ID, fq.listArgs.CursorID.UUID)
}

func TestListValidation(t *testing.T) {
	svc := NewService(&fakeQueries{}, nil)
	ctx := testutil.Ctx(testutil.HO(auth.RoleOps))
	now := time.Now()
	_, err := svc.List(ctx, Filter{From: &now, To: &now}, nil, nil)
	assert.True(t, apperr.Is(err, apperr.KindValidation))

	bad := "not-a-cursor"
	_, err = svc.List(ctx, Filter{}, nil, &bad)
	e, ok := apperr.As(err)
	require.True(t, ok)
	assert.Equal(t, "invalid_cursor", e.Code)
}

func TestChainLastPage(t *testing.T) {
	fq := &fakeQueries{rows: sampleRows(3)}
	svc := NewService(fq, nil)
	entity := ids.New()
	page, err := svc.Chain(testutil.Ctx(testutil.HO(auth.RoleFinance)), "plot", entity, nil, nil)
	require.NoError(t, err)
	assert.Len(t, page.Items, 3)
	assert.Nil(t, page.NextCursor)
	assert.Equal(t, int32(chainDefaultLimit+1), fq.chainArgs.RowLimit)
	assert.Equal(t, "plot", fq.chainArgs.EntityType)
	assert.Equal(t, entity, fq.chainArgs.EntityID.UUID)
}
