package testutil

import (
	"context"
	"net/http"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/cache"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/jobs"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/push"
	"github.com/sapionic/orbit/backend/internal/platform/ratelimit"
	"github.com/sapionic/orbit/backend/internal/platform/reqctx"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/platform/storage"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// NewDeps builds platform.Deps for tests on pool (from NewDB): config from
// config.ForTest, no Redis (cache always misses, rate limits use Postgres),
// an insert-only River client, local storage in a temp dir, log SMS/push,
// the system clock (replace Deps.Clock with clock.NewFake if needed) and a
// discarding logger.
func NewDeps(t testing.TB, pool *pgxpool.Pool) platform.Deps {
	t.Helper()
	cfg := config.ForTest()
	cfg.StorageDir = t.TempDir()
	log := logx.Discard()
	clk := clock.System()

	j, err := jobs.NewInsertOnly(pool, log)
	if err != nil {
		t.Fatalf("testutil: jobs: %v", err)
	}
	st, err := storage.NewLocal(cfg.StorageDir, cfg.PublicBaseURL, []byte(cfg.StorageSigningKey), clk)
	if err != nil {
		t.Fatalf("testutil: storage: %v", err)
	}
	return platform.Deps{
		Config:    cfg,
		Pool:      pool,
		Cache:     cache.New(nil, log),
		Limiter:   ratelimit.New(nil, pool, clk, log),
		Jobs:      j,
		Events:    events.NewPublisher(j, clk),
		Tokens:    auth.NewTokens(cfg.JWTSecret, cfg.JWTIssuer, cfg.AccessTokenTTL, clk),
		Storage:   st,
		SMS:       sms.NewLog(log),
		Push:      push.NewLog(log),
		Clock:     clk,
		Logger:    log,
		Commands:  commands.NewRegistry(),
		Territory: territory.NewRegistry(),
	}
}

// Tokens returns a token service using the test config's secret. Use it in
// HTTP tests that don't need a database.
func Tokens() *auth.Tokens {
	cfg := config.ForTest()
	return auth.NewTokens(cfg.JWTSecret, cfg.JWTIssuer, cfg.AccessTokenTTL, nil)
}

// HO returns an HO principal with a random ID.
func HO(role auth.Role, districtIDs ...uuid.UUID) auth.Principal {
	return auth.Principal{Kind: auth.KindHO, ID: ids.New(), Role: role, DistrictIDs: districtIDs, SessionID: ids.New()}
}

// FA returns an FA principal with random ID, device and session.
func FA() auth.Principal {
	return auth.Principal{Kind: auth.KindFA, ID: ids.New(), DeviceID: ids.New(), SessionID: ids.New()}
}

// Farmer returns a farmer principal with random ID, device and session.
func Farmer() auth.Principal {
	return auth.Principal{Kind: auth.KindFarmer, ID: ids.New(), DeviceID: ids.New(), SessionID: ids.New()}
}

// Ctx returns a background context carrying p and a test request ID, as the
// HTTP middleware would for a real request.
func Ctx(p auth.Principal) context.Context {
	ctx := reqctx.With(context.Background(), reqctx.Meta{RequestID: "test-" + ids.New().String(), IP: "127.0.0.1"})
	return auth.WithPrincipal(ctx, p)
}

// Token mints an access token for p with tokens.
func Token(t testing.TB, tokens *auth.Tokens, p auth.Principal) string {
	t.Helper()
	tok, _, err := tokens.IssueAccess(p)
	if err != nil {
		t.Fatalf("testutil: token: %v", err)
	}
	return tok
}

// Router returns the production middleware stack (request ID, logging,
// recover, CORS, surface guard) with mounts applied, for HTTP tests:
//
//	r := testutil.Router(testutil.Tokens(), m.Mount)
//	req.Header.Set("Authorization", "Bearer "+testutil.Token(t, tokens, testutil.HO(auth.RoleAdmin)))
func Router(tokens *auth.Tokens, mounts ...func(chi.Router)) http.Handler {
	r := httpx.NewRouter(httpx.RouterConfig{Logger: logx.Discard(), Tokens: tokens})
	for _, m := range mounts {
		m(r)
	}
	return r
}
