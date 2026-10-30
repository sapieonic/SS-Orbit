package sync

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"strings"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

// Snapshot returns the calling FA's offline snapshot as gzipped JSON, or
// NotModified when ifNoneMatch (the If-None-Match header, "" if absent)
// matches the current ETag.
//
// Versions are read BEFORE the sections are built. A write that lands during
// the build then makes the data newer than its key, never older: the phone may
// pull once more than needed, but a cached snapshot never hides a change
// behind a version it already reports.
//
// The gzipped bytes are cached in Redis under
// scope:{fa}:v{territory}:m{masters} (CONVENTIONS section 8). With Redis down
// every request rebuilds.
func (s *Service) Snapshot(ctx context.Context, ifNoneMatch string) (BuiltSnapshot, error) {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return BuiltSnapshot{}, err
	}
	v, err := s.versions(ctx, p.ID)
	if err != nil {
		return BuiltSnapshot{}, err
	}
	if etagMatches(ifNoneMatch, v.ETag()) {
		s.markSynced(ctx, p.ID, p.DeviceID)
		return BuiltSnapshot{Versions: v, NotModified: true}, nil
	}

	key := snapshotKey(p.ID, v)
	body, ok := s.deps.Cache.Get(ctx, key)
	if !ok {
		if body, err = s.build(ctx, p.ID, v); err != nil {
			return BuiltSnapshot{}, err
		}
		s.deps.Cache.Set(ctx, key, body, s.snapshotTTL)
		s.rememberKey(ctx, p.ID, key)
	}
	s.markSynced(ctx, p.ID, p.DeviceID)
	return BuiltSnapshot{Versions: v, Gzip: body}, nil
}

// Status returns the calling FA's current versions (the cheap poll).
func (s *Service) Status(ctx context.Context) (Versions, error) {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return Versions{}, err
	}
	return s.versions(ctx, p.ID)
}

// build asks every registered section provider for the FA's data and returns
// the gzipped JSON envelope.
func (s *Service) build(ctx context.Context, faID uuid.UUID, v Versions) ([]byte, error) {
	sections, err := s.deps.Territory.Build(ctx, faID)
	if err != nil {
		return nil, apperr.Internalf("sync: build snapshot: %w", err)
	}
	if sections == nil {
		sections = map[string]any{}
	}
	env := envelope{
		TerritoryVersion: v.Territory,
		MastersVersion:   v.Masters,
		GeneratedAt:      s.deps.Clock.Now(),
		Sections:         sections,
	}
	var buf bytes.Buffer
	zw := gzip.NewWriter(&buf)
	if err := json.NewEncoder(zw).Encode(env); err != nil {
		return nil, apperr.Internalf("sync: encode snapshot: %w", err)
	}
	if err := zw.Close(); err != nil {
		return nil, apperr.Internalf("sync: gzip snapshot: %w", err)
	}
	return buf.Bytes(), nil
}

// Dropping cached snapshots.
//
// The device.revoked event carries no versions, and the FA may have several
// cached snapshots (older versions until their TTL). Each FA therefore has a
// small index key, scope:{fa}:keys, listing the snapshot keys written for it;
// revocation deletes those keys and the index. We use a JSON list through the
// cache helpers rather than a Redis set because modules only get the typed
// cache API. Two concurrent builds can race on the index and lose an entry;
// as a backstop the key for the current versions is deleted too (older
// versions are never served again, they only wait for their TTL).
const maxIndexedKeys = 8

func snapshotKey(faID uuid.UUID, v Versions) string {
	return fmt.Sprintf("scope:%s:v%d:m%d", faID, v.Territory, v.Masters)
}

func indexKey(faID uuid.UUID) string { return "scope:" + faID.String() + ":keys" }

// rememberKey adds key to the FA's index. The index lives as long as the
// newest snapshot, so it always outlives the keys it lists.
func (s *Service) rememberKey(ctx context.Context, faID uuid.UUID, key string) {
	var keys []string
	s.deps.Cache.GetJSON(ctx, indexKey(faID), &keys)
	if !slices.Contains(keys, key) {
		keys = append(keys, key)
	}
	if len(keys) > maxIndexedKeys {
		keys = keys[len(keys)-maxIndexedKeys:]
	}
	s.deps.Cache.SetJSON(ctx, indexKey(faID), keys, s.snapshotTTL)
}

// DropCachedSnapshots deletes every cached snapshot of an FA. Best effort:
// with Redis down there is nothing to delete now and entries expire by TTL.
func (s *Service) DropCachedSnapshots(ctx context.Context, faID uuid.UUID) {
	var keys []string
	s.deps.Cache.GetJSON(ctx, indexKey(faID), &keys)
	if v, err := s.versions(ctx, faID); err == nil {
		keys = append(keys, snapshotKey(faID, v))
	} else {
		logx.From(ctx).WarnContext(ctx, "sync: versions unavailable while dropping snapshots", "fa_id", faID, "err", err)
	}
	keys = append(keys, indexKey(faID))
	s.deps.Cache.Delete(ctx, keys...)
}

// etagMatches implements If-None-Match: a comma-separated list of entity
// tags (weak ones compared by their opaque part) or "*".
func etagMatches(header, etag string) bool {
	for part := range strings.SplitSeq(header, ",") {
		t := strings.TrimSpace(part)
		if t == "*" {
			return true
		}
		if strings.TrimPrefix(t, "W/") == etag {
			return true
		}
	}
	return false
}
