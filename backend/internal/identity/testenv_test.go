package identity

import (
	"context"
	"regexp"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/ratelimit"
	"github.com/sapionic/orbit/backend/internal/platform/reqctx"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// fakeFarmers stands in for the farmers module: one farmer per phone.
type fakeFarmers struct {
	mu      sync.Mutex
	byPhone map[string]uuid.UUID
	status  map[uuid.UUID]string
}

func (f *fakeFarmers) FindOrCreateByPhone(_ context.Context, _ pgx.Tx, phone, source string) (uuid.UUID, bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if source != "self" {
		return uuid.Nil, false, apperr.Validation("source", "unexpected")
	}
	if id, ok := f.byPhone[phone]; ok {
		return id, false, nil
	}
	id := ids.New()
	f.byPhone[phone] = id
	f.status[id] = "pending_profile"
	return id, true, nil
}

func (f *fakeFarmers) GetFarmerSummaries(_ context.Context, list []uuid.UUID) ([]xmod.FarmerSummary, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []xmod.FarmerSummary
	for _, id := range list {
		if st, ok := f.status[id]; ok {
			out = append(out, xmod.FarmerSummary{ID: id, Status: st})
		}
	}
	return out, nil
}

// captureSMS records messages instead of sending them.
type captureSMS struct {
	mu   sync.Mutex
	msgs []sms.Message
}

func (c *captureSMS) Send(_ context.Context, m sms.Message) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.msgs = append(c.msgs, m)
	return "test", nil
}

var codeRe = regexp.MustCompile(`\b[0-9]{6}\b`)

func (c *captureSMS) lastCode(t *testing.T) string {
	t.Helper()
	c.mu.Lock()
	defer c.mu.Unlock()
	require.NotEmpty(t, c.msgs)
	code := codeRe.FindString(c.msgs[len(c.msgs)-1].Body)
	require.NotEmpty(t, code)
	return code
}

// fakeGeo maps FAs to the districts of their allocations.
type fakeGeo struct {
	mu        sync.Mutex
	districts map[uuid.UUID][]uuid.UUID
	calls     int
}

func (g *fakeGeo) DistrictIDsForFAs(_ context.Context, faIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.calls++
	out := map[uuid.UUID][]uuid.UUID{}
	for _, id := range faIDs {
		if d, ok := g.districts[id]; ok {
			out[id] = d
		}
	}
	return out, nil
}

func (g *fakeGeo) allocate(faID uuid.UUID, districts ...uuid.UUID) {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.districts[faID] = districts
}

type env struct {
	svc     *Service
	pool    *pgxpool.Pool
	clock   *clock.Fake
	sms     *captureSMS
	farmers *fakeFarmers
	geo     *fakeGeo
}

// newEnv builds the module on orbit_test with a fake clock (shared by the
// rate limiter), captured SMS and a fake farmers port.
func newEnv(t testing.TB) *env {
	t.Helper()
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	clk := clock.NewFake(time.Now())
	deps.Clock = clk
	deps.Limiter = ratelimit.New(nil, pool, clk, logx.Discard())
	capture := &captureSMS{}
	deps.SMS = capture
	farmers := &fakeFarmers{byPhone: map[string]uuid.UUID{}, status: map[uuid.UUID]string{}}
	geo := &fakeGeo{districts: map[uuid.UUID][]uuid.UUID{}}
	m := New(deps, &Ports{Farmers: farmers, Geo: geo})
	return &env{svc: m.Service(), pool: pool, clock: clk, sms: capture, farmers: farmers, geo: geo}
}

// seedHO inserts an HO user with a known password and, if withTOTP, an
// enabled TOTP secret. Seeded users are active. Returns the row and a principal for it.
func (e *env) seedHO(t testing.TB, email string, role auth.Role, withTOTP bool) (store.HoUser, auth.Principal) {
	t.Helper()
	ctx := context.Background()
	hash, err := auth.HashPassword("Start-1234")
	require.NoError(t, err)
	q := store.New(e.pool)
	u, err := q.CreateHOUser(ctx, store.CreateHOUserParams{ID: ids.New(), Email: email, Name: "Seed " + string(role),
		PasswordHash: hash, Role: string(role), DistrictIds: []uuid.UUID{}})
	require.NoError(t, err)
	u, err = q.SetHOUserStatus(ctx, store.SetHOUserStatusParams{Status: HOActive, ID: u.ID})
	require.NoError(t, err)
	if withTOTP {
		secret, _, err := auth.GenerateTOTP(totpIssuer, email)
		require.NoError(t, err)
		require.NoError(t, q.SetHOUserTOTP(ctx, store.SetHOUserTOTPParams{TotpSecret: &secret, TotpEnabled: true, ID: u.ID}))
		u.TotpSecret, u.TotpEnabled = &secret, true
	}
	return u, auth.Principal{Kind: auth.KindHO, ID: u.ID, Role: role, SessionID: ids.New()}
}

// farmerLogin runs the OTP flow for phone on device key.
func (e *env) farmerLogin(t *testing.T, phone, deviceKey string) FarmerLogin {
	t.Helper()
	ctx := anonCtx()
	_, err := e.svc.RequestOTP(ctx, phone, "te")
	require.NoError(t, err)
	out, err := e.svc.VerifyOTP(ctx, phone, e.sms.lastCode(t), AppDevice{Key: deviceKey})
	require.NoError(t, err)
	e.clock.Advance(31 * time.Second) // past the resend gap
	return out
}

// anonCtx is a request context with no principal (sign-in endpoints).
func anonCtx() context.Context {
	return reqctx.With(context.Background(), reqctx.Meta{RequestID: "test-" + ids.New().String(), IP: "127.0.0.1"})
}

func (e *env) count(t *testing.T, sql string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, e.pool.QueryRow(context.Background(), sql, args...).Scan(&n))
	return n
}

func appCode(err error) string {
	if e, ok := apperr.As(err); ok {
		return e.Code
	}
	return ""
}
