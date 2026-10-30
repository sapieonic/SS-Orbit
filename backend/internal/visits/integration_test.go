package visits

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

func TestPhotoUpload(t *testing.T) {
	w := newWorld(t)
	visit := ids.New()
	p := w.logPayload(visit)
	photo := p["photos"].([]map[string]any)[0]["photo_id"].(uuid.UUID)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdLogVisit, p).Status)

	faCtx := testutil.Ctx(w.fa1)
	_, err := w.svc.PresignPhotoUpload(testutil.Ctx(w.fa2), visit, photo, "image/jpeg", 1000)
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "another FA: %v", err)
	_, err = w.svc.PresignPhotoUpload(faCtx, visit, photo, "image/png", 1000)
	assert.True(t, apperr.Is(err, apperr.KindValidation), "type differs from the log: %v", err)
	_, err = w.svc.PresignPhotoUpload(faCtx, visit, ids.New(), "image/jpeg", 1000)
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	up, err := w.svc.PresignPhotoUpload(faCtx, visit, photo, "image/jpeg", 2048)
	require.NoError(t, err)
	assert.Equal(t, "PUT", up.Method)
	assert.Equal(t, "image/jpeg", up.Headers["Content-Type"])
	assert.True(t, strings.HasSuffix(up.StorageKey, ".jpg"))

	_, err = w.svc.ConfirmPhotoUpload(faCtx, visit, photo, nil)
	e, ok := apperr.As(err)
	require.True(t, ok, "%v", err)
	assert.Equal(t, "upload_missing", e.Code)

	require.NoError(t, w.deps.Storage.Put(context.Background(), up.StorageKey, "image/jpeg", strings.NewReader("jpeg")))
	sha := strings.Repeat("a", 64)
	ph, err := w.svc.ConfirmPhotoUpload(faCtx, visit, photo, &sha)
	require.NoError(t, err)
	require.NotNil(t, ph.UploadedAt)
	assert.Equal(t, int32(2048), *ph.Bytes)
	again, err := w.svc.ConfirmPhotoUpload(faCtx, visit, photo, nil)
	require.NoError(t, err)
	assert.Equal(t, ph.UploadedAt, again.UploadedAt, "idempotent")

	_, err = w.svc.PresignPhotoUpload(faCtx, visit, photo, "image/jpeg", 2048)
	assert.True(t, apperr.Is(err, apperr.KindConflict), "already uploaded")

	d, err := w.svc.Get(testutil.Ctx(testutil.HO(auth.RoleAgronomy)), visit)
	require.NoError(t, err)
	require.Len(t, d.Photos, 1)
	require.NotNil(t, d.Photos[0].URL)
	assert.Contains(t, *d.Photos[0].URL, up.StorageKey)
	assert.Equal(t, "Suresh K", *d.Visit.FAName)
	assert.Len(t, d.Visit.Issues, 2)
}

func TestFarmerApp(t *testing.T) {
	w := newWorld(t)
	farmerCtx := testutil.Ctx(farmerPrincipal(w.farmer1))

	nv, err := w.svc.MyNextVisit(farmerCtx)
	require.NoError(t, err)
	assert.Nil(t, nv)

	// Two logged visits and a plan for next week.
	first := w.logPayload(ids.New())
	first["visited_at"] = now.Add(-72 * time.Hour).Format(time.RFC3339)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdLogVisit, first).Status)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdLogVisit, w.logPayload(ids.New())).Status)
	planned := ids.New()
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdPlanVisit, w.planPayload(planned, "2026-11-05")).Status)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdPlanVisit, w.planPayload(ids.New(), "2026-11-09")).Status)

	nv, err = w.svc.MyNextVisit(farmerCtx)
	require.NoError(t, err)
	require.NotNil(t, nv)
	assert.Equal(t, planned, nv.VisitID)
	assert.Equal(t, "Suresh K", nv.FA.Name)

	one := 1
	page, err := w.svc.MyVisits(farmerCtx, &one, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	require.NotNil(t, page.NextCursor)
	latest := page.Items[0]
	assert.True(t, latest.VisitedAt.After(now.Add(-2*time.Hour)), "newest first")
	require.Len(t, latest.Issues, 2)
	for _, is := range latest.Issues {
		if is.Advice.SaltOnly() {
			assert.Nil(t, is.Advice.ProductName, "salt only: no brand")
		} else {
			assert.Equal(t, "శాంపిల్ 5 SG", *is.Advice.ProductNameTe)
		}
	}
	page, err = w.svc.MyVisits(farmerCtx, &one, page.NextCursor)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	assert.Nil(t, page.NextCursor)

	// Another farmer sees none of it.
	other, err := w.svc.MyVisits(testutil.Ctx(farmerPrincipal(w.farmer2)), nil, nil)
	require.NoError(t, err)
	assert.Empty(t, other.Items)

	t.Run("call-back", func(t *testing.T) {
		v0 := w.version(w.fa1.ID)
		cb, created, err := w.svc.RequestCallback(farmerCtx)
		require.NoError(t, err)
		assert.True(t, created)
		assert.Equal(t, w.fa1.ID, cb.FAID)
		assert.Greater(t, w.version(w.fa1.ID), v0)
		assert.Equal(t, 1, w.count(`SELECT count(*) FROM river_job WHERE args->>'name' = 'callback.requested'`))

		again, created, err := w.svc.RequestCallback(farmerCtx)
		require.NoError(t, err)
		assert.False(t, created, "one open at a time")
		assert.Equal(t, cb.ID, again.ID)

		open, err := w.svc.MyOpenCallback(farmerCtx)
		require.NoError(t, err)
		require.NotNil(t, open)

		_, err = w.svc.CancelMyCallback(testutil.Ctx(farmerPrincipal(w.farmer2)), cb.ID)
		assert.True(t, apperr.Is(err, apperr.KindNotFound), "not your request")
		c, err := w.svc.CancelMyCallback(farmerCtx, cb.ID)
		require.NoError(t, err)
		assert.Equal(t, CallbackCancelled, c.Status)
		_, err = w.svc.CancelMyCallback(farmerCtx, cb.ID)
		require.NoError(t, err, "idempotent")
		open, err = w.svc.MyOpenCallback(farmerCtx)
		require.NoError(t, err)
		assert.Nil(t, open)

		w.farmers.assign(w.farmer2, uuid.Nil)
		_, _, err = w.svc.RequestCallback(testutil.Ctx(farmerPrincipal(w.farmer2)))
		e, ok := apperr.As(err)
		require.True(t, ok)
		assert.Equal(t, "no_fa_assigned", e.Code)
	})
}

func TestMissedJobAndAdmin(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	old, today, logged := ids.New(), ids.New(), ids.New()
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdPlanVisit, w.planPayload(old, "2026-10-28")).Status)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdPlanVisit, w.planPayload(today, "2026-10-30")).Status)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdLogVisit, w.logPayload(logged)).Status)

	ops := testutil.Ctx(testutil.HO(auth.RoleOps))
	overdue, err := w.svc.Overdue(ops, nil, nil, nil)
	require.NoError(t, err)
	require.Len(t, overdue.Items, 1, "planned in the past shows before the job runs")
	assert.Equal(t, old, overdue.Items[0].ID)

	v0 := w.version(w.fa1.ID)
	n, err := w.svc.MarkMissed(ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, n, "only visits before today (IST)")
	assert.Greater(t, w.version(w.fa1.ID), v0)
	n, err = w.svc.MarkMissed(ctx)
	require.NoError(t, err)
	assert.Equal(t, 0, n, "idempotent")

	// Just after IST midnight the visit planned for the 30th is missed too.
	w.clock.Set(time.Date(2026, 10, 30, 18, 31, 0, 0, time.UTC))
	n, err = w.svc.MarkMissed(ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, n)
	overdue, err = w.svc.Overdue(ops, &w.fa1.ID, nil, nil)
	require.NoError(t, err)
	require.Len(t, overdue.Items, 2)
	assert.Equal(t, today, overdue.Items[0].ID, "most recent day first")

	from, to := time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 10, 31, 0, 0, 0, 0, time.UTC)
	counts, err := w.svc.Counts(testutil.Ctx(testutil.HO(auth.RoleFinance)), from, to, CountsFilter{})
	require.NoError(t, err)
	require.Len(t, counts.Items, 1)
	c := counts.Items[0]
	assert.Equal(t, FACounts{FAID: w.fa1.ID, FAName: c.FAName, Planned: 2, Done: 1, Missed: 2, FarmersVisited: 1}, c)
	assert.Equal(t, "Suresh K", *c.FAName)

	sample, err := w.svc.Sample(testutil.Ctx(testutil.HO(auth.RoleAgronomy)), from, to, nil, nil)
	require.NoError(t, err)
	require.Len(t, sample.Items, 1)
	assert.Equal(t, logged, sample.Items[0].ID)
	assert.Equal(t, 1, w.count(`SELECT count(*) FROM audit_log WHERE action = 'visits.sample_drawn'`))

	// List: filters and keyset pagination.
	status := StatusMissed
	page, err := w.svc.List(ops, ListFilter{Status: &status}, nil, nil)
	require.NoError(t, err)
	assert.Len(t, page.Items, 2)
	day := time.Date(2026, 10, 28, 0, 0, 0, 0, time.UTC)
	page, err = w.svc.List(ops, ListFilter{From: &day, To: &day}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	assert.Equal(t, old, page.Items[0].ID)

	// Area scope: a user of the farmers' district sees their visits; a user of
	// another district sees none and gets not found on the detail.
	mine := testutil.Ctx(testutil.HO(auth.RoleOps, w.district))
	other := testutil.Ctx(testutil.HO(auth.RoleOps, ids.New()))
	page, err = w.svc.List(mine, ListFilter{}, nil, nil)
	require.NoError(t, err)
	assert.Len(t, page.Items, 3)
	page, err = w.svc.List(other, ListFilter{}, nil, nil)
	require.NoError(t, err)
	assert.Empty(t, page.Items)
	_, err = w.svc.Get(mine, logged)
	require.NoError(t, err)
	_, err = w.svc.Get(other, logged)
	assert.True(t, apperr.Is(err, apperr.KindNotFound))
	overdue, err = w.svc.Overdue(other, nil, nil, nil)
	require.NoError(t, err)
	assert.Empty(t, overdue.Items)
	counts, err = w.svc.Counts(testutil.Ctx(testutil.HO(auth.RoleFinance, w.district)), from, to, CountsFilter{})
	require.NoError(t, err)
	assert.Len(t, counts.Items, 1)
	counts, err = w.svc.Counts(testutil.Ctx(testutil.HO(auth.RoleFinance, ids.New())), from, to, CountsFilter{})
	require.NoError(t, err)
	assert.Empty(t, counts.Items)
	sample, err = w.svc.Sample(other, from, to, nil, nil)
	require.NoError(t, err)
	assert.Empty(t, sample.Items)

	seen := map[uuid.UUID]bool{}
	var cursor *string
	one := 1
	for range 10 {
		page, err = w.svc.List(ops, ListFilter{FAID: &w.fa1.ID}, &one, cursor)
		require.NoError(t, err)
		for _, v := range page.Items {
			assert.False(t, seen[v.ID])
			seen[v.ID] = true
		}
		if cursor = page.NextCursor; cursor == nil {
			break
		}
	}
	assert.Len(t, seen, 3)
}

func TestReassignment(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	planned, logged := ids.New(), ids.New()
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdPlanVisit, w.planPayload(planned, "2026-11-04")).Status)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdLogVisit, w.logPayload(logged)).Status)
	cb, _, err := w.svc.RequestCallback(testutil.Ctx(farmerPrincipal(w.farmer1)))
	require.NoError(t, err)

	v1, v2 := w.version(w.fa1.ID), w.version(w.fa2.ID)
	e := events.FarmersReassigned{FarmerIDs: []uuid.UUID{w.farmer1}, FromFAID: &w.fa1.ID, ToFAID: w.fa2.ID}
	require.NoError(t, w.svc.onFarmersReassigned(ctx, e))
	assert.Greater(t, w.version(w.fa1.ID), v1)
	assert.Greater(t, w.version(w.fa2.ID), v2)

	moved, err := w.svc.read().GetVisit(ctx, planned)
	require.NoError(t, err)
	assert.Equal(t, w.fa2.ID, moved.FaID)
	kept, err := w.svc.read().GetVisit(ctx, logged)
	require.NoError(t, err)
	assert.Equal(t, w.fa1.ID, kept.FaID, "logged visits stay with the FA who made them")
	assert.Equal(t, 1, w.count(`SELECT count(*) FROM callback_requests WHERE id = $1 AND fa_id = $2`, cb.ID, w.fa2.ID))

	v2 = w.version(w.fa2.ID)
	require.NoError(t, w.svc.onFarmersReassigned(ctx, e))
	assert.Equal(t, v2, w.version(w.fa2.ID), "redelivery changes nothing")

	// The old FA can no longer cancel the moved visit; the new one can.
	assert.Equal(t, commands.StatusRejected, w.send(w.fa1, CmdCancelVisit, map[string]any{"visit_id": planned}).Status)
	assert.Equal(t, commands.StatusApplied, w.send(w.fa2, CmdCancelVisit, map[string]any{"visit_id": planned}).Status)
}

func TestSnapshotAndProviders(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	planned := ids.New()
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdPlanVisit, w.planPayload(planned, "2026-11-04")).Status)
	var logged []uuid.UUID
	for i := range 4 {
		id := ids.New()
		p := w.logPayload(id)
		p["visited_at"] = now.Add(-time.Duration(4-i) * time.Hour).Format(time.RFC3339)
		require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdLogVisit, p).Status)
		logged = append(logged, id)
	}
	_, _, err := w.svc.RequestCallback(testutil.Ctx(farmerPrincipal(w.farmer2)))
	require.NoError(t, err)

	reg := territory.NewRegistry()
	w.mod.RegisterSnapshot(reg)
	reg.SetResolver(func(_ context.Context, fa uuid.UUID) (territory.Scope, error) {
		return territory.Scope{FarmerIDs: []uuid.UUID{w.farmer1, w.farmer2}}, nil
	})
	snap, err := reg.Build(ctx, w.fa1.ID)
	require.NoError(t, err)
	visits := snap[territory.SectionVisits].([]SnapshotVisit)
	require.Len(t, visits, 4, "1 planned + last 3 logged")
	assert.Equal(t, planned, visits[0].ID)
	assert.Equal(t, "2026-11-04", *visits[0].PlannedFor)
	got := map[uuid.UUID]bool{}
	for _, v := range visits[1:] {
		got[v.ID] = true
		assert.Len(t, v.Issues, 2)
	}
	assert.False(t, got[logged[0]], "the oldest logged visit is left out")
	callbacks := snap[territory.SectionCallbacks].([]SnapshotCallback)
	require.Len(t, callbacks, 1)
	assert.Equal(t, w.farmer2, callbacks[0].FarmerID)

	nv, err := w.svc.NextPlannedVisit(ctx, w.farmer1)
	require.NoError(t, err)
	require.NotNil(t, nv)
	assert.Equal(t, planned, nv.VisitID)
	assert.Equal(t, "morning", nv.PlannedSlot)
	nv, err = w.svc.NextPlannedVisit(ctx, w.farmer2)
	require.NoError(t, err)
	assert.Nil(t, nv)

	adv, err := w.svc.GetVisitAdvice(ctx, logged[3])
	require.NoError(t, err)
	assert.Equal(t, w.fa1.ID, adv.FAID)
	require.Len(t, adv.Items, 2)
	for _, it := range adv.Items {
		assert.Equal(t, "Pink bollworm", it.IssueName)
		assert.Equal(t, "Emamectin benzoate 5% SG", it.SaltName)
	}
	_, err = w.svc.GetVisitAdvice(ctx, planned)
	assert.True(t, apperr.Is(err, apperr.KindNotFound), "not logged yet")
}
