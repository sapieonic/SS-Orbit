package platform_test

import (
	"context"
	"errors"
	"net"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/ratelimit"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// Integration tests for platform pieces that touch Postgres.

func TestRateLimitPostgresFallback(t *testing.T) {
	pool := testutil.NewDB(t)
	dead := redis.NewClient(&redis.Options{Addr: "redis-down:6379", MaxRetries: -1, DialerRetries: 1, DialerRetryTimeout: time.Millisecond, Dialer: func(context.Context, string, string) (net.Conn, error) {
		return nil, errors.New("redis down")
	}})
	l := ratelimit.New(dead, pool, clock.NewFake(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)), logx.Discard())
	ctx := context.Background()
	for i := range 2 {
		ok, err := l.Allow(ctx, "login:FA-KDP-014", 2, time.Minute)
		require.NoError(t, err)
		assert.True(t, ok, "attempt %d", i+1)
	}
	ok, err := l.Allow(ctx, "login:FA-KDP-014", 2, time.Minute)
	require.NoError(t, err)
	assert.False(t, ok)

	var n int
	require.NoError(t, pool.QueryRow(ctx, `SELECT count FROM rate_limit_counters WHERE key = 'login:FA-KDP-014'`).Scan(&n))
	assert.Equal(t, 3, n)
}

func TestTerritoryBump(t *testing.T) {
	pool := testutil.NewDB(t)
	ctx := context.Background()
	a, b := ids.New(), ids.New()
	v, err := territory.Version(ctx, pool, a)
	require.NoError(t, err)
	assert.Zero(t, v)

	for range 2 {
		require.NoError(t, db.WithTx(ctx, pool, func(tx pgx.Tx) error {
			return territory.Bump(ctx, tx, a, b, a) // duplicates ignored
		}))
	}
	v, _ = territory.Version(ctx, pool, a)
	assert.Equal(t, int64(2), v)

	// Rolled-back transactions do not bump.
	_ = db.WithTx(ctx, pool, func(tx pgx.Tx) error {
		_ = territory.Bump(ctx, tx, a)
		return assert.AnError
	})
	v, _ = territory.Version(ctx, pool, a)
	assert.Equal(t, int64(2), v)
}

func TestPublishIsTransactional(t *testing.T) {
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	ctx := context.Background()
	count := func() int {
		var n int
		require.NoError(t, pool.QueryRow(ctx, `SELECT count(*) FROM river_job WHERE kind = $1`, events.KindDomainEvent).Scan(&n))
		return n
	}
	_ = db.WithTx(ctx, pool, func(tx pgx.Tx) error {
		require.NoError(t, deps.Events.Publish(ctx, tx, events.SystemPing{Message: "rolled back"}))
		return assert.AnError
	})
	assert.Equal(t, 0, count(), "event discarded with its transaction")
	require.NoError(t, db.WithTx(ctx, pool, func(tx pgx.Tx) error {
		return deps.Events.Publish(ctx, tx, events.SystemPing{Message: "committed"})
	}))
	assert.Equal(t, 1, count())
}

func TestRateLimitPurgeExpired(t *testing.T) {
	pool := testutil.NewDB(t)
	ctx := context.Background()
	now := time.Date(2026, 3, 10, 12, 0, 0, 0, time.UTC)
	_, err := pool.Exec(ctx, `INSERT INTO rate_limit_counters (key, window_start, count) VALUES
		('old', $1, 3), ('recent', $2, 1)`, now.Add(-72*time.Hour), now.Add(-time.Hour))
	require.NoError(t, err)
	n, err := ratelimit.PurgeExpired(ctx, pool, now)
	require.NoError(t, err)
	assert.EqualValues(t, 1, n)
	var left string
	require.NoError(t, pool.QueryRow(ctx, `SELECT string_agg(key, ',') FROM rate_limit_counters`).Scan(&left))
	assert.Equal(t, "recent", left)
}
