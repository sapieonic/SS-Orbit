package messaging

import (
	"context"
	"errors"
	"fmt"
	"math/rand/v2"
	"slices"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/push"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Fake ports.

type fakeFarmers struct {
	mu       sync.Mutex
	farmers  map[uuid.UUID]xmod.FarmerSummary
	targeted []uuid.UUID // returned by FarmerIDsForTargeting
	lastT    xmod.FarmerTarget
	// and, when set, makes FarmerIDsForTargeting evaluate the target over
	// farmers like the real provider: every non-empty list narrows (AND).
	and *fakeGeo
}

func (f *fakeFarmers) FarmerIDsForTargeting(_ context.Context, t xmod.FarmerTarget) ([]uuid.UUID, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.lastT = t
	if f.and == nil {
		return f.targeted, nil
	}
	in := func(list []uuid.UUID, id uuid.UUID) bool { return len(list) == 0 || slices.Contains(list, id) }
	var out []uuid.UUID
	for id, fs := range f.farmers {
		if fs.Status != "active" || !fs.VillageID.Valid {
			continue
		}
		v := f.and.villages[fs.VillageID.UUID]
		if in(t.DistrictIDs, v.DistrictID) && in(t.MandalIDs, v.MandalID) && in(t.VillageIDs, v.ID) &&
			(t.Plan == nil || *t.Plan == fs.Plan) {
			out = append(out, id)
		}
	}
	return out, nil
}

func (f *fakeFarmers) GetFarmerSummaries(_ context.Context, ids []uuid.UUID) ([]xmod.FarmerSummary, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []xmod.FarmerSummary
	for _, id := range ids {
		if s, ok := f.farmers[id]; ok {
			out = append(out, s)
		}
	}
	return out, nil
}

type fakeGeo struct {
	villages    map[uuid.UUID]xmod.Village
	faDistricts map[uuid.UUID][]uuid.UUID
}

func (g *fakeGeo) DistrictIDsForFAs(_ context.Context, faIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error) {
	out := map[uuid.UUID][]uuid.UUID{}
	for _, id := range faIDs {
		if d, ok := g.faDistricts[id]; ok {
			out[id] = d
		}
	}
	return out, nil
}

func (g *fakeGeo) GetVillages(_ context.Context, ids []uuid.UUID) ([]xmod.Village, error) {
	var out []xmod.Village
	for _, id := range ids {
		if v, ok := g.villages[id]; ok {
			out = append(out, v)
		}
	}
	return out, nil
}

type fakeIdentity struct {
	fas      map[uuid.UUID]xmod.FieldAssistant
	tokens   map[uuid.UUID][]string // farmer and FA devices, by subject ID
	notSince []xmod.FieldAssistant  // returned by FAsNotSyncedSince
	since    time.Time
}

func (i *fakeIdentity) FAsNotSyncedSince(_ context.Context, since time.Time) ([]xmod.FieldAssistant, error) {
	i.since = since
	return i.notSince, nil
}

func (i *fakeIdentity) GetFieldAssistants(_ context.Context, ids []uuid.UUID) ([]xmod.FieldAssistant, error) {
	var out []xmod.FieldAssistant
	for _, id := range ids {
		if fa, ok := i.fas[id]; ok {
			out = append(out, fa)
		}
	}
	return out, nil
}

func (i *fakeIdentity) PushTokens(_ context.Context, kind string, ids []uuid.UUID) (map[uuid.UUID][]string, error) {
	out := map[uuid.UUID][]string{}
	for _, id := range ids {
		if t, ok := i.tokens[id]; ok {
			out[id] = t
		}
	}
	return out, nil
}

type fakeVisits struct {
	advice map[uuid.UUID]xmod.VisitAdvice
}

func (v *fakeVisits) GetVisitAdvice(_ context.Context, id uuid.UUID) (xmod.VisitAdvice, error) {
	a, ok := v.advice[id]
	if !ok {
		return xmod.VisitAdvice{}, apperr.NotFound("visit")
	}
	return a, nil
}

type fakeMasters struct{ terms []string }

func (m *fakeMasters) ProductTerms(context.Context) ([]string, error) { return m.terms, nil }

// Fake senders.

type fakeSMS struct {
	mu   sync.Mutex
	sent []sms.Message
	fail bool
}

func (f *fakeSMS) Send(_ context.Context, m sms.Message) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.fail {
		return "", errors.New("provider down")
	}
	f.sent = append(f.sent, m)
	return "sms-" + ids.New().String(), nil
}

type fakePush struct {
	mu   sync.Mutex
	sent []push.Message
	fail bool
}

func (f *fakePush) Send(_ context.Context, m push.Message) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.fail {
		return "", errors.New("fcm down")
	}
	f.sent = append(f.sent, m)
	return "push-" + ids.New().String(), nil
}

// env is a module on the test database with fake ports, senders and clock.
type env struct {
	t        *testing.T
	pool     *pgxpool.Pool
	deps     platform.Deps
	svc      *Service
	mod      *Module
	clock    *clock.Fake
	farmers  *fakeFarmers
	geo      *fakeGeo
	identity *fakeIdentity
	visits   *fakeVisits
	masters  *fakeMasters
	sms      *fakeSMS
	push     *fakePush
	district uuid.UUID
	village  xmod.Village
}

// noonIST is a time outside quiet hours.
var noonIST = time.Date(2026, 10, 30, 12, 0, 0, 0, ist)

func newEnv(t *testing.T) *env {
	t.Helper()
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	e := &env{t: t, pool: pool, clock: clock.NewFake(noonIST),
		farmers: &fakeFarmers{farmers: map[uuid.UUID]xmod.FarmerSummary{}}, geo: &fakeGeo{villages: map[uuid.UUID]xmod.Village{}},
		identity: &fakeIdentity{fas: map[uuid.UUID]xmod.FieldAssistant{}, tokens: map[uuid.UUID][]string{}},
		visits:   &fakeVisits{advice: map[uuid.UUID]xmod.VisitAdvice{}}, sms: &fakeSMS{}, push: &fakePush{},
		masters: &fakeMasters{terms: []string{"shanmukha boost", "imidacloprid", "ఇమిడాక్లోప్రిడ్"}}}
	deps.Clock, deps.SMS, deps.Push = e.clock, e.sms, e.push
	e.deps = deps
	e.mod = New(deps, &Ports{Farmers: e.farmers, Geo: e.geo, Identity: e.identity, Visits: e.visits, Masters: e.masters})
	e.svc = e.mod.Service()

	// One district > mandal > village, known to the fake geo port too.
	e.district = ids.New()
	mandal, village := ids.New(), ids.New()
	e.exec(`INSERT INTO districts (id, name) VALUES ($1, $2)`, e.district, "Kadapa-"+e.district.String()[24:])
	e.exec(`INSERT INTO mandals (id, district_id, name) VALUES ($1, $2, 'Pulivendula')`, mandal, e.district)
	e.exec(`INSERT INTO villages (id, mandal_id, name) VALUES ($1, $2, 'Kondapur')`, village, mandal)
	e.village = xmod.Village{ID: village, Name: "Kondapur", MandalID: mandal, MandalName: "Pulivendula",
		DistrictID: e.district, DistrictName: "Kadapa"}
	e.geo.villages[village] = e.village
	return e
}

func (e *env) exec(sql string, args ...any) {
	e.t.Helper()
	_, err := e.pool.Exec(context.Background(), sql, args...)
	require.NoError(e.t, err)
}

func (e *env) count(sql string, args ...any) int {
	e.t.Helper()
	var n int
	require.NoError(e.t, e.pool.QueryRow(context.Background(), sql, args...).Scan(&n))
	return n
}

// ho inserts an HO user and returns a context for them.
func (e *env) ho(role auth.Role, districts ...uuid.UUID) (auth.Principal, context.Context) {
	e.t.Helper()
	p := testutil.HO(role, districts...)
	if districts == nil {
		districts = []uuid.UUID{}
	}
	e.exec(`INSERT INTO ho_users (id, email, name, password_hash, role, district_ids) VALUES ($1, $2, 'HO', 'x', $3, $4)`,
		p.ID, p.ID.String()+"@example.com", string(role), districts)
	return p, testutil.Ctx(p)
}

// fa inserts an FA (also known to the identity port).
func (e *env) fa(name string) xmod.FieldAssistant {
	e.t.Helper()
	id := ids.New()
	fa := xmod.FieldAssistant{ID: id, Code: "FA-" + id.String()[24:], Name: name, Phone: "+919800000001", Level: "village", Status: "active"}
	e.exec(`INSERT INTO field_assistants (id, code, name, phone, password_hash, level) VALUES ($1, $2, $3, $4, 'x', 'village')`,
		id, fa.Code, name, fa.Phone)
	e.identity.fas[id] = fa
	return fa
}

// farmer inserts a farmer row and registers its summary with the farmers port.
func (e *env) farmer(name, lang, status string, faID uuid.NullUUID, villageID uuid.NullUUID) xmod.FarmerSummary {
	e.t.Helper()
	id := ids.New()
	phone := fmt.Sprintf("+9198%08d", rand.IntN(100_000_000))
	f := xmod.FarmerSummary{ID: id, Phone: phone, Name: &name, Language: lang, VillageID: villageID,
		AssignedFAID: faID, Plan: "free", Status: status, ProgrammeConsent: true}
	e.exec(`INSERT INTO farmers (id, phone, name, language, village_id, assigned_fa_id, source, status)
	        VALUES ($1, $2, $3, $4, $5, $6, 'self', $7)`, id, phone, name, lang, villageID, faID, status)
	e.farmers.farmers[id] = f
	return f
}

func (e *env) deliveries(noticeID uuid.UUID) []store.Delivery {
	e.t.Helper()
	rows, err := e.pool.Query(context.Background(), `SELECT id FROM deliveries WHERE notice_id = $1 ORDER BY channel`, noticeID)
	require.NoError(e.t, err)
	defer rows.Close()
	var out []store.Delivery
	for rows.Next() {
		var id uuid.UUID
		require.NoError(e.t, rows.Scan(&id))
		d, err := e.svc.q.GetDelivery(context.Background(), id)
		require.NoError(e.t, err)
		out = append(out, d)
	}
	return out
}

// sendAll works every queued delivery once (as the River worker would).
func (e *env) sendAll() {
	e.t.Helper()
	rows, err := e.pool.Query(context.Background(), `SELECT id FROM deliveries WHERE status = 'queued'`)
	require.NoError(e.t, err)
	var idsToSend []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		require.NoError(e.t, rows.Scan(&id))
		idsToSend = append(idsToSend, id)
	}
	rows.Close()
	for _, id := range idsToSend {
		require.NoError(e.t, e.svc.SendDelivery(context.Background(), id, 1, deliveryMaxAttempts))
	}
}

func nu(id uuid.UUID) uuid.NullUUID { return uuid.NullUUID{UUID: id, Valid: true} }

// testDepsNoDB is enough Deps for pure service methods.
func testDepsNoDB() platform.Deps {
	return platform.Deps{Clock: clock.NewFake(noonIST), Tokens: testutil.Tokens()}
}
