package farmers

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

func TestFindOrCreateByPhone(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	var first, again uuid.UUID
	var created, createdAgain bool
	err := db.WithTx(ctx, f.pool, func(tx pgx.Tx) error {
		var err error
		if first, created, err = f.svc.FindOrCreateByPhone(ctx, tx, "098480 12345", SourceSelf); err != nil {
			return err
		}
		again, createdAgain, err = f.svc.FindOrCreateByPhone(ctx, tx, "+91 98480 12345", SourceSelf)
		return err
	})
	require.NoError(t, err)
	assert.True(t, created)
	assert.False(t, createdAgain)
	assert.Equal(t, first, again, "merged on the normalised phone")
	got := f.farmer(first)
	assert.Equal(t, StatusPending, got.Status)
	assert.Equal(t, "+919848012345", got.Phone)
	require.Len(t, f.events("farmer.registered"), 1)
	assert.Equal(t, "self", f.events("farmer.registered")[0]["source"])
	assert.Equal(t, 1, f.count(`SELECT count(*) FROM audit_log WHERE action = 'farmers.registered' AND farmer_id = $1`, first))
	assert.Zero(t, f.count(`SELECT count(*) FROM audit_log WHERE after::text LIKE '%9848012345%'`), "phone masked in audit")

	err = db.WithTx(ctx, f.pool, func(tx pgx.Tx) error {
		_, _, err := f.svc.FindOrCreateByPhone(ctx, tx, "12345", SourceSelf)
		return err
	})
	assert.True(t, apperr.Is(err, apperr.KindValidation))
}

func TestFarmerApp(t *testing.T) {
	f := newFixture(t)
	id := f.selfSignUp("9848012345")
	ctx := farmerCtx(id)

	// Pending farmers must complete the profile before adding plots.
	_, err := f.svc.AddMyPlot(ctx, NewPlotInput{Pin: Point{Lat: 17.46, Lng: 78.36}, AreaAcres: 1})
	assert.True(t, apperr.Is(err, apperr.KindConflict))

	name, lang := "Ravi K", "te"
	got, err := f.svc.CompleteProfile(ctx, ProfileInput{Name: &name, Language: &lang, VillageID: &f.village})
	require.NoError(t, err)
	assert.Equal(t, StatusActive, got.Status)
	require.NotNil(t, got.AssignedFAID)
	assert.Equal(t, f.fa1, *got.AssignedFAID, "lead FA of the village")
	assert.Equal(t, f.district, *got.DistrictID)
	require.Len(t, f.events("farmer.profile_completed"), 1)
	assert.Equal(t, f.village.String(), f.events("farmer.profile_completed")[0]["village_id"])
	assert.Equal(t, 1, f.territoryVersion(f.fa1))

	_, err = f.svc.CompleteProfile(ctx, ProfileInput{Name: &name, Language: &lang, VillageID: &f.village})
	assert.True(t, apperr.Is(err, apperr.KindConflict), "only once")

	// Consents: append-only rows, current = latest per purpose.
	cs, err := f.svc.SetMyConsent(ctx, ConsentInput{Purpose: "programme", Granted: true, NoticeVersion: "2026-10", AudioPlayed: true})
	require.NoError(t, err)
	require.Len(t, cs, 4)
	assert.True(t, *cs[0].Granted)
	assert.Nil(t, cs[1].Granted, "soil partner never asked")
	f.clock.Advance(time.Minute)
	cs, err = f.svc.SetMyConsent(ctx, ConsentInput{Purpose: "programme", Granted: false, NoticeVersion: "2026-10"})
	require.NoError(t, err)
	assert.False(t, *cs[0].Granted)
	assert.Equal(t, MethodApp, *cs[0].Method)
	assert.Equal(t, 2, f.count(`SELECT count(*) FROM consents WHERE farmer_id = $1`, id))

	// Plot, season, home with stage, FA card and next visit.
	plot, err := f.svc.AddMyPlot(ctx, NewPlotInput{Pin: Point{Lat: 17.46, Lng: 78.36}, AreaAcres: 2.1})
	require.NoError(t, err)
	assert.Equal(t, "Plot 1", plot.Label)
	assert.Equal(t, AreaTyped, plot.AreaSource)
	sowing := time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)
	season, err := f.svc.StartMySeason(ctx, plot.ID, NewSeasonInput{SeasonCode: "kharif-2026", CropID: f.cotton, SowingDate: &sowing})
	require.NoError(t, err)
	_, err = f.svc.StartMySeason(ctx, plot.ID, NewSeasonInput{SeasonCode: "kharif-2026", CropID: f.cotton})
	assert.True(t, apperr.Is(err, apperr.KindConflict), "one active season per plot")

	visit := &xmod.PlannedVisit{VisitID: ids.New(), FAID: f.fa1, PlotID: plot.ID, SeasonID: season.ID,
		PlannedFor: time.Date(2026, 11, 2, 0, 0, 0, 0, time.UTC), PlannedSlot: "morning"}
	f.vis.next[id] = visit
	home, err := f.svc.Home(ctx)
	require.NoError(t, err)
	require.Len(t, home.Plots, 1)
	hp := home.Plots[0]
	require.NotNil(t, hp.ActiveSeason)
	assert.Equal(t, 59, *hp.DaysAfterSowing, "1 Sep to 30 Oct (IST)")
	require.NotNil(t, hp.Stage)
	assert.Equal(t, "flowering", hp.Stage.Code)
	require.NotNil(t, home.FA)
	assert.Equal(t, "Suresh K", home.FA.Name)
	require.NotNil(t, home.Village)
	assert.Equal(t, "Kondapur", home.Village.Name)
	assert.Equal(t, visit, home.NextVisit)

	closed, err := f.svc.CloseMySeason(ctx, season.ID, SeasonHarvested)
	require.NoError(t, err)
	assert.Equal(t, SeasonHarvested, closed.Status)

	// Another farmer cannot touch this plot.
	other := f.selfSignUp("9000011111")
	_, err = f.svc.CompleteProfile(farmerCtx(other), ProfileInput{Name: &name, Language: &lang, VillageID: &f.village3})
	require.NoError(t, err)
	assert.False(t, f.farmer(other).AssignedFaID.Valid, "no lead FA covers village3")
	_, err = f.svc.StartMySeason(farmerCtx(other), plot.ID, NewSeasonInput{SeasonCode: "rabi-2026-27", CropID: f.cotton})
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	// Wrong token kind.
	_, err = f.svc.Home(testutil.Ctx(faPrincipal(f.fa1)))
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
}

func TestTargetingAndTerritory(t *testing.T) {
	f := newFixture(t)
	fa := faPrincipal(f.fa1)
	ctx := testutil.Ctx(fa)
	_, cottonFarmer := f.enrol(f.fa1, "9848011111", "Cotton Farmer", f.village)
	_, paddyFarmer := f.enrol(f.fa1, "9848022222", "Paddy Farmer", f.village2)
	_, idle := f.enrol(f.fa1, "9848033333", "No Season", f.village)

	addSeason := func(farmerID, crop uuid.UUID, sowing string) {
		plotID := ids.New()
		res, err := f.svc.SavePlot(ctx, fa, cmd("SavePlot"), SavePlotPayload{PlotID: plotID, FarmerID: farmerID, Label: "Plot 1",
			Pin: &Point{Lat: 17.46, Lng: 78.36}, AreaAcres: 1, AreaSource: AreaTyped})
		require.NoError(t, err)
		require.Equal(t, "applied", string(res.Status))
		res, err = f.svc.StartSeason(ctx, fa, cmd("StartSeason"), StartSeasonPayload{SeasonID: ids.New(), FarmerID: farmerID,
			PlotID: plotID, SeasonCode: "kharif-2026", CropID: crop, SowingDate: &sowing})
		require.NoError(t, err)
		require.Equal(t, "applied", string(res.Status))
	}
	addSeason(cottonFarmer, f.cotton, "2026-09-01") // day 59: flowering
	addSeason(paddyFarmer, f.paddy, "2026-10-20")

	target := func(t xmod.FarmerTarget) []uuid.UUID {
		got, err := f.svc.FarmerIDsForTargeting(context.Background(), t)
		require.NoError(f.t, err)
		return got
	}
	assert.ElementsMatch(t, []uuid.UUID{cottonFarmer, paddyFarmer, idle}, target(xmod.FarmerTarget{}))
	assert.Equal(t, []uuid.UUID{cottonFarmer}, target(xmod.FarmerTarget{CropIDs: []uuid.UUID{f.cotton}}))
	assert.Equal(t, []uuid.UUID{paddyFarmer}, target(xmod.FarmerTarget{VillageIDs: []uuid.UUID{f.village2}}))
	assert.ElementsMatch(t, []uuid.UUID{cottonFarmer, paddyFarmer, idle}, target(xmod.FarmerTarget{DistrictIDs: []uuid.UUID{f.district}}))
	assert.Empty(t, target(xmod.FarmerTarget{MandalIDs: []uuid.UUID{f.mandal2}}))
	assert.Equal(t, []uuid.UUID{cottonFarmer}, target(xmod.FarmerTarget{StageCodes: []string{"flowering"}}))
	assert.Empty(t, target(xmod.FarmerTarget{StageCodes: []string{"seedling"}, CropIDs: []uuid.UUID{f.paddy}}))
	premium := "premium"
	assert.Empty(t, target(xmod.FarmerTarget{Plan: &premium}))

	// Withdrawn programme consent drops the farmer.
	f.exec(`INSERT INTO consents (id, farmer_id, purpose, granted, method, notice_version, language, created_at)
		VALUES ($1, $2, 'programme', false, 'app', 'v2', 'te', '2026-10-30 07:00:00+00')`, ids.New(), idle)
	assert.NotContains(t, target(xmod.FarmerTarget{}), idle)

	sums, err := f.svc.GetFarmerSummaries(context.Background(), []uuid.UUID{cottonFarmer, ids.New()})
	require.NoError(t, err)
	require.Len(t, sums, 1)
	assert.Equal(t, "Cotton Farmer", *sums[0].Name)
	assert.Equal(t, f.fa1, sums[0].AssignedFAID.UUID)

	// Territory: resolver and sections.
	reg := territory.NewRegistry()
	(&Module{svc: f.svc}).RegisterSnapshot(reg)
	snap, err := reg.Build(context.Background(), f.fa1)
	require.NoError(t, err)
	raw, err := json.Marshal(snap)
	require.NoError(t, err)
	var decoded struct {
		Farmers []map[string]any `json:"farmers"`
		Plots   []map[string]any `json:"plots"`
		Seasons []map[string]any `json:"seasons"`
	}
	require.NoError(t, json.Unmarshal(raw, &decoded))
	assert.Len(t, decoded.Farmers, 3)
	assert.Len(t, decoded.Plots, 2)
	require.Len(t, decoded.Seasons, 2)
	assert.Contains(t, []any{"2026-09-01", "2026-10-20"}, decoded.Seasons[0]["sowing_date"])
	scope, err := reg.Resolve(context.Background(), f.fa1)
	require.NoError(t, err)
	assert.ElementsMatch(t, []uuid.UUID{f.village, f.village2}, scope.VillageIDs)
	empty, err := reg.Build(context.Background(), f.fa2)
	require.NoError(t, err)
	assert.Empty(t, empty["farmers"])
}

func TestAdmin(t *testing.T) {
	f := newFixture(t)
	_, a := f.enrol(f.fa1, "9848011111", "Anil R", f.village)
	_, b := f.enrol(f.fa1, "9848022222", "Bhavani S", f.village2)
	_, c := f.enrol(f.fa2, "9848033333", "Chandra M", f.village3)
	pending := f.selfSignUp("9848044444")

	ops := testutil.Ctx(testutil.HO(auth.RoleOps))
	finance := testutil.Ctx(testutil.HO(auth.RoleFinance))
	scoped := testutil.Ctx(testutil.HO(auth.RoleOps, f.district2))

	t.Run("list", func(t *testing.T) {
		page, err := f.svc.List(finance, ListFilter{}, nil, nil)
		require.NoError(t, err)
		require.Len(t, page.Items, 4)
		assert.Equal(t, pending, page.Items[0].Farmer.ID, "newest first")

		page, err = f.svc.List(finance, ListFilter{}, ptr(2), nil)
		require.NoError(t, err)
		require.Len(t, page.Items, 2)
		require.NotNil(t, page.NextCursor)
		next, err := f.svc.List(finance, ListFilter{}, ptr(2), page.NextCursor)
		require.NoError(t, err)
		assert.Len(t, next.Items, 2)
		assert.Nil(t, next.NextCursor)

		page, err = f.svc.List(finance, ListFilter{FAID: &f.fa1}, nil, nil)
		require.NoError(t, err)
		assert.Len(t, page.Items, 2)
		it := page.Items[1]
		assert.Equal(t, a, it.Farmer.ID)
		require.NotNil(t, it.Village)
		assert.Equal(t, "Kondapur", it.Village.Name)
		require.NotNil(t, it.FA)
		assert.Equal(t, "Suresh K", it.FA.Name)
		assert.True(t, *it.ProgrammeConsent)
		assert.Equal(t, 2, it.ConsentsGranted)

		q := "bhav"
		page, err = f.svc.List(finance, ListFilter{Q: &q}, nil, nil)
		require.NoError(t, err)
		require.Len(t, page.Items, 1)
		assert.Equal(t, b, page.Items[0].Farmer.ID)
		q = "98480 33333"
		page, err = f.svc.List(finance, ListFilter{Q: &q}, nil, nil)
		require.NoError(t, err)
		require.Len(t, page.Items, 1)
		assert.Equal(t, c, page.Items[0].Farmer.ID)

		page, err = f.svc.List(finance, ListFilter{Unassigned: true}, nil, nil)
		require.NoError(t, err)
		require.Len(t, page.Items, 1)
		assert.Equal(t, pending, page.Items[0].Farmer.ID)

		page, err = f.svc.List(scoped, ListFilter{}, nil, nil)
		require.NoError(t, err)
		require.Len(t, page.Items, 1, "district scope")
		assert.Equal(t, c, page.Items[0].Farmer.ID)
	})

	t.Run("360 and scope", func(t *testing.T) {
		v, err := f.svc.Get360(finance, a)
		require.NoError(t, err)
		assert.Len(t, v.ConsentHistory, 2)
		assert.Equal(t, "Suresh K", v.AssignedFA.Name)
		assert.Equal(t, "Suresh K", v.EnrolledByFA.Name)
		_, err = f.svc.Get360(scoped, a)
		assert.True(t, apperr.Is(err, apperr.KindNotFound), "outside the HO user's districts")
	})

	t.Run("update", func(t *testing.T) {
		_, err := f.svc.AdminUpdateFarmer(finance, a, AdminUpdate{ExpectedVersion: 1})
		assert.True(t, apperr.Is(err, apperr.KindForbidden), "finance cannot write")

		cur := f.farmer(a)
		before := f.territoryVersion(f.fa1)
		premium, newPhone := "premium", "9848055555"
		admin := testutil.Ctx(testutil.HO(auth.RoleAdmin))
		got, err := f.svc.AdminUpdateFarmer(admin, a, AdminUpdate{ExpectedVersion: cur.Version, Plan: &premium, Phone: &newPhone,
			VillageID: &f.village2, Reason: ptr("trial")})
		require.NoError(t, err)
		assert.Equal(t, "premium", got.Plan)
		assert.Equal(t, "+919848055555", got.Phone)
		assert.Equal(t, f.village2, *got.VillageID)
		assert.Equal(t, before+1, f.territoryVersion(f.fa1))

		_, err = f.svc.AdminUpdateFarmer(ops, a, AdminUpdate{ExpectedVersion: cur.Version, Plan: &premium})
		e, ok := apperr.As(err)
		require.True(t, ok)
		assert.Equal(t, "version_mismatch", e.Code)

		taken := "9848022222"
		_, err = f.svc.AdminUpdateFarmer(ops, a, AdminUpdate{ExpectedVersion: got.Version, Phone: &taken})
		e, ok = apperr.As(err)
		require.True(t, ok)
		assert.Equal(t, "phone_taken", e.Code)
	})

	t.Run("deactivate and reactivate", func(t *testing.T) {
		got, err := f.svc.Deactivate(ops, b, nil)
		require.NoError(t, err)
		assert.Equal(t, StatusInactive, got.Status)
		_, err = f.svc.Deactivate(ops, b, nil)
		assert.True(t, apperr.Is(err, apperr.KindConflict))
		scope, err := f.svc.ResolveTerritory(context.Background(), f.fa1)
		require.NoError(t, err)
		assert.NotContains(t, scope.FarmerIDs, b, "inactive farmers leave the snapshot")
		got, err = f.svc.Reactivate(ops, b, nil)
		require.NoError(t, err)
		assert.Equal(t, StatusActive, got.Status)
	})

	t.Run("reassign by village", func(t *testing.T) {
		v1, v2 := f.territoryVersion(f.fa1), f.territoryVersion(f.fa2)
		moved, err := f.svc.Reassign(ops, ReassignInput{ToFAID: f.fa2, FromFAID: &f.fa1, VillageIDs: []uuid.UUID{f.village2}})
		require.NoError(t, err)
		assert.ElementsMatch(t, []uuid.UUID{a, b}, moved, "a moved to village2 above")
		assert.Equal(t, f.fa2, f.farmer(b).AssignedFaID.UUID)
		evs := f.events("farmers.reassigned")
		require.Len(t, evs, 1)
		assert.Equal(t, f.fa1.String(), evs[0]["from_fa_id"])
		assert.Equal(t, f.fa2.String(), evs[0]["to_fa_id"])
		assert.Greater(t, f.territoryVersion(f.fa1), v1)
		assert.Greater(t, f.territoryVersion(f.fa2), v2)

		moved, err = f.svc.Reassign(ops, ReassignInput{ToFAID: f.fa2, FromFAID: &f.fa1, VillageIDs: []uuid.UUID{f.village2}})
		require.NoError(t, err)
		assert.Empty(t, moved, "already with that FA")

		_, err = f.svc.Reassign(ops, ReassignInput{ToFAID: ids.New(), FarmerIDs: []uuid.UUID{a}})
		assert.True(t, apperr.Is(err, apperr.KindValidation), "unknown FA")
		_, err = f.svc.Reassign(ops, ReassignInput{ToFAID: f.fa1})
		assert.True(t, apperr.Is(err, apperr.KindValidation), "nothing selected")
	})

	t.Run("rollover", func(t *testing.T) {
		fa := faPrincipal(f.fa2)
		plotID := ids.New()
		res, err := f.svc.SavePlot(testutil.Ctx(fa), fa, cmd("SavePlot"), SavePlotPayload{PlotID: plotID, FarmerID: c, Label: "Plot 1",
			Pin: &Point{Lat: 17.5, Lng: 78.5}, AreaAcres: 1, AreaSource: AreaTyped})
		require.NoError(t, err)
		require.Equal(t, "applied", string(res.Status), "%v", res.Error)
		res, err = f.svc.StartSeason(testutil.Ctx(fa), fa, cmd("StartSeason"), StartSeasonPayload{SeasonID: ids.New(), FarmerID: c,
			PlotID: plotID, SeasonCode: "kharif-2026", CropID: f.cotton})
		require.NoError(t, err)
		require.Equal(t, "applied", string(res.Status))

		n, err := f.svc.Rollover(testutil.Ctx(testutil.HO(auth.RoleOps, f.district)), "kharif-2026", SeasonHarvested)
		require.NoError(t, err)
		assert.Zero(t, n, "farmer c is outside this HO user's district")
		n, err = f.svc.Rollover(ops, "kharif-2026", SeasonHarvested)
		require.NoError(t, err)
		assert.Equal(t, 1, n)
		assert.Zero(t, f.count(`SELECT count(*) FROM crop_seasons WHERE status = 'active'`))
	})
}

func ptr[T any](v T) *T { return &v }
