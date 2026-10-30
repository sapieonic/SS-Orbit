// Package cache is a thin, failure-tolerant wrapper over Redis. Every method
// treats Redis being down (or not configured) as a cache miss and logs a
// warning; callers never see Redis errors. Never store anything here that
// cannot be rebuilt from Postgres.
package cache

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

// Open parses a redis:// URL and returns a client. It does not ping; Redis may
// come up later. An empty url returns (nil, nil): run without Redis.
func Open(url string) (*redis.Client, error) {
	if url == "" {
		return nil, nil
	}
	opts, err := redis.ParseURL(url)
	if err != nil {
		return nil, fmt.Errorf("cache: parse REDIS_URL: %w", err)
	}
	opts.DialTimeout = 500 * time.Millisecond
	opts.ReadTimeout = 500 * time.Millisecond
	opts.WriteTimeout = 500 * time.Millisecond
	opts.MaxRetries = 1
	// Fail fast when Redis is down: go-redis defaults to 5 dial retries 100ms
	// apart, which would add ~0.5s to every request during an outage.
	opts.DialerRetries = 1
	opts.DialerRetryTimeout = 10 * time.Millisecond
	return redis.NewClient(opts), nil
}

// Cache wraps a Redis client. A nil client means "no Redis": every Get misses.
type Cache struct {
	rdb *redis.Client
	log *slog.Logger
}

// New wraps rdb (may be nil).
func New(rdb *redis.Client, log *slog.Logger) *Cache {
	if log == nil {
		log = slog.Default()
	}
	return &Cache{rdb: rdb, log: log}
}

// Client exposes the raw client (may be nil) for platform packages such as
// ratelimit. Modules should use the typed helpers.
func (c *Cache) Client() *redis.Client {
	if c == nil {
		return nil
	}
	return c.rdb
}

// Ping returns an error if Redis is not configured or unreachable (readyz).
func (c *Cache) Ping(ctx context.Context) error {
	if c == nil || c.rdb == nil {
		return errors.New("redis not configured")
	}
	return c.rdb.Ping(ctx).Err()
}

// Get returns the raw bytes at key and whether it was found.
func (c *Cache) Get(ctx context.Context, key string) ([]byte, bool) {
	if c == nil || c.rdb == nil {
		return nil, false
	}
	b, err := c.rdb.Get(ctx, key).Bytes()
	if err != nil {
		if !errors.Is(err, redis.Nil) {
			c.log.WarnContext(ctx, "cache get failed", "key", key, "err", err)
		}
		return nil, false
	}
	return b, true
}

// Set stores raw bytes with a TTL (0 = no expiry). Failures are logged.
func (c *Cache) Set(ctx context.Context, key string, val []byte, ttl time.Duration) {
	if c == nil || c.rdb == nil {
		return
	}
	if err := c.rdb.Set(ctx, key, val, ttl).Err(); err != nil {
		c.log.WarnContext(ctx, "cache set failed", "key", key, "err", err)
	}
}

// GetJSON decodes the JSON value at key into dst. It returns false on a miss,
// on a Redis error, or if the stored value no longer decodes.
func (c *Cache) GetJSON(ctx context.Context, key string, dst any) bool {
	b, ok := c.Get(ctx, key)
	if !ok {
		return false
	}
	if err := json.Unmarshal(b, dst); err != nil {
		c.log.WarnContext(ctx, "cache decode failed", "key", key, "err", err)
		return false
	}
	return true
}

// SetJSON encodes v as JSON and stores it with a TTL.
func (c *Cache) SetJSON(ctx context.Context, key string, v any, ttl time.Duration) {
	b, err := json.Marshal(v)
	if err != nil {
		c.log.WarnContext(ctx, "cache encode failed", "key", key, "err", err)
		return
	}
	c.Set(ctx, key, b, ttl)
}

// Delete removes keys. Failures are logged.
func (c *Cache) Delete(ctx context.Context, keys ...string) {
	if c == nil || c.rdb == nil || len(keys) == 0 {
		return
	}
	if err := c.rdb.Del(ctx, keys...).Err(); err != nil {
		c.log.WarnContext(ctx, "cache delete failed", "keys", keys, "err", err)
	}
}
