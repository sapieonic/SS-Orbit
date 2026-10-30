package geo_test

import (
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/geo"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

func TestMasters(t *testing.T) {
	w := newWorld(t)

	tree, err := w.svc.AdminTree(w.admin)
	require.NoError(t, err)
	require.Len(t, tree.Districts, 2)
	assert.Equal(t, "Medchal", tree.Districts[0].Name, "sorted by name")
	rr := tree.Districts[1]
	assert.Equal(t, "రంగారెడ్డి", *rr.NameTe)
	assert.Equal(t, 4, rr.VillageCount)
	require.Len(t, rr.Mandals, 2)
	assert.Equal(t, "Gandipet", rr.Mandals[0].Name)
	assert.Equal(t, 3, rr.Mandals[1].VillageCount)

	// Unique rules come back as specific 409s.
	_, err = w.svc.CreateDistrict(w.admin, geo.DistrictFields{Name: str("Rangareddy")})
	assert.Equal(t, "district_exists", errCode(t, err))
	_, err = w.svc.CreateMandal(w.admin, geo.MandalFields{DistrictID: w.rangareddy, Name: str("Gandipet")})
	assert.Equal(t, "mandal_exists", errCode(t, err))
	_, err = w.svc.CreateVillage(w.admin, geo.VillageFields{MandalID: w.serilingampally, Name: str("Kondapur")})
	assert.Equal(t, "village_exists", errCode(t, err))
	_, err = w.svc.CreateVillage(w.admin, geo.VillageFields{MandalID: unknownID, Name: str("X")})
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	// Edit: LGD code and centroid; then the code is taken for another village.
	lat, lng := 17.4699, 78.3578
	v, err := w.svc.UpdateVillage(w.admin, w.kondapur, geo.VillageFields{LGDCode: str("574123"), Lat: &lat, Lng: &lng})
	require.NoError(t, err)
	assert.Equal(t, "Kondapur", v.Name, "unsent fields unchanged")
	assert.Equal(t, "574123", *v.LGDCode)
	require.NotNil(t, v.Lat)
	assert.InDelta(t, lat, *v.Lat, 1e-9)
	assert.InDelta(t, lng, *v.Lng, 1e-9)
	assert.Equal(t, "Serilingampally", v.MandalName)
	assert.Equal(t, "Rangareddy", v.DistrictName)
	_, err = w.svc.UpdateVillage(w.admin, w.gachibowli, geo.VillageFields{LGDCode: str("574123")})
	assert.Equal(t, "lgd_code_taken", errCode(t, err))

	m, err := w.svc.UpdateMandal(w.admin, w.gandipet, geo.MandalFields{NameTe: str("గండిపేట్")})
	require.NoError(t, err)
	assert.Equal(t, "గండిపేట్", *m.NameTe)
	assert.Equal(t, "Rangareddy", m.DistrictName)

	// Writes invalidate nothing visible without Redis, but the tree reflects them.
	tree, err = w.svc.AdminTree(w.admin)
	require.NoError(t, err)
	assert.Equal(t, "గండిపేట్", *tree.Districts[1].Mandals[0].NameTe)

	assert.Equal(t, 5, w.count(t, `SELECT count(*) FROM audit_log WHERE action = 'geo.village_created'`))
	assert.Equal(t, 1, w.count(t, `SELECT count(*) FROM audit_log WHERE action = 'geo.village_updated' AND before IS NOT NULL`))
}

func TestVillageListAndSearch(t *testing.T) {
	w := newWorld(t)

	// Keyset pagination walks every village once, oldest first.
	two := 2
	seen := map[uuid.UUID]bool{}
	var cursor *string
	for range 10 {
		page, err := w.svc.ListVillages(w.admin, geo.VillageFilter{}, &two, cursor)
		require.NoError(t, err)
		for _, v := range page.Items {
			assert.False(t, seen[v.ID])
			seen[v.ID] = true
		}
		if page.NextCursor == nil {
			break
		}
		cursor = page.NextCursor
	}
	assert.Len(t, seen, 5)

	page, err := w.svc.ListVillages(w.admin, geo.VillageFilter{MandalID: &w.serilingampally}, nil, nil)
	require.NoError(t, err)
	assert.Len(t, page.Items, 3)

	search := func(q string, f geo.VillageFilter) []string {
		t.Helper()
		f.Q = &q
		vs, err := w.svc.SearchVillagesForFarmer(testutil.Ctx(testutil.Farmer()), f, nil)
		require.NoError(t, err)
		names := make([]string, len(vs))
		for i, v := range vs {
			names[i] = v.Name
		}
		return names
	}
	assert.Equal(t, []string{"Kondapur"}, search("kond", geo.VillageFilter{}), "prefix, any case")
	assert.Equal(t, []string{"Kondapur"}, search("కొండా", geo.VillageFilter{}), "Telugu")
	assert.Contains(t, search("Kondapor", geo.VillageFilter{}), "Kondapur", "trigram typo")
	assert.ElementsMatch(t, []string{"Madhapur", "Kondapur"}, search("pur", geo.VillageFilter{}), "substring")
	assert.Empty(t, search("%", geo.VillageFilter{}), "wildcards are literal")
	assert.Equal(t, []string{"Gachibowli", "Kondapur", "Madhapur"}, search("", geo.VillageFilter{MandalID: &w.serilingampally}),
		"no query lists by name")
	assert.Equal(t, []string{"Medchal"}, search("", geo.VillageFilter{DistrictID: &w.medchal}))

	// The farmer's pick carries mandal and district names.
	q := "Narsingi"
	vs, err := w.svc.SearchVillagesForFarmer(testutil.Ctx(testutil.Farmer()), geo.VillageFilter{Q: &q}, nil)
	require.NoError(t, err)
	require.Len(t, vs, 1)
	assert.Equal(t, "Gandipet", vs[0].MandalName)
	assert.Equal(t, "రంగారెడ్డి", *vs[0].DistrictNameTe)

	// HO search with q: best matches, no next page.
	page, err = w.svc.ListVillages(w.admin, geo.VillageFilter{Q: str("gachi")}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	assert.Nil(t, page.NextCursor)
}

func TestAreaScope(t *testing.T) {
	w := newWorld(t)
	medchalFinance := testutil.Ctx(testutil.HO(auth.RoleFinance, w.medchal))

	ds, err := w.svc.ListDistricts(medchalFinance)
	require.NoError(t, err)
	require.Len(t, ds, 1)
	assert.Equal(t, w.medchal, ds[0].ID)

	tree, err := w.svc.AdminTree(medchalFinance)
	require.NoError(t, err)
	require.Len(t, tree.Districts, 1)

	ms, err := w.svc.ListMandals(medchalFinance, nil)
	require.NoError(t, err)
	require.Len(t, ms, 1)

	page, err := w.svc.ListVillages(medchalFinance, geo.VillageFilter{}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	page, err = w.svc.ListVillages(medchalFinance, geo.VillageFilter{Q: str("Kondapur")}, nil, nil)
	require.NoError(t, err)
	assert.Empty(t, page.Items, "search is scoped too")

	_, err = w.svc.GetVillage(medchalFinance, w.kondapur)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))

	medchalOps := testutil.Ctx(testutil.HO(auth.RoleOps, w.medchal))
	_, err = w.svc.UpdateVillage(medchalOps, w.kondapur, geo.VillageFields{NameTe: str("x")})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	_, err = w.svc.CreateVillage(medchalOps, geo.VillageFields{MandalID: w.medchalMandal, Name: str("Gundlapochampally")})
	assert.NoError(t, err, "ops can add villages inside their scope")

	csv := "district,mandal,village\nRangareddy,Gandipet,Kokapet\n"
	_, err = w.svc.ImportVillages(medchalOps, strings.NewReader(csv), false)
	assert.Equal(t, "validation_failed", errCode(t, err), "rows outside the scope are rejected")
}

var unknownID = uuid.MustParse("01900000-0000-7000-8000-000000000001")
