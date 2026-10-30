package sync

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"io"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

type fakeFarmer struct {
	ID     uuid.UUID `json:"id"`
	NameTe string    `json:"name_te"`
}

// registerFakeSnapshot sets a resolver and two section providers; builds
// are counted under "build".
func registerFakeSnapshot(e *env, calls *counter) uuid.UUID {
	farmer := uuid.New()
	village := uuid.New()
	e.deps.Territory.SetResolver(func(_ context.Context, faID uuid.UUID) (territory.Scope, error) {
		calls.inc("build")
		return territory.Scope{FAID: faID, VillageIDs: []uuid.UUID{village}, FarmerIDs: []uuid.UUID{farmer}}, nil
	})
	e.deps.Territory.Register(territory.SectionFarmers, func(_ context.Context, s territory.Scope) (any, error) {
		return []fakeFarmer{{ID: s.FarmerIDs[0], NameTe: "రవి"}}, nil
	})
	e.deps.Territory.Register(territory.SectionVillages, func(_ context.Context, s territory.Scope) (any, error) {
		return s.VillageIDs, nil
	})
	return farmer
}

func gunzip(t *testing.T, b []byte) []byte {
	t.Helper()
	zr, err := gzip.NewReader(bytes.NewReader(b))
	require.NoError(t, err)
	out, err := io.ReadAll(zr)
	require.NoError(t, err)
	return out
}

func decodeEnvelope(t *testing.T, gz []byte) Snapshot {
	t.Helper()
	var s Snapshot
	require.NoError(t, json.Unmarshal(gunzip(t, gz), &s))
	return s
}

func (e *env) bump(t *testing.T) {
	t.Helper()
	ctx := context.Background()
	require.NoError(t, db.WithTx(ctx, e.pool, func(tx pgx.Tx) error { return territory.Bump(ctx, tx, e.fa.ID) }))
}

func TestSnapshotBuildETagAndNotModified(t *testing.T) {
	e := newEnv(t, nil) // no Redis: every miss rebuilds
	calls := newCounter()
	farmer := registerFakeSnapshot(e, calls)

	snap, err := e.svc.Snapshot(e.ctx(), "")
	require.NoError(t, err)
	assert.False(t, snap.NotModified)
	assert.Equal(t, `"t0-m7"`, snap.Versions.ETag())
	env := decodeEnvelope(t, snap.Gzip)
	assert.Equal(t, int64(0), env.TerritoryVersion)
	assert.Equal(t, int64(7), env.MastersVersion)
	assert.False(t, env.GeneratedAt.IsZero())
	require.Contains(t, env.Sections, "farmers")
	require.Contains(t, env.Sections, "villages")
	farmers := env.Sections["farmers"].([]any)
	assert.Equal(t, farmer.String(), farmers[0].(map[string]any)["id"])
	assert.Equal(t, "రవి", farmers[0].(map[string]any)["name_te"])
	assert.Equal(t, 1, e.identity.count())

	// Same ETag (also weak, also in a list): 304, nothing built.
	for _, inm := range []string{`"t0-m7"`, `W/"t0-m7"`, `"x", "t0-m7"`, `*`} {
		snap, err = e.svc.Snapshot(e.ctx(), inm)
		require.NoError(t, err)
		assert.True(t, snap.NotModified, inm)
		assert.Nil(t, snap.Gzip)
	}
	assert.Equal(t, 1, calls.get("build"))
	assert.Equal(t, 5, e.identity.count(), "an up-to-date check is a sync too")

	// A territory write or a masters publish changes the ETag.
	e.bump(t)
	snap, err = e.svc.Snapshot(e.ctx(), `"t0-m7"`)
	require.NoError(t, err)
	assert.False(t, snap.NotModified)
	assert.Equal(t, `"t1-m7"`, snap.Versions.ETag())
	e.masters.set(8)
	v, err := e.svc.Status(e.ctx())
	require.NoError(t, err)
	assert.Equal(t, `"t1-m8"`, v.ETag())
}

func TestSnapshotCachedInRedis(t *testing.T) {
	c := redisCache(t)
	e := newEnv(t, c)
	calls := newCounter()
	registerFakeSnapshot(e, calls)
	ctx := e.ctx()

	first, err := e.svc.Snapshot(ctx, "")
	require.NoError(t, err)
	second, err := e.svc.Snapshot(ctx, "")
	require.NoError(t, err)
	assert.Equal(t, 1, calls.get("build"), "second pull served from Redis")
	assert.Equal(t, first.Gzip, second.Gzip)

	key := snapshotKey(e.fa.ID, Versions{Territory: 0, Masters: 7})
	cached, ok := c.Get(ctx, key)
	require.True(t, ok, "stored under scope:{fa}:v{t}:m{m}")
	assert.Equal(t, first.Gzip, cached)

	// New version: new key, rebuilt; both keys indexed for the FA.
	e.bump(t)
	_, err = e.svc.Snapshot(ctx, "")
	require.NoError(t, err)
	assert.Equal(t, 2, calls.get("build"))
	var keys []string
	require.True(t, c.GetJSON(ctx, indexKey(e.fa.ID), &keys))
	assert.ElementsMatch(t, []string{key, snapshotKey(e.fa.ID, Versions{Territory: 1, Masters: 7})}, keys)

	// device.revoked for this FA drops every cached snapshot and the index.
	require.NoError(t, e.svc.onDeviceRevoked(ctx, events.DeviceRevoked{DeviceID: e.fa.DeviceID, SubjectKind: "fa", SubjectID: e.fa.ID}))
	for _, k := range append(keys, indexKey(e.fa.ID)) {
		_, ok := c.Get(ctx, k)
		assert.False(t, ok, k)
	}
	_, err = e.svc.Snapshot(ctx, "")
	require.NoError(t, err)
	assert.Equal(t, 3, calls.get("build"))
}

func TestDeviceRevokedIgnoresFarmers(t *testing.T) {
	c := redisCache(t)
	e := newEnv(t, c)
	registerFakeSnapshot(e, newCounter())
	_, err := e.svc.Snapshot(e.ctx(), "")
	require.NoError(t, err)

	require.NoError(t, e.svc.onDeviceRevoked(context.Background(), events.DeviceRevoked{SubjectKind: "farmer", SubjectID: e.fa.ID}))
	_, ok := c.Get(context.Background(), snapshotKey(e.fa.ID, Versions{Masters: 7}))
	assert.True(t, ok)
}

func TestSnapshotWithRedisDown(t *testing.T) {
	e := newEnv(t, downCache(t))
	calls := newCounter()
	registerFakeSnapshot(e, calls)

	for range 2 {
		snap, err := e.svc.Snapshot(e.ctx(), "")
		require.NoError(t, err)
		assert.Equal(t, int64(7), decodeEnvelope(t, snap.Gzip).MastersVersion)
	}
	assert.Equal(t, 2, calls.get("build"), "no cache: rebuilt each time")
	// Revocation with Redis down is a no-op, not an error (TTL covers it).
	require.NoError(t, e.svc.onDeviceRevoked(context.Background(), events.DeviceRevoked{SubjectKind: "fa", SubjectID: e.fa.ID}))
}

func TestSnapshotProviderFailure(t *testing.T) {
	e := newEnv(t, nil)
	e.deps.Territory.SetResolver(func(context.Context, uuid.UUID) (territory.Scope, error) {
		return territory.Scope{}, io.ErrUnexpectedEOF
	})
	_, err := e.svc.Snapshot(e.ctx(), "")
	require.Error(t, err)
	assert.Equal(t, 0, e.identity.count())
}

func TestSubscriberRegistered(t *testing.T) {
	bus := events.NewBus()
	(&Module{svc: NewService(platform.Deps{}, nil, nil)}).RegisterSubscribers(bus)
	assert.Equal(t, []string{"sync.drop_snapshot_cache"}, bus.Subscribers(events.NameDeviceRevoked))
}
