package sync

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	gosync "sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/cache"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// fakeMasters is the Masters port.
type fakeMasters struct {
	mu      gosync.Mutex
	version int64
	err     error
}

func (f *fakeMasters) CurrentVersion(context.Context) (int64, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.version, f.err
}

func (f *fakeMasters) set(v int64) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.version = v
}

// fakeIdentity records MarkSynced calls.
type fakeIdentity struct {
	mu    gosync.Mutex
	calls []markSyncedCall
}

type markSyncedCall struct {
	FAID, DeviceID uuid.UUID
	At             time.Time
}

func (f *fakeIdentity) MarkSynced(_ context.Context, faID, deviceID uuid.UUID, at time.Time) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, markSyncedCall{faID, deviceID, at})
	return nil
}

func (f *fakeIdentity) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.calls)
}

// env is a sync module on orbit_test with fake ports and an FA (with a
// device row, since sync_commands references both).
type env struct {
	pool     *pgxpool.Pool
	deps     platform.Deps
	m        *Module
	svc      *Service
	masters  *fakeMasters
	identity *fakeIdentity
	fa       auth.Principal
}

// newEnv builds the env. c replaces the test cache (nil keeps testutil's
// Redis-less cache). Command handlers and snapshot providers are registered
// by each test on e.deps.Commands / e.deps.Territory before use.
func newEnv(t *testing.T, c *cache.Cache) *env {
	t.Helper()
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	if c != nil {
		deps.Cache = c
	}
	e := &env{pool: pool, deps: deps, masters: &fakeMasters{version: 7}, identity: &fakeIdentity{}}
	e.m = New(deps, &Ports{Masters: e.masters, Identity: e.identity})
	e.svc = e.m.Service()
	e.fa = e.newFA(t)
	return e
}

var faSeq int

// newFA inserts a field assistant and a device for it (identity's tables,
// written directly as test fixtures) and returns the FA principal.
func (e *env) newFA(t *testing.T) auth.Principal {
	t.Helper()
	faSeq++
	p := testutil.FA()
	ctx := context.Background()
	_, err := e.pool.Exec(ctx, `INSERT INTO field_assistants (id, code, name, phone, password_hash, level)
		VALUES ($1, $2, 'Suresh K', '+919000000001', 'x', 'village')`, p.ID, fmt.Sprintf("FA-TST-%03d-%s", faSeq, p.ID.String()[:8]))
	require.NoError(t, err)
	_, err = e.pool.Exec(ctx, `INSERT INTO devices (id, subject_kind, subject_id, device_key) VALUES ($1, 'fa', $2, 'test')`,
		p.DeviceID, p.ID)
	require.NoError(t, err)
	return p
}

func (e *env) ctx() context.Context { return testutil.Ctx(e.fa) }

func (e *env) countCommands(t *testing.T) int {
	t.Helper()
	var n int
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT count(*) FROM sync_commands`).Scan(&n))
	return n
}

// counter counts handler/provider calls by key.
type counter struct {
	mu gosync.Mutex
	n  map[string]int
}

func newCounter() *counter { return &counter{n: map[string]int{}} }

func (c *counter) inc(k string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.n[k]++
}

func (c *counter) get(k string) int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.n[k]
}

func mustJSON(t *testing.T, v any) json.RawMessage {
	t.Helper()
	b, err := json.Marshal(v)
	require.NoError(t, err)
	return b
}

// redisCache returns a cache on a real Redis (TEST_REDIS_URL, default the dev
// container) or skips. Keys in tests are per random FA ID, so no flushing.
func redisCache(t *testing.T) *cache.Cache {
	t.Helper()
	url := os.Getenv("TEST_REDIS_URL")
	if url == "" {
		url = "redis://localhost:6379/0"
	}
	rdb, err := cache.Open(url)
	require.NoError(t, err)
	t.Cleanup(func() { _ = rdb.Close() })
	c := cache.New(rdb, logx.Discard())
	if err := c.Ping(context.Background()); err != nil {
		t.Skipf("redis not reachable at %s: %v", url, err)
	}
	return c
}

// downCache is a cache whose Redis is unreachable: every call misses.
func downCache(t *testing.T) *cache.Cache {
	t.Helper()
	rdb, err := cache.Open("redis://127.0.0.1:1/0")
	require.NoError(t, err)
	t.Cleanup(func() { _ = rdb.Close() })
	return cache.New(rdb, logx.Discard())
}
