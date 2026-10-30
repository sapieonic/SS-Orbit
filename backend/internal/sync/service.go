package sync

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/sync/store"
)

// queries is the subset of the generated store the service uses.
type queries interface {
	GetSyncCommand(ctx context.Context, id uuid.UUID) (store.SyncCommand, error)
	GetSyncCommandsByIDs(ctx context.Context, ids []uuid.UUID) ([]store.SyncCommand, error)
	InsertSyncCommand(ctx context.Context, arg store.InsertSyncCommandParams) (store.SyncCommand, error)
	ListSyncCommands(ctx context.Context, arg store.ListSyncCommandsParams) ([]store.ListSyncCommandsRow, error)
	RecordSyncCommandFailure(ctx context.Context, arg store.RecordSyncCommandFailureParams) (int32, error)
	DeleteOldSyncCommands(ctx context.Context, arg store.DeleteOldSyncCommandsParams) (int64, error)
	DeleteOldSyncCommandFailures(ctx context.Context, before time.Time) (int64, error)
}

// Service orchestrates FA sync. It owns only sync_commands; the data itself
// belongs to the modules behind deps.Commands (handlers) and deps.Territory
// (snapshot providers).
type Service struct {
	deps  platform.Deps
	q     queries
	ports *Ports
	// snapshotTTL is how long a gzipped snapshot stays in Redis. The key
	// carries both versions, so a stale entry is never served; the TTL only
	// bounds memory and how long FA data sits in Redis.
	snapshotTTL time.Duration
}

// defaultSnapshotTTL: long enough to serve an FA's repeat pulls during a
// working day without rebuilding, short enough not to keep data around.
const defaultSnapshotTTL = 2 * time.Hour

// NewService builds the service on q (store.New(pool) in production).
func NewService(deps platform.Deps, q queries, ports *Ports) *Service {
	if ports == nil {
		ports = &Ports{}
	}
	return &Service{deps: deps, q: q, ports: ports, snapshotTTL: defaultSnapshotTTL}
}

// versions reads the FA's territory version and the masters version.
func (s *Service) versions(ctx context.Context, faID uuid.UUID) (Versions, error) {
	t, err := territory.Version(ctx, s.deps.Pool, faID)
	if err != nil {
		return Versions{}, apperr.Internalf("sync: territory version: %w", err)
	}
	if s.ports.Masters == nil {
		return Versions{}, apperr.Internalf("sync: %w", errors.New("masters port not wired"))
	}
	m, err := s.ports.Masters.CurrentVersion(ctx)
	if err != nil {
		return Versions{}, apperr.Internalf("sync: masters version: %w", err)
	}
	return Versions{Territory: t, Masters: m}, nil
}

// markSynced records the sync on the FA and device (identity). It is
// bookkeeping for the HO "last sync" column, so a failure is logged and does
// not fail the sync the phone already completed.
func (s *Service) markSynced(ctx context.Context, faID, deviceID uuid.UUID) {
	if s.ports.Identity == nil {
		logx.From(ctx).WarnContext(ctx, "sync: identity port not wired; last sync not recorded")
		return
	}
	if err := s.ports.Identity.MarkSynced(ctx, faID, deviceID, s.deps.Clock.Now()); err != nil {
		logx.From(ctx).WarnContext(ctx, "sync: mark synced failed", "fa_id", faID, "device_id", deviceID, "err", err)
	}
}
