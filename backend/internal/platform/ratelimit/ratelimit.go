// Package ratelimit limits attempts per key (OTP sends, logins, ...).
//
// It uses Redis GCRA (go-redis/redis_rate) when Redis is available and falls
// back to fixed-window counters in the Postgres rate_limit_counters table when
// Redis is missing or erroring, so limits hold even during a Redis outage.
package ratelimit

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/go-redis/redis_rate/v10"
	"github.com/redis/go-redis/v9"

	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/db"
)

// Store is the fallback counter store. CounterStore (Postgres) is the real one.
type Store interface {
	// Incr increments the counter for (key, windowStart) and returns the new count.
	Incr(ctx context.Context, key string, windowStart time.Time) (int, error)
}

// Limiter checks and consumes rate-limit budget.
type Limiter struct {
	redis    *redis_rate.Limiter // nil when Redis is not configured
	fallback Store
	clock    clock.Clock
	log      *slog.Logger
}

// New builds a Limiter. rdb may be nil (Postgres-only). pool is used for the
// fallback counters.
func New(rdb *redis.Client, pool db.DBTX, clk clock.Clock, log *slog.Logger) *Limiter {
	return NewWithStore(rdb, CounterStore{DB: pool}, clk, log)
}

// NewWithStore is New with an explicit fallback store (tests).
func NewWithStore(rdb *redis.Client, store Store, clk clock.Clock, log *slog.Logger) *Limiter {
	l := &Limiter{fallback: store, clock: clk, log: log}
	if l.log == nil {
		l.log = slog.Default()
	}
	if l.clock == nil {
		l.clock = clock.System()
	}
	if rdb != nil {
		l.redis = redis_rate.NewLimiter(rdb)
	}
	return l
}

// Allow consumes one unit from key's budget of limit per window and reports
// whether the call is allowed. Keys should be namespaced, e.g.
// "otp:send:+919848012345". An error is returned only if both Redis and
// Postgres fail; callers should then fail closed (apperr.Unavailable).
func (l *Limiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (bool, error) {
	if limit <= 0 || window <= 0 {
		return false, errors.New("ratelimit: limit and window must be positive")
	}
	if l.redis != nil {
		res, err := l.redis.Allow(ctx, "rl:"+key, redis_rate.Limit{Rate: limit, Burst: limit, Period: window})
		if err == nil {
			return res.Allowed > 0, nil
		}
		l.log.WarnContext(ctx, "ratelimit: redis failed, using postgres fallback", "key", key, "err", err)
	}
	start := l.clock.Now().Truncate(window)
	n, err := l.fallback.Incr(ctx, key, start)
	if err != nil {
		return false, fmt.Errorf("ratelimit: fallback: %w", err)
	}
	return n <= limit, nil
}

// CounterStore implements Store on the rate_limit_counters table.
type CounterStore struct{ DB db.DBTX }

// Incr upserts the window row and returns the incremented count.
func (s CounterStore) Incr(ctx context.Context, key string, windowStart time.Time) (int, error) {
	var n int
	err := s.DB.QueryRow(ctx, `
		INSERT INTO rate_limit_counters (key, window_start, count) VALUES ($1, $2, 1)
		ON CONFLICT (key, window_start) DO UPDATE SET count = rate_limit_counters.count + 1
		RETURNING count`, key, windowStart).Scan(&n)
	return n, err
}

// MaxWindow is the longest window callers should use: PurgeExpired keeps two
// of them, so a live window is never deleted.
const MaxWindow = 24 * time.Hour

// PurgeBefore deletes fallback windows that started before t and returns how
// many rows went.
func (s CounterStore) PurgeBefore(ctx context.Context, t time.Time) (int64, error) {
	tag, err := s.DB.Exec(ctx, `DELETE FROM rate_limit_counters WHERE window_start < $1`, t)
	if err != nil {
		return 0, fmt.Errorf("ratelimit: purge: %w", err)
	}
	return tag.RowsAffected(), nil
}

// PurgeExpired deletes the Postgres fallback counters whose window has long
// ended (older than 2 x MaxWindow before now). The identity maintenance job
// calls it periodically.
func PurgeExpired(ctx context.Context, q db.DBTX, now time.Time) (int64, error) {
	return CounterStore{DB: q}.PurgeBefore(ctx, now.Add(-2*MaxWindow))
}
