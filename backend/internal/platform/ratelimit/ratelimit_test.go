package ratelimit

import (
	"context"
	"errors"
	"net"
	"sync"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

type memStore struct {
	mu   sync.Mutex
	n    map[string]int
	fail bool
}

func (m *memStore) Incr(_ context.Context, key string, ws time.Time) (int, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.fail {
		return 0, errors.New("db down")
	}
	k := key + "|" + ws.String()
	m.n[k]++
	return m.n[k], nil
}

// deadRedis points at a port nothing listens on, simulating a Redis outage.
func deadRedis() *redis.Client {
	return redis.NewClient(&redis.Options{Addr: "redis-down:6379", MaxRetries: -1, DialerRetries: 1, DialerRetryTimeout: time.Millisecond, Dialer: func(context.Context, string, string) (net.Conn, error) {
		return nil, errors.New("redis down")
	}})
}

func TestFallbackWhenRedisDown(t *testing.T) {
	ctx := context.Background()
	clk := clock.NewFake(time.Date(2026, 1, 1, 10, 0, 30, 0, time.UTC))
	st := &memStore{n: map[string]int{}}
	l := NewWithStore(deadRedis(), st, clk, logx.Discard())

	for i := 0; i < 3; i++ {
		ok, err := l.Allow(ctx, "otp:+919848012345", 3, time.Minute)
		require.NoError(t, err)
		assert.True(t, ok, "attempt %d", i+1)
	}
	ok, err := l.Allow(ctx, "otp:+919848012345", 3, time.Minute)
	require.NoError(t, err)
	assert.False(t, ok, "4th attempt in the window is blocked")

	clk.Advance(time.Minute) // next window
	ok, err = l.Allow(ctx, "otp:+919848012345", 3, time.Minute)
	require.NoError(t, err)
	assert.True(t, ok)
}

func TestNoRedisConfigured(t *testing.T) {
	st := &memStore{n: map[string]int{}}
	l := NewWithStore(nil, st, clock.System(), logx.Discard())
	ok, err := l.Allow(context.Background(), "k", 1, time.Hour)
	require.NoError(t, err)
	assert.True(t, ok)
	ok, _ = l.Allow(context.Background(), "k", 1, time.Hour)
	assert.False(t, ok)
}

func TestBothDownReturnsError(t *testing.T) {
	l := NewWithStore(deadRedis(), &memStore{fail: true}, clock.System(), logx.Discard())
	_, err := l.Allow(context.Background(), "k", 1, time.Hour)
	require.Error(t, err)
}

func TestInvalidArgs(t *testing.T) {
	l := NewWithStore(nil, &memStore{n: map[string]int{}}, nil, nil)
	_, err := l.Allow(context.Background(), "k", 0, time.Hour)
	require.Error(t, err)
}
