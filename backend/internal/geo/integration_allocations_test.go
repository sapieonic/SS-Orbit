package geo_test

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/geo"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

func TestAllocationsAndCoverage(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	suresh := w.fa(t, "Suresh K", "active")
	kiran := w.fa(t, "Kiran M", "active")
	lakshmi := w.fa(t, "Lakshmi Devi", "active")
	anil := w.fa(t, "Anil Reddy", "active")

	a := w.allocate(t, suresh, geo.LevelVillage, w.kondapur, true)
	assert.Equal(t, "Kondapur", a.AreaName)
	assert.Equal(t, "కొండాపూర్", *a.AreaNameTe)
	assert.Equal(t, w.serilingampally, *a.MandalID)
	assert.Equal(t, "Rangareddy", a.DistrictName)
	require.NotNil(t, a.FA, "names come from identity")
	assert.Equal(t, "Suresh K", a.FA.Name)
	assert.Nil(t, a.CreatedBy, "random HO principal is not an ho_users row")
	assert.Equal(t, int64(1), w.version(t, suresh))

	// One lead per area; one allocation per FA per area.
	_, err := w.svc.CreateAllocation(w.admin, geo.NewAllocation{FAID: kiran, Level: geo.LevelVillage, AreaID: w.kondapur, IsLead: true})
	e, ok := apperr.As(err)
	require.True(t, ok)
	assert.Equal(t, "area_has_lead", e.Code)
	assert.Equal(t, suresh, e.Details["fa_id"])
	_, err = w.svc.CreateAllocation(w.admin, geo.NewAllocation{FAID: suresh, Level: geo.LevelVillage, AreaID: w.kondapur})
	assert.Equal(t, "allocation_exists", errCode(t, err))
	_, err = w.svc.CreateAllocation(w.admin, geo.NewAllocation{FAID: ids.New(), Level: geo.LevelVillage, AreaID: w.gachibowli})
	assert.True(t, apperr.Is(err, apperr.KindNotFound), "unknown FA")
	_, err = w.svc.CreateAllocation(w.admin, geo.NewAllocation{FAID: kiran, Level: geo.LevelMandal, AreaID: w.kondapur})
	assert.True(t, apperr.Is(err, apperr.KindNotFound), "area must exist at that level")

	kiranSupport := w.allocate(t, kiran, geo.LevelVillage, w.kondapur, false)
	w.allocate(t, lakshmi, geo.LevelMandal, w.serilingampally, true)
	w.allocate(t, lakshmi, geo.LevelVillage, w.kondapur, false)
	anilDistrict := w.allocate(t, anil, geo.LevelDistrict, w.rangareddy, true)
	assert.Equal(t, w.rangareddy, anilDistrict.AreaID)
	assert.Nil(t, anilDistrict.MandalID)

	// Most specific level first, leads first, each FA once.
	cov, err := w.svc.FAsCoveringVillage(ctx, w.kondapur)
	require.NoError(t, err)
	assert.Equal(t, []xmod.Coverage{
		{FAID: suresh, Level: "village", IsLead: true},
		{FAID: kiran, Level: "village", IsLead: false},
		{FAID: lakshmi, Level: "village", IsLead: false},
		{FAID: anil, Level: "district", IsLead: true},
	}, cov)
	cov, err = w.svc.FAsCoveringVillage(ctx, w.narsingi)
	require.NoError(t, err)
	assert.Equal(t, []xmod.Coverage{{FAID: anil, Level: "district", IsLead: true}}, cov)
	cov, err = w.svc.FAsCoveringVillage(ctx, w.medchalVillage)
	require.NoError(t, err)
	assert.Empty(t, cov)

	// Mandal and district allocations expand to their villages.
	villagesOf := func(fa uuid.UUID) []uuid.UUID {
		got, err := w.svc.VillageIDsForFA(ctx, fa)
		require.NoError(t, err)
		return got
	}
	assert.Equal(t, []uuid.UUID{w.kondapur}, villagesOf(suresh))
	assert.ElementsMatch(t, []uuid.UUID{w.kondapur, w.gachibowli, w.madhapur}, villagesOf(lakshmi))
	assert.ElementsMatch(t, []uuid.UUID{w.kondapur, w.gachibowli, w.madhapur, w.narsingi}, villagesOf(anil))

	// A new village in a covered mandal bumps the FAs who now cover it.
	before := w.version(t, lakshmi)
	beforeSuresh := w.version(t, suresh)
	hafeezpet := w.village(t, w.serilingampally, "Hafeezpet", "హఫీజ్‌పేట్")
	assert.Greater(t, w.version(t, lakshmi), before)
	assert.Contains(t, villagesOf(lakshmi), hafeezpet)
	assert.Contains(t, villagesOf(anil), hafeezpet)
	assert.GreaterOrEqual(t, w.version(t, suresh), beforeSuresh)

	// Districts per FA: village, mandal and district allocations all resolve
	// to Rangareddy; an FA with no allocation is absent.
	nobody := w.fa(t, "No Area", "active")
	districts, err := w.svc.DistrictIDsForFAs(ctx, []uuid.UUID{suresh, lakshmi, anil, nobody})
	require.NoError(t, err)
	assert.Equal(t, map[uuid.UUID][]uuid.UUID{
		suresh: {w.rangareddy}, lakshmi: {w.rangareddy}, anil: {w.rangareddy},
	}, districts)

	// Lists and filters.
	list := func(f geo.AllocationFilter) []geo.FAAllocation {
		page, err := w.svc.ListAllocations(w.admin, f, nil, nil)
		require.NoError(t, err)
		return page.Items
	}
	assert.Len(t, list(geo.AllocationFilter{}), 5)
	assert.Len(t, list(geo.AllocationFilter{MandalID: &w.serilingampally}), 4, "village and mandal level, not the district FA")
	assert.Len(t, list(geo.AllocationFilter{DistrictID: &w.rangareddy}), 5)
	assert.Len(t, list(geo.AllocationFilter{FAID: &lakshmi}), 2)
	assert.Len(t, list(geo.AllocationFilter{VillageID: &w.kondapur}), 3)
	assert.Equal(t, "Anil Reddy", list(geo.AllocationFilter{})[0].FA.Name, "newest first, names attached")

	// End an allocation.
	v := w.version(t, kiran)
	ended, err := w.svc.EndAllocation(w.admin, kiranSupport.ID)
	require.NoError(t, err)
	require.NotNil(t, ended.ValidTo)
	assert.Greater(t, w.version(t, kiran), v)
	_, err = w.svc.EndAllocation(w.admin, kiranSupport.ID)
	assert.Equal(t, "allocation_ended", errCode(t, err))
	_, err = w.svc.EndAllocation(w.admin, uuid.New())
	assert.True(t, apperr.Is(err, apperr.KindNotFound))
	assert.Len(t, list(geo.AllocationFilter{FAID: &kiran}), 0)
	assert.Len(t, list(geo.AllocationFilter{FAID: &kiran, IncludeEnded: true}), 1)
	assert.Empty(t, villagesOf(kiran))
	// The area can take that FA again once the old row ended.
	w.allocate(t, kiran, geo.LevelVillage, w.kondapur, false)

	// Area scope: Medchal ops cannot touch Rangareddy.
	medchalOps := testutil.Ctx(testutil.HO(auth.RoleOps, w.medchal))
	_, err = w.svc.CreateAllocation(medchalOps, geo.NewAllocation{FAID: kiran, Level: geo.LevelVillage, AreaID: w.gachibowli})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	_, err = w.svc.EndAllocation(medchalOps, anilDistrict.ID)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	_, err = w.svc.Handover(medchalOps, anil, kiran)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	assert.Empty(t, listAll(t, w, medchalOps))

	assert.Equal(t, 6, w.count(t, `SELECT count(*) FROM audit_log WHERE action = 'geo.allocation_created'`))
	assert.Equal(t, 1, w.count(t, `SELECT count(*) FROM audit_log WHERE action = 'geo.allocation_ended'`))
}

func listAll(t *testing.T, w *world, ctx context.Context) []geo.FAAllocation {
	page, err := w.svc.ListAllocations(ctx, geo.AllocationFilter{}, nil, nil)
	require.NoError(t, err)
	return page.Items
}

func TestHandover(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	gopal := w.fa(t, "Gopal R", "leaving")
	kiran := w.fa(t, "Kiran M", "active")
	farida := w.fa(t, "Farida S", "active")
	retired := w.fa(t, "Old FA", "inactive")

	w.allocate(t, gopal, geo.LevelVillage, w.kondapur, true)
	w.allocate(t, gopal, geo.LevelMandal, w.gandipet, true)
	w.allocate(t, gopal, geo.LevelVillage, w.gachibowli, false)
	w.allocate(t, kiran, geo.LevelMandal, w.gandipet, false) // kiran already supports Gandipet
	w.allocate(t, farida, geo.LevelVillage, w.gachibowli, true)

	_, err := w.svc.Handover(w.admin, gopal, retired)
	assert.Equal(t, "fa_inactive", errCode(t, err))
	_, err = w.svc.Handover(w.admin, gopal, ids.New())
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	vg, vk := w.version(t, gopal), w.version(t, kiran)
	res, err := w.svc.Handover(w.admin, gopal, kiran)
	require.NoError(t, err)
	assert.Len(t, res.EndedIDs, 3)
	assert.ElementsMatch(t, []uuid.UUID{w.kondapur, w.gachibowli, w.narsingi}, res.AffectedVillageIDs)
	require.Len(t, res.Allocations, 3)
	byArea := map[uuid.UUID]geo.FAAllocation{}
	for _, a := range res.Allocations {
		assert.Equal(t, kiran, a.FAID)
		assert.Nil(t, a.ValidTo)
		require.NotNil(t, a.FA)
		byArea[a.AreaID] = a
	}
	assert.True(t, byArea[w.kondapur].IsLead)
	assert.True(t, byArea[w.gandipet].IsLead, "kiran's support row on Gandipet became the lead")
	assert.False(t, byArea[w.gachibowli].IsLead, "support stays support; farida stays lead")
	assert.Greater(t, w.version(t, gopal), vg)
	assert.Greater(t, w.version(t, kiran), vk)

	got, err := w.svc.VillageIDsForFA(ctx, gopal)
	require.NoError(t, err)
	assert.Empty(t, got)
	got, err = w.svc.VillageIDsForFA(ctx, kiran)
	require.NoError(t, err)
	assert.ElementsMatch(t, []uuid.UUID{w.kondapur, w.gachibowli, w.narsingi}, got)
	assert.Equal(t, 1, w.count(t, `SELECT count(*) FROM fa_allocations WHERE fa_id = $1 AND valid_to IS NULL AND level = 'mandal'`, kiran))

	cov, err := w.svc.FAsCoveringVillage(ctx, w.gachibowli)
	require.NoError(t, err)
	assert.Equal(t, []xmod.Coverage{{FAID: farida, Level: "village", IsLead: true}, {FAID: kiran, Level: "village", IsLead: false}}, cov)

	// Again: nothing left to move.
	res, err = w.svc.Handover(w.admin, gopal, kiran)
	require.NoError(t, err)
	assert.Empty(t, res.EndedIDs)
	assert.Empty(t, res.Allocations)
	assert.Empty(t, res.AffectedVillageIDs)
	assert.Equal(t, 1, w.count(t, `SELECT count(*) FROM audit_log WHERE action = 'geo.allocations_handed_over' AND entity_id = $1`, gopal))
}

func TestCreatedByAndNoIdentityPort(t *testing.T) {
	w := newWorld(t)
	w.ports.Identity = nil // not wired: no names, the FK is the only FA check
	fa := w.fa(t, "Suresh K", "active")

	ho := testutil.HO(auth.RoleOps)
	_, err := w.pool.Exec(context.Background(), `INSERT INTO ho_users (id, email, name, password_hash, role) VALUES ($1, 'ops@example.com', 'Ops', 'x', 'ops')`, ho.ID)
	require.NoError(t, err)
	a, err := w.svc.CreateAllocation(testutil.Ctx(ho), geo.NewAllocation{FAID: fa, Level: geo.LevelVillage, AreaID: w.kondapur, IsLead: true})
	require.NoError(t, err)
	require.NotNil(t, a.CreatedBy)
	assert.Equal(t, ho.ID, *a.CreatedBy)
	assert.Nil(t, a.FA)

	_, err = w.svc.CreateAllocation(w.admin, geo.NewAllocation{FAID: ids.New(), Level: geo.LevelVillage, AreaID: w.gachibowli, IsLead: true})
	assert.True(t, apperr.Is(err, apperr.KindNotFound), "FK violation maps to not found")
}

func TestSnapshotSection(t *testing.T) {
	w := newWorld(t)
	fa := w.fa(t, "Lakshmi Devi", "active")
	w.allocate(t, fa, geo.LevelMandal, w.gandipet, true)
	w.allocate(t, fa, geo.LevelVillage, w.kondapur, true)

	reg := territory.NewRegistry()
	w.m.RegisterSnapshot(reg)
	// The farmers module owns the resolver; this stand-in uses geo's provider.
	reg.SetResolver(func(ctx context.Context, faID uuid.UUID) (territory.Scope, error) {
		vs, err := w.svc.VillageIDsForFA(ctx, faID)
		return territory.Scope{VillageIDs: vs}, err
	})
	snap, err := reg.Build(context.Background(), fa)
	require.NoError(t, err)
	villages, ok := snap[territory.SectionVillages].([]geo.VillageInfo)
	require.True(t, ok, "%T", snap[territory.SectionVillages])
	require.Len(t, villages, 2)
	assert.Equal(t, "Kondapur", villages[0].Name)
	assert.Equal(t, "Serilingampally", villages[0].MandalName)
	assert.Equal(t, "Narsingi", villages[1].Name)
	assert.Equal(t, "రంగారెడ్డి", *villages[1].DistrictNameTe)

	got, err := w.svc.GetVillages(context.Background(), []uuid.UUID{w.narsingi, unknownID})
	require.NoError(t, err)
	require.Len(t, got, 1)
	assert.Equal(t, xmod.Village{ID: w.narsingi, Name: "Narsingi", NameTe: str("నార్సింగి"), MandalID: w.gandipet, MandalName: "Gandipet",
		MandalNameTe: str("గండిపేట"), DistrictID: w.rangareddy, DistrictName: "Rangareddy", DistrictNameTe: str("రంగారెడ్డి")}, got[0])
}
