package farmers

import (
	"context"
	"encoding/json"
	"slices"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// ---- fake ports ----

type fakeGeo struct {
	villages   map[uuid.UUID]xmod.Village
	coverage   map[uuid.UUID][]xmod.Coverage // village -> FAs
	faVillages map[uuid.UUID][]uuid.UUID     // FA -> villages
}

func (g *fakeGeo) GetVillages(_ context.Context, ids []uuid.UUID) ([]xmod.Village, error) {
	out := []xmod.Village{}
	for _, id := range ids {
		if v, ok := g.villages[id]; ok {
			out = append(out, v)
		}
	}
	return out, nil
}

func (g *fakeGeo) FAsCoveringVillage(_ context.Context, id uuid.UUID) ([]xmod.Coverage, error) {
	return g.coverage[id], nil
}

func (g *fakeGeo) VillageIDsForFA(_ context.Context, faID uuid.UUID) ([]uuid.UUID, error) {
	return g.faVillages[faID], nil
}

// DistrictIDsForFAs derives each FA's districts from their villages.
func (g *fakeGeo) DistrictIDsForFAs(_ context.Context, faIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error) {
	out := map[uuid.UUID][]uuid.UUID{}
	for _, fa := range faIDs {
		for _, v := range g.faVillages[fa] {
			if d := g.villages[v].DistrictID; !slices.Contains(out[fa], d) {
				out[fa] = append(out[fa], d)
			}
		}
	}
	return out, nil
}

type fakeIdentity struct {
	fas map[uuid.UUID]xmod.FieldAssistant
}

func (f *fakeIdentity) GetFieldAssistants(_ context.Context, ids []uuid.UUID) ([]xmod.FieldAssistant, error) {
	out := []xmod.FieldAssistant{}
	for _, id := range ids {
		if fa, ok := f.fas[id]; ok {
			out = append(out, fa)
		}
	}
	return out, nil
}

// fakeMasters has stages for one crop: seedling days 0-29, flowering 30-120.
type fakeMasters struct {
	cropID uuid.UUID
	calls  int
}

func (m *fakeMasters) GetStagesForDay(_ context.Context, cropID uuid.UUID, day int) (xmod.Stage, error) {
	m.calls++
	if cropID != m.cropID || day > 120 {
		return xmod.Stage{}, apperr.NotFound("stage")
	}
	if day < 30 {
		return xmod.Stage{ID: uuid.NewSHA1(cropID, []byte("seedling")), CropID: cropID, Code: "seedling", Name: "Seedling", NameTe: "మొలక", Seq: 1, StartDay: 0, EndDay: 29}, nil
	}
	return xmod.Stage{ID: uuid.NewSHA1(cropID, []byte("flowering")), CropID: cropID, Code: "flowering", Name: "Flowering", NameTe: "పూత", Seq: 2, StartDay: 30, EndDay: 120}, nil
}

type fakeVisits struct {
	next map[uuid.UUID]*xmod.PlannedVisit
}

func (v *fakeVisits) NextPlannedVisit(_ context.Context, farmerID uuid.UUID) (*xmod.PlannedVisit, error) {
	return v.next[farmerID], nil
}

// ---- fixture: a small geography, two FAs and two crops in orbit_test ----

type fixture struct {
	t     *testing.T
	pool  *pgxpool.Pool
	deps  platform.Deps
	clock *clock.Fake
	svc   *Service
	geo   *fakeGeo
	ident *fakeIdentity
	mast  *fakeMasters
	vis   *fakeVisits

	district, mandal, village, village2 uuid.UUID // village2 is in the same mandal
	district2, mandal2, village3        uuid.UUID // another district
	fa1, fa2                            uuid.UUID // fa1 leads village; fa2 covers village3
	cotton, paddy                       uuid.UUID
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	clk := clock.NewFake(time.Date(2026, 10, 30, 6, 0, 0, 0, time.UTC))
	deps.Clock = clk
	deps.Tokens = auth.NewTokens(deps.Config.JWTSecret, deps.Config.JWTIssuer, deps.Config.AccessTokenTTL, clk)
	f := &fixture{
		t: t, pool: pool, deps: deps, clock: clk,
		district: ids.New(), mandal: ids.New(), village: ids.New(), village2: ids.New(),
		district2: ids.New(), mandal2: ids.New(), village3: ids.New(),
		fa1: ids.New(), fa2: ids.New(), cotton: ids.New(), paddy: ids.New(),
	}
	f.exec(`INSERT INTO districts (id, name) VALUES ($1, 'Rangareddy'), ($2, 'Medchal')`, f.district, f.district2)
	f.exec(`INSERT INTO mandals (id, district_id, name) VALUES ($1, $2, 'Serilingampally'), ($3, $4, 'Medchal')`,
		f.mandal, f.district, f.mandal2, f.district2)
	f.exec(`INSERT INTO villages (id, mandal_id, name) VALUES ($1, $2, 'Kondapur'), ($3, $2, 'Gachibowli'), ($4, $5, 'Kandlakoya')`,
		f.village, f.mandal, f.village2, f.village3, f.mandal2)
	f.exec(`INSERT INTO field_assistants (id, code, name, phone, password_hash, level) VALUES
		($1, 'FA-KDP-001', 'Suresh K', '+919848000001', 'x', 'village'),
		($2, 'FA-MDC-002', 'Farida S', '+919848000002', 'x', 'village')`, f.fa1, f.fa2)
	f.exec(`INSERT INTO crops (id, code, name, name_te) VALUES ($1, 'cotton', 'Cotton', 'పత్తి'), ($2, 'paddy', 'Paddy', 'వరి')`,
		f.cotton, f.paddy)

	vil := func(id, m, d uuid.UUID, name, mandal, district string) xmod.Village {
		return xmod.Village{ID: id, Name: name, MandalID: m, MandalName: mandal, DistrictID: d, DistrictName: district}
	}
	f.geo = &fakeGeo{
		villages: map[uuid.UUID]xmod.Village{
			f.village:  vil(f.village, f.mandal, f.district, "Kondapur", "Serilingampally", "Rangareddy"),
			f.village2: vil(f.village2, f.mandal, f.district, "Gachibowli", "Serilingampally", "Rangareddy"),
			f.village3: vil(f.village3, f.mandal2, f.district2, "Kandlakoya", "Medchal", "Medchal"),
		},
		coverage: map[uuid.UUID][]xmod.Coverage{
			f.village:  {{FAID: f.fa1, Level: "village", IsLead: true}},
			f.village3: {{FAID: f.fa2, Level: "village", IsLead: false}}, // no lead: self sign-ups stay unassigned
		},
		faVillages: map[uuid.UUID][]uuid.UUID{f.fa1: {f.village, f.village2}, f.fa2: {f.village3}},
	}
	f.ident = &fakeIdentity{fas: map[uuid.UUID]xmod.FieldAssistant{
		f.fa1: {ID: f.fa1, Code: "FA-KDP-001", Name: "Suresh K", Phone: "+919848000001", Level: "village", Status: "active"},
		f.fa2: {ID: f.fa2, Code: "FA-MDC-002", Name: "Farida S", Phone: "+919848000002", Level: "village", Status: "active"},
	}}
	f.mast = &fakeMasters{cropID: f.cotton}
	f.vis = &fakeVisits{next: map[uuid.UUID]*xmod.PlannedVisit{}}
	f.svc = NewService(deps, store.New(pool), &Ports{Identity: f.ident, Geo: f.geo, Masters: f.mast, Visits: f.vis})
	return f
}

func (f *fixture) exec(sql string, args ...any) {
	f.t.Helper()
	_, err := f.pool.Exec(context.Background(), sql, args...)
	require.NoError(f.t, err)
}

func (f *fixture) count(sql string, args ...any) int {
	f.t.Helper()
	var n int
	require.NoError(f.t, f.pool.QueryRow(context.Background(), sql, args...).Scan(&n))
	return n
}

// events returns the payloads of published events with this name.
func (f *fixture) events(name string) []map[string]any {
	f.t.Helper()
	rows, err := f.pool.Query(context.Background(),
		`SELECT args->'payload' FROM river_job WHERE kind = 'domain_event' AND args->>'name' = $1 ORDER BY id`, name)
	require.NoError(f.t, err)
	raws, err := pgx.CollectRows(rows, pgx.RowTo[[]byte])
	require.NoError(f.t, err)
	out := make([]map[string]any, len(raws))
	for i, r := range raws {
		require.NoError(f.t, json.Unmarshal(r, &out[i]))
	}
	return out
}

func (f *fixture) territoryVersion(faID uuid.UUID) int {
	return f.count(`SELECT COALESCE((SELECT version FROM territory_versions WHERE fa_id = $1), 0)`, faID)
}

func (f *fixture) farmer(id uuid.UUID) store.Farmer {
	f.t.Helper()
	r, err := store.New(f.pool).GetFarmer(context.Background(), id)
	require.NoError(f.t, err)
	return r
}

// selfSignUp creates a pending farmer as identity's OTP sign-up would.
func (f *fixture) selfSignUp(phoneNumber string) uuid.UUID {
	f.t.Helper()
	var id uuid.UUID
	err := db.WithTx(context.Background(), f.pool, func(tx pgx.Tx) error {
		var err error
		id, _, err = f.svc.FindOrCreateByPhone(context.Background(), tx, phoneNumber, SourceSelf)
		return err
	})
	require.NoError(f.t, err)
	return id
}

func faPrincipal(id uuid.UUID) auth.Principal {
	return auth.Principal{Kind: auth.KindFA, ID: id, DeviceID: ids.New(), SessionID: ids.New()}
}

func farmerCtx(id uuid.UUID) context.Context {
	return testutil.Ctx(auth.Principal{Kind: auth.KindFarmer, ID: id, DeviceID: ids.New(), SessionID: ids.New()})
}

func cmd(typ string) commands.Command { return commands.Command{ID: ids.New(), Type: typ} }

// enrol sends an EnrolFarmer (with a valid consent proof) as FA faID and
// requires a non-rejected result.
func (f *fixture) enrol(faID uuid.UUID, phoneNumber, name string, village uuid.UUID) (commands.Result, uuid.UUID) {
	f.t.Helper()
	in := f.enrolPayload(faID, phoneNumber, name, village)
	res, err := f.svc.EnrolFarmer(testutil.Ctx(faPrincipal(faID)), faPrincipal(faID), cmd("EnrolFarmer"), in)
	require.NoError(f.t, err)
	require.NotEqual(f.t, commands.StatusRejected, res.Status, "%v", res.Error)
	return res, in.FarmerID
}

// verifiedAt is when the test consent OTPs were verified: 10 minutes ago.
func (f *fixture) verifiedAt() time.Time { return f.clock.Now().Add(-10 * time.Minute) }

// proof issues a consent proof as identity would after the farmer read the
// OTP out to FA faID.
func (f *fixture) proof(faID uuid.UUID, phoneNumber string) *string {
	f.t.Helper()
	norm, err := phone.Normalize(phoneNumber)
	if err != nil {
		norm = phoneNumber // for payloads that test a bad phone number
	}
	tok, err := f.deps.Tokens.IssueConsentProof(auth.ConsentProof{FAID: faID, Phone: norm, VerifiedAt: f.verifiedAt()}, 7*24*time.Hour)
	require.NoError(f.t, err)
	return &tok
}

// enrolPayload is an enrolment with programme and soil_partner consent and a
// valid consent proof for FA faID.
func (f *fixture) enrolPayload(faID uuid.UUID, phoneNumber, name string, village uuid.UUID) EnrolFarmerPayload {
	return EnrolFarmerPayload{
		FarmerID: ids.New(), Phone: phoneNumber, Name: name, Language: "te", VillageID: village,
		Consent: EnrolConsent{Purposes: []string{"programme", "soil_partner"}, OTPProof: f.proof(faID, phoneNumber),
			AudioPlayed: true, NoticeVersion: "2026-10"},
	}
}

// squareAcre is a GeoJSON square of about one acre near Kondapur.
const squareAcre = `{"type":"Polygon","coordinates":[[[78.36,17.46],[78.3605995,17.46],[78.3605995,17.4605713],[78.36,17.4605713],[78.36,17.46]]]}`
