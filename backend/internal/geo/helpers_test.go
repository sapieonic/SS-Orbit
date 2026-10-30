package geo_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/geo"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// identityFake stands in for the identity module's GetFieldAssistants.
type identityFake struct {
	fas map[uuid.UUID]xmod.FieldAssistant
}

func (f *identityFake) GetFieldAssistants(_ context.Context, ids []uuid.UUID) ([]xmod.FieldAssistant, error) {
	var out []xmod.FieldAssistant
	for _, id := range ids {
		if fa, ok := f.fas[id]; ok {
			out = append(out, fa)
		}
	}
	return out, nil
}

// world is the sample geography the integrator seeds, plus a second district:
//
//	Rangareddy > Serilingampally > Kondapur, Gachibowli, Madhapur
//	Rangareddy > Gandipet > Narsingi
//	Medchal > Medchal > Medchal
type world struct {
	pool  *pgxpool.Pool
	deps  platform.Deps
	m     *geo.Module
	svc   *geo.Service
	ports *geo.Ports
	idp   *identityFake
	admin context.Context

	rangareddy, medchal                                      uuid.UUID
	serilingampally, gandipet, medchalMandal                 uuid.UUID
	kondapur, gachibowli, madhapur, narsingi, medchalVillage uuid.UUID
}

func newWorld(t *testing.T) *world {
	t.Helper()
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	w := &world{pool: pool, deps: deps, idp: &identityFake{fas: map[uuid.UUID]xmod.FieldAssistant{}}}
	w.ports = &geo.Ports{Identity: w.idp}
	w.m = geo.New(deps, w.ports)
	w.svc = w.m.Service()
	w.admin = testutil.Ctx(testutil.HO(auth.RoleAdmin))

	w.rangareddy = w.district(t, "Rangareddy", "రంగారెడ్డి")
	w.medchal = w.district(t, "Medchal", "మేడ్చల్")
	w.serilingampally = w.mandal(t, w.rangareddy, "Serilingampally", "శేరిలింగంపల్లి")
	w.gandipet = w.mandal(t, w.rangareddy, "Gandipet", "గండిపేట")
	w.medchalMandal = w.mandal(t, w.medchal, "Medchal", "మేడ్చల్")
	w.kondapur = w.village(t, w.serilingampally, "Kondapur", "కొండాపూర్")
	w.gachibowli = w.village(t, w.serilingampally, "Gachibowli", "గచ్చిబౌలి")
	w.madhapur = w.village(t, w.serilingampally, "Madhapur", "మాదాపూర్")
	w.narsingi = w.village(t, w.gandipet, "Narsingi", "నార్సింగి")
	w.medchalVillage = w.village(t, w.medchalMandal, "Medchal", "మేడ్చల్")
	return w
}

func str(s string) *string { return &s }

func (w *world) district(t *testing.T, name, te string) uuid.UUID {
	d, err := w.svc.CreateDistrict(w.admin, geo.DistrictFields{Name: str(name), NameTe: str(te)})
	require.NoError(t, err)
	return d.ID
}

func (w *world) mandal(t *testing.T, district uuid.UUID, name, te string) uuid.UUID {
	m, err := w.svc.CreateMandal(w.admin, geo.MandalFields{DistrictID: district, Name: str(name), NameTe: str(te)})
	require.NoError(t, err)
	return m.ID
}

func (w *world) village(t *testing.T, mandal uuid.UUID, name, te string) uuid.UUID {
	v, err := w.svc.CreateVillage(w.admin, geo.VillageFields{MandalID: mandal, Name: str(name), NameTe: str(te)})
	require.NoError(t, err)
	return v.ID
}

var faSeq int

// fa inserts a field_assistants row (identity's table; test fixture only) and
// registers it with the identity fake.
func (w *world) fa(t *testing.T, name, status string) uuid.UUID {
	t.Helper()
	faSeq++
	id := ids.New()
	code := fmt.Sprintf("FA-TST-%03d", faSeq)
	_, err := w.pool.Exec(context.Background(), `
		INSERT INTO field_assistants (id, code, name, phone, password_hash, level, status)
		VALUES ($1, $2, $3, '+919000000001', 'x', 'village', $4)`, id, code, name, status)
	require.NoError(t, err)
	w.idp.fas[id] = xmod.FieldAssistant{ID: id, Code: code, Name: name, Status: status}
	return id
}

func (w *world) allocate(t *testing.T, fa uuid.UUID, level string, area uuid.UUID, lead bool) geo.FAAllocation {
	t.Helper()
	a, err := w.svc.CreateAllocation(w.admin, geo.NewAllocation{FAID: fa, Level: level, AreaID: area, IsLead: lead})
	require.NoError(t, err)
	return a
}

func (w *world) version(t *testing.T, fa uuid.UUID) int64 {
	t.Helper()
	v, err := territory.Version(context.Background(), w.pool, fa)
	require.NoError(t, err)
	return v
}

func (w *world) count(t *testing.T, sql string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, w.pool.QueryRow(context.Background(), sql, args...).Scan(&n))
	return n
}

func errCode(t *testing.T, err error) string {
	t.Helper()
	e, ok := apperr.As(err)
	require.True(t, ok, "want an apperr, got %v", err)
	return e.Code
}
