package identity

import (
	"context"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/cache"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// The guard check's Redis cache. These need TEST_REDIS_URL (e.g.
// redis://localhost:6379/15) on top of TEST_DATABASE_URL; they skip otherwise.

func withRedis(tb testing.TB, e *env) {
	tb.Helper()
	url := os.Getenv("TEST_REDIS_URL")
	if url == "" {
		tb.Skip("TEST_REDIS_URL not set")
	}
	rdb, err := cache.Open(url)
	require.NoError(tb, err)
	require.NoError(tb, rdb.FlushDB(context.Background()).Err())
	tb.Cleanup(func() { _ = rdb.Close() })
	e.svc.deps.Cache = cache.New(rdb, logx.Discard())
}

func TestCheckPrincipalCacheIsClearedOnRevoke(t *testing.T) {
	e := newEnv(t)
	withRedis(t, e)
	ctx := context.Background()
	row, _ := e.seedHO(t, "ops@orbit.test", auth.RoleOps, true)
	in := e.hoLogin(t, row)
	p := e.principal(t, in.Tokens.Access)
	require.NoError(t, e.svc.CheckPrincipal(ctx, p)) // cached as live

	// Revoked behind identity's back: the cached answer is still used...
	_, err := e.pool.Exec(ctx, `UPDATE sessions SET revoked_at = now() WHERE id = $1`, p.SessionID)
	require.NoError(t, err)
	require.NoError(t, e.svc.CheckPrincipal(ctx, p), "served from cache")
	// ...until identity drops it, as every revoke path does after commit.
	e.svc.forgetSessions(ctx, p.SessionID)
	assert.Equal(t, "session_revoked", appCode(e.svc.CheckPrincipal(ctx, p)))

	// Through the service: sign-out clears the cache itself.
	in = e.hoLogin(t, row)
	p = e.principal(t, in.Tokens.Access)
	require.NoError(t, e.svc.CheckPrincipal(ctx, p))
	require.NoError(t, e.svc.Logout(testutil.Ctx(p), nil))
	assert.Equal(t, "session_revoked", appCode(e.svc.CheckPrincipal(ctx, p)))
}

// BenchmarkCheckPrincipalCacheHit measures the guard's per-request cost for
// an HO token when the answer is cached (one Redis GET).
func BenchmarkCheckPrincipalCacheHit(b *testing.B) {
	e := newEnv(b)
	withRedis(b, e)
	row, _ := e.seedHO(b, "ops@orbit.test", auth.RoleOps, true)
	p := e.principal(b, e.hoLogin(b, row).Tokens.Access)
	ctx := context.Background()
	require.NoError(b, e.svc.CheckPrincipal(ctx, p))
	b.ResetTimer()
	for b.Loop() {
		if err := e.svc.CheckPrincipal(ctx, p); err != nil {
			b.Fatal(err)
		}
	}
}

// BenchmarkCheckPrincipalNoRedis is the fallback cost (one Postgres query)
// when Redis is down.
func BenchmarkCheckPrincipalNoRedis(b *testing.B) {
	e := newEnv(b)
	row, _ := e.seedHO(b, "ops@orbit.test", auth.RoleOps, true)
	p := e.principal(b, e.hoLogin(b, row).Tokens.Access)
	ctx := context.Background()
	for b.Loop() {
		if err := e.svc.CheckPrincipal(ctx, p); err != nil {
			b.Fatal(err)
		}
	}
}
