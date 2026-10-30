package visits

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/visits/store"
)

func TestPlanVisit(t *testing.T) {
	w := newWorld(t)
	visit := ids.New()

	res := w.send(w.fa1, CmdPlanVisit, w.planPayload(visit, "2026-11-02"))
	require.Equal(t, commands.StatusApplied, res.Status, res.Error)
	assert.Equal(t, visit, res.EntityID)
	assert.Equal(t, 1, w.version(w.fa1.ID))
	assert.Equal(t, 1, w.count(`SELECT count(*) FROM audit_log WHERE action = 'visits.planned' AND entity_id = $1`, visit))

	// Same plan again: applied, nothing written.
	res = w.send(w.fa1, CmdPlanVisit, w.planPayload(visit, "2026-11-02"))
	require.Equal(t, commands.StatusApplied, res.Status)
	assert.Equal(t, 1, w.version(w.fa1.ID))

	// Re-plan to another day.
	res = w.send(w.fa1, CmdPlanVisit, w.planPayload(visit, "2026-11-03"))
	require.Equal(t, commands.StatusApplied, res.Status)
	v, err := w.svc.read().GetVisit(context.Background(), visit)
	require.NoError(t, err)
	assert.Equal(t, "2026-11-03", v.PlannedFor.Format(time.DateOnly))
	assert.Equal(t, 1, w.count(`SELECT count(*) FROM audit_log WHERE action = 'visits.replanned'`))

	t.Run("farmer not assigned to this FA", func(t *testing.T) {
		res := w.send(w.fa2, CmdPlanVisit, w.planPayload(ids.New(), "2026-11-02"))
		assert.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "not assigned")
	})
	t.Run("season of another farmer", func(t *testing.T) {
		p := w.planPayload(ids.New(), "2026-11-02")
		p["season_id"] = w.season2
		res := w.send(w.fa1, CmdPlanVisit, p)
		require.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "season does not exist or does not belong")
	})
	t.Run("bad slot and date", func(t *testing.T) {
		p := w.planPayload(ids.New(), "02-11-2026")
		assert.Equal(t, commands.StatusRejected, w.send(w.fa1, CmdPlanVisit, p).Status)
		p = w.planPayload(ids.New(), "2026-11-02")
		p["planned_slot"] = "night"
		assert.Equal(t, commands.StatusRejected, w.send(w.fa1, CmdPlanVisit, p).Status)
	})
	t.Run("a merged farmer's phone-minted ID resolves to the farmer", func(t *testing.T) {
		alias := ids.New()
		w.farmers.aliases = map[uuid.UUID]uuid.UUID{alias: w.farmer1}
		id := ids.New()
		p := w.planPayload(id, "2026-11-05")
		p["farmer_id"] = alias
		res := w.send(w.fa1, CmdPlanVisit, p)
		require.Equal(t, commands.StatusApplied, res.Status, res.Error)
		v, err := w.svc.read().GetVisit(context.Background(), id)
		require.NoError(t, err)
		assert.Equal(t, w.farmer1, v.FarmerID)

		l := w.logPayload(ids.New())
		l["farmer_id"] = alias
		res = w.send(w.fa1, CmdLogVisit, l)
		require.Equal(t, commands.StatusApplied, res.Status, res.Error)
	})
	t.Run("visit ID reused for another farmer", func(t *testing.T) {
		p := w.planPayload(visit, "2026-11-02")
		p["farmer_id"], p["plot_id"], p["season_id"] = w.farmer2, w.plot2, w.season2
		res := w.send(w.fa1, CmdPlanVisit, p)
		require.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "different farmer")
	})
}

func TestLogVisit(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	visit, next := ids.New(), ids.New()
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdPlanVisit, w.planPayload(visit, "2026-10-30")).Status)

	// The farmer asked for a call-back; logging the visit closes it.
	_, created, err := w.svc.RequestCallback(testutil.Ctx(farmerPrincipal(w.farmer1)))
	require.NoError(t, err)
	require.True(t, created)
	before := w.version(w.fa1.ID)

	p := w.logPayload(visit)
	p["next_visit"] = map[string]any{"visit_id": next, "planned_for": "2026-11-12", "planned_slot": "afternoon"}
	res := w.send(w.fa1, CmdLogVisit, p)
	require.Equal(t, commands.StatusApplied, res.Status, res.Error)
	assert.Greater(t, w.version(w.fa1.ID), before)

	v, err := w.svc.read().GetVisit(ctx, visit)
	require.NoError(t, err)
	assert.Equal(t, StatusDone, v.Status)
	assert.Equal(t, "2026-10-30", v.PlannedFor.Format(time.DateOnly), "the earlier plan is kept")
	assert.Equal(t, "Flowering", *v.StageName)
	loc := parsePoint(v.LocationGeojson)
	require.NotNil(t, loc)
	assert.InDelta(t, 17.46, loc.Lat, 1e-9)
	assert.Equal(t, int32(1), v.PhotoCount)

	issues, err := w.svc.read().ListVisitIssues(ctx, []uuid.UUID{visit})
	require.NoError(t, err)
	require.Len(t, issues, 2)
	byIssue := map[uuid.UUID]store.VisitIssue{}
	for _, is := range issues {
		byIssue[is.IssueID] = is
	}
	withSKU, saltOnly := byIssue[w.issueSKU], byIssue[w.issueSalt]
	assert.Equal(t, w.ruleSKU, withSKU.AdvisoryRuleID.UUID, "exact rule stored")
	assert.Equal(t, int32(2), *withSKU.RuleVersion)
	assert.Equal(t, w.sku, withSKU.SkuID.UUID)
	assert.Equal(t, "Sample 5 SG", *withSKU.ProductName)
	assert.Equal(t, "80 g per acre", *withSKU.DosePerAcre)
	assert.False(t, saltOnly.SkuID.Valid, "salt only")
	assert.Nil(t, saltOnly.ProductName)
	assert.Equal(t, "Pink bollworm", *saltOnly.IssueName)
	assert.Equal(t, AdviceGivenStatus, withSKU.AdviceStatus)
	assert.Equal(t, w.ruleSKU, withSKU.RequestedRuleID.UUID)
	assert.Equal(t, w.district, v.DistrictID.UUID, "the farmer's district, for HO area scope")

	photos, err := w.svc.read().ListVisitPhotos(ctx, visit)
	require.NoError(t, err)
	require.Len(t, photos, 1)
	assert.Nil(t, photos[0].UploadedAt, "awaiting upload")
	assert.Equal(t, "visits/"+visit.String()+"/"+photos[0].ID.String()+".jpg", photos[0].StorageKey)

	nv, err := w.svc.read().GetVisit(ctx, next)
	require.NoError(t, err)
	assert.Equal(t, StatusPlanned, nv.Status)
	assert.Equal(t, "afternoon", *nv.PlannedSlot)

	assert.Equal(t, 0, w.count(`SELECT count(*) FROM callback_requests WHERE status = 'open'`), "callback closed")
	assert.Equal(t, 1, w.count(`SELECT count(*) FROM river_job WHERE kind = 'domain_event' AND args->>'name' = 'visit.logged'`))
	assert.Equal(t, 1, w.count(`SELECT count(*) FROM audit_log WHERE action = 'visits.logged' AND entity_id = $1`, visit))

	t.Run("replay is idempotent", func(t *testing.T) {
		calls := w.masters.calls
		res := w.send(w.fa1, CmdLogVisit, p)
		require.Equal(t, commands.StatusApplied, res.Status)
		assert.Equal(t, calls, w.masters.calls, "a replay does not resolve advice again")
		assert.Equal(t, 2, w.count(`SELECT count(*) FROM visit_issues WHERE visit_id = $1`, visit))
		assert.Equal(t, 1, w.count(`SELECT count(*) FROM river_job WHERE kind = 'domain_event' AND args->>'name' = 'visit.logged'`))
	})
	t.Run("advice problems never reject the visit", func(t *testing.T) {
		id := ids.New()
		p := w.logPayload(id)
		unknownRule := ids.New()
		p["issues"] = []map[string]any{
			{"issue_visit_id": ids.New(), "issue_id": w.issueNoRule, "severity": "high"},                                  // no rule picked
			{"issue_visit_id": ids.New(), "issue_id": w.issueNoRule, "severity": "high", "advisory_rule_id": unknownRule}, // not a rule
			{"issue_visit_id": ids.New(), "issue_id": w.issueNoRule, "severity": "low", "advisory_rule_id": w.ruleSalt},   // another issue's rule
			{"issue_visit_id": ids.New(), "issue_id": w.issueSKU, "severity": "low", "advisory_rule_id": w.ruleOld},       // superseded: fine
		}
		res := w.send(w.fa1, CmdLogVisit, p)
		require.Equal(t, commands.StatusApplied, res.Status, res.Error)
		assert.Equal(t, 3, w.count(`SELECT count(*) FROM visit_issues WHERE visit_id = $1 AND advice_status = 'unresolved'
			AND salt_id IS NULL AND advisory_rule_id IS NULL`, id))
		assert.Equal(t, 1, w.count(`SELECT count(*) FROM visit_issues WHERE visit_id = $1 AND requested_rule_id = $2
			AND unresolved_reason LIKE '%not an approved rule'`, id, unknownRule))
		assert.Equal(t, 1, w.count(`SELECT count(*) FROM visit_issues WHERE visit_id = $1 AND requested_rule_id = $2
			AND unresolved_reason LIKE '%for another issue'`, id, w.ruleSalt))
		assert.Equal(t, 1, w.count(`SELECT count(*) FROM visit_issues WHERE visit_id = $1 AND advice_status = 'given'
			AND advisory_rule_id = $2 AND dose_per_acre = '70 g per acre'`, id, w.ruleOld), "the FA's (superseded) rule, not the live one")

		// HO visit detail shows them; the farmer notice leaves them out.
		d, err := w.svc.Get(testutil.Ctx(testutil.HO(auth.RoleAgronomy)), id)
		require.NoError(t, err)
		unresolved := 0
		for _, is := range d.Visit.Issues {
			if is.Unresolved() {
				unresolved++
				assert.Nil(t, is.Advice.SaltID)
				assert.NotNil(t, is.UnresolvedReason)
			}
		}
		assert.Equal(t, 3, unresolved)
		adv, err := w.svc.GetVisitAdvice(ctx, id)
		require.NoError(t, err)
		require.Len(t, adv.Items, 1)
		assert.Equal(t, "70 g per acre", *adv.Items[0].Dose)
	})
	t.Run("IDs reused from another visit are rejected with a clear reason", func(t *testing.T) {
		issues, err := w.svc.read().ListVisitIssues(ctx, []uuid.UUID{visit})
		require.NoError(t, err)
		photos, err := w.svc.read().ListVisitPhotos(ctx, visit)
		require.NoError(t, err)

		p := w.logPayload(ids.New())
		p["issues"] = []map[string]any{{"issue_visit_id": issues[0].ID, "issue_id": w.issueSKU, "severity": "low", "advisory_rule_id": w.ruleSKU}}
		res := w.send(w.fa1, CmdLogVisit, p)
		require.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "issue_visit_id is already used by another visit")

		p = w.logPayload(ids.New())
		p["photos"] = []map[string]any{{"photo_id": photos[0].ID, "content_type": "image/jpeg"}}
		res = w.send(w.fa1, CmdLogVisit, p)
		require.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "photo_id is already used by another visit")
		assert.Equal(t, 1, w.count(`SELECT count(*) FROM visit_photos WHERE id = $1`, photos[0].ID))
	})
	t.Run("plot of another farmer", func(t *testing.T) {
		p := w.logPayload(ids.New())
		p["plot_id"] = w.plot2
		res := w.send(w.fa1, CmdLogVisit, p)
		require.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "does not belong")
	})
	t.Run("bad photo type and future time", func(t *testing.T) {
		p := w.logPayload(ids.New())
		p["photos"] = []map[string]any{{"photo_id": ids.New(), "content_type": "image/gif"}}
		assert.Equal(t, commands.StatusRejected, w.send(w.fa1, CmdLogVisit, p).Status)
		p = w.logPayload(ids.New())
		p["visited_at"] = now.Add(2 * time.Hour).Format(time.RFC3339)
		assert.Equal(t, commands.StatusRejected, w.send(w.fa1, CmdLogVisit, p).Status)
	})
	t.Run("cancel", func(t *testing.T) {
		res := w.send(w.fa1, CmdCancelVisit, map[string]any{"visit_id": visit})
		require.Equal(t, commands.StatusRejected, res.Status, "a logged visit cannot be cancelled")
		res = w.send(w.fa2, CmdCancelVisit, map[string]any{"visit_id": next})
		require.Equal(t, commands.StatusRejected, res.Status, "another FA's visit")
		res = w.send(w.fa1, CmdCancelVisit, map[string]any{"visit_id": next, "reason": "farmer away"})
		require.Equal(t, commands.StatusApplied, res.Status)
		res = w.send(w.fa1, CmdCancelVisit, map[string]any{"visit_id": next})
		require.Equal(t, commands.StatusApplied, res.Status, "idempotent")
		res = w.send(w.fa1, CmdCancelVisit, map[string]any{"visit_id": ids.New()})
		require.Equal(t, commands.StatusRejected, res.Status)
	})
}

func TestCloseCallback(t *testing.T) {
	w := newWorld(t)
	farmerCtx := testutil.Ctx(farmerPrincipal(w.farmer1))
	cb, _, err := w.svc.RequestCallback(farmerCtx)
	require.NoError(t, err)

	res := w.send(w.fa2, CmdCloseCallback, map[string]any{"callback_id": cb.ID})
	require.Equal(t, commands.StatusRejected, res.Status)
	res = w.send(w.fa1, CmdCloseCallback, map[string]any{"callback_id": cb.ID, "note": "Called, will visit Monday"})
	require.Equal(t, commands.StatusApplied, res.Status)
	res = w.send(w.fa1, CmdCloseCallback, map[string]any{"callback_id": cb.ID})
	require.Equal(t, commands.StatusApplied, res.Status, "idempotent")

	row, err := w.svc.read().LockCallback(context.Background(), cb.ID)
	require.NoError(t, err)
	assert.Equal(t, CallbackClosed, row.Status)
	assert.Equal(t, w.fa1.ID, row.ClosedBy.UUID)
	assert.Equal(t, "Called, will visit Monday", *row.Note)

	_, err = w.svc.CancelMyCallback(farmerCtx, cb.ID)
	assert.ErrorContains(t, err, "callback_closed")
}
