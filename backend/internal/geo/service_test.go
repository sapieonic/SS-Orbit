package geo

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// fakeIdentity is the identity port: it returns the FAs it knows.
type fakeIdentity struct {
	fas   map[uuid.UUID]xmod.FieldAssistant
	err   error
	calls int
}

func (f *fakeIdentity) GetFieldAssistants(_ context.Context, ids []uuid.UUID) ([]xmod.FieldAssistant, error) {
	f.calls++
	if f.err != nil {
		return nil, f.err
	}
	var out []xmod.FieldAssistant
	for _, id := range ids {
		if fa, ok := f.fas[id]; ok {
			out = append(out, fa)
		}
	}
	return out, nil
}

// Rules that are decided before the database is touched; the service has no
// store, so reaching the database would panic.
func TestAuthorizationBeforeDB(t *testing.T) {
	svc := NewService(platform.Deps{}, nil, nil)
	district := ids.New()
	hoCtx := func(r auth.Role, d ...uuid.UUID) context.Context { return testutil.Ctx(testutil.HO(r, d...)) }
	name := "Medchal"

	writes := map[string]func(ctx context.Context) error{
		"create district": func(ctx context.Context) error {
			_, err := svc.CreateDistrict(ctx, DistrictFields{Name: &name})
			return err
		},
		"create mandal": func(ctx context.Context) error {
			_, err := svc.CreateMandal(ctx, MandalFields{DistrictID: district, Name: &name})
			return err
		},
		"import": func(ctx context.Context) error {
			_, err := svc.ImportVillages(ctx, strings.NewReader("district,mandal,village\nA,B,C\n"), false)
			return err
		},
		"create allocation": func(ctx context.Context) error {
			_, err := svc.CreateAllocation(ctx, NewAllocation{FAID: ids.New(), Level: "village", AreaID: ids.New(), IsLead: true})
			return err
		},
		"end allocation": func(ctx context.Context) error { _, err := svc.EndAllocation(ctx, ids.New()); return err },
		"handover": func(ctx context.Context) error {
			_, err := svc.Handover(ctx, ids.New(), ids.New())
			return err
		},
	}
	for name, call := range writes {
		t.Run(name, func(t *testing.T) {
			assert.True(t, apperr.Is(call(context.Background()), apperr.KindUnauthorized))
			assert.True(t, apperr.Is(call(hoCtx(auth.RoleAgronomy)), apperr.KindForbidden), "agronomy reads only")
			assert.True(t, apperr.Is(call(hoCtx(auth.RoleFinance)), apperr.KindForbidden), "finance reads only")
			assert.True(t, apperr.Is(call(testutil.Ctx(testutil.FA())), apperr.KindForbidden))
			assert.True(t, apperr.Is(call(testutil.Ctx(testutil.Farmer())), apperr.KindForbidden))
		})
	}

	t.Run("area-scoped user cannot add a district", func(t *testing.T) {
		_, err := svc.CreateDistrict(hoCtx(auth.RoleAdmin, district), DistrictFields{Name: &name})
		assert.True(t, apperr.Is(err, apperr.KindForbidden))
	})
	t.Run("area-scoped user cannot add a mandal elsewhere", func(t *testing.T) {
		_, err := svc.CreateMandal(hoCtx(auth.RoleOps, district), MandalFields{DistrictID: ids.New(), Name: &name})
		assert.True(t, apperr.Is(err, apperr.KindForbidden))
	})
	t.Run("area-scoped reads outside scope", func(t *testing.T) {
		other := ids.New()
		_, err := svc.ListMandals(hoCtx(auth.RoleFinance, district), &other)
		assert.True(t, apperr.Is(err, apperr.KindForbidden))
		_, err = svc.ListVillages(hoCtx(auth.RoleFinance, district), VillageFilter{DistrictID: &other}, nil, nil)
		assert.True(t, apperr.Is(err, apperr.KindForbidden))
		_, err = svc.ListAllocations(hoCtx(auth.RoleFinance, district), AllocationFilter{DistrictID: &other}, nil, nil)
		assert.True(t, apperr.Is(err, apperr.KindForbidden))
	})
	t.Run("surfaces", func(t *testing.T) {
		_, err := svc.FarmerTree(hoCtx(auth.RoleAdmin))
		assert.True(t, apperr.Is(err, apperr.KindForbidden), "farmer picker is for farmers")
		_, err = svc.SearchVillagesForFarmer(testutil.Ctx(testutil.FA()), VillageFilter{}, nil)
		assert.True(t, apperr.Is(err, apperr.KindForbidden))
		_, err = svc.AdminTree(testutil.Ctx(testutil.Farmer()))
		assert.True(t, apperr.Is(err, apperr.KindForbidden))
	})
}

func TestInputValidationBeforeDB(t *testing.T) {
	svc := NewService(platform.Deps{}, nil, nil)
	ctx := testutil.Ctx(testutil.HO(auth.RoleOps))
	blank := "   "
	lat := 17.4

	_, err := svc.CreateDistrict(ctx, DistrictFields{Name: &blank})
	assert.True(t, apperr.Is(err, apperr.KindValidation), "blank name")

	_, err = svc.CreateVillage(ctx, VillageFields{MandalID: ids.New(), Name: &blank})
	assert.True(t, apperr.Is(err, apperr.KindValidation))
	name := "Kondapur"
	_, err = svc.CreateVillage(ctx, VillageFields{MandalID: ids.New(), Name: &name, Lat: &lat})
	assert.True(t, apperr.Is(err, apperr.KindValidation), "lat without lng")

	_, err = svc.CreateAllocation(ctx, NewAllocation{FAID: ids.New(), Level: "state", AreaID: ids.New()})
	assert.True(t, apperr.Is(err, apperr.KindValidation))

	fa := ids.New()
	_, err = svc.Handover(ctx, fa, fa)
	assert.True(t, apperr.Is(err, apperr.KindValidation), "hand over to self")
}

func TestRequireFAs(t *testing.T) {
	active, inactive, missing := ids.New(), ids.New(), ids.New()
	idp := &fakeIdentity{fas: map[uuid.UUID]xmod.FieldAssistant{
		active:   {ID: active, Name: "Suresh K", Status: "active"},
		inactive: {ID: inactive, Name: "Gopal R", Status: "inactive"},
	}}
	svc := NewService(platform.Deps{}, nil, &Ports{Identity: idp})
	ctx := context.Background()

	assert.NoError(t, svc.requireFAs(ctx, []uuid.UUID{active}))
	assert.NoError(t, svc.requireFAs(ctx, []uuid.UUID{active}, inactive), "the FA handing over may be inactive")

	err := svc.requireFAs(ctx, []uuid.UUID{missing})
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	err = svc.requireFAs(ctx, []uuid.UUID{inactive})
	e, ok := apperr.As(err)
	require.True(t, ok)
	assert.Equal(t, "fa_inactive", e.Code)

	// Without the port the foreign key is the only check.
	assert.NoError(t, NewService(platform.Deps{}, nil, nil).requireFAs(ctx, []uuid.UUID{missing}))
}

func TestParseVillageCSV(t *testing.T) {
	ok := "\uFEFFDistrict, Mandal ,village,name_te,lgd_code,lat,lng\n" +
		"Rangareddy,Serilingampally,Kondapur,కొండాపూర్,574123,17.4699,78.3578\n" +
		"\n" +
		"rangareddy,serilingampally,  Gachibowli  ,,,,\n"
	rows, err := parseVillageCSV(strings.NewReader(ok))
	require.NoError(t, err)
	require.Len(t, rows, 2)
	assert.Equal(t, 2, rows[0].line)
	assert.Equal(t, "Kondapur", rows[0].village)
	assert.Equal(t, "కొండాపూర్", *rows[0].nameTe)
	assert.Equal(t, "574123", *rows[0].lgdCode)
	assert.InDelta(t, 78.3578, *rows[0].lng, 1e-9)
	assert.Equal(t, 4, rows[1].line, "blank lines are skipped but line numbers stay true")
	assert.Equal(t, "Gachibowli", rows[1].village)
	assert.Nil(t, rows[1].nameTe)
	assert.Nil(t, rows[1].lat)

	// Columns in any order, optional ones absent.
	rows, err = parseVillageCSV(strings.NewReader("village,mandal,district\nKondapur,Serilingampally,Rangareddy\n"))
	require.NoError(t, err)
	assert.Equal(t, "Rangareddy", rows[0].district)

	bad := []struct {
		name, csv, field string
	}{
		{"empty", "", "body"},
		{"header only", "district,mandal,village\n", "body"},
		{"missing column", "district,village\nA,B\n", "header"},
		{"unknown column", "district,mandal,village,pincode\nA,B,C,500084\n", "header"},
		{"missing village", "district,mandal,village\nA,B,\n", "row 2"},
		{"bad lgd", "district,mandal,village,lgd_code\nA,B,C,12a\n", "row 2"},
		{"lat without lng", "district,mandal,village,lat,lng\nA,B,C,17.4,\n", "row 2"},
		{"lat out of range", "district,mandal,village,lat,lng\nA,B,C,97.4,78\n", "row 2"},
		{"duplicate village", "district,mandal,village\nA,B,C\na,b,c\n", "row 3"},
		{"duplicate lgd", "district,mandal,village,lgd_code\nA,B,C,1\nA,B,D,1\n", "row 3"},
	}
	for _, c := range bad {
		t.Run(c.name, func(t *testing.T) {
			_, err := parseVillageCSV(strings.NewReader(c.csv))
			e, ok := apperr.As(err)
			require.True(t, ok, "got %v", err)
			assert.Equal(t, "validation_failed", e.Code)
			fields, _ := e.Details["fields"].(map[string]string)
			assert.Contains(t, fields, c.field, e.Error())
		})
	}
}

func TestEscapeLikeAndSearchText(t *testing.T) {
	assert.Equal(t, `50\%\_off\\`, escapeLike(`50%_off\`))
	q := "  Kondapur   village "
	assert.Equal(t, "Kondapur village", searchText(&q))
	assert.Equal(t, "", searchText(nil))
}
