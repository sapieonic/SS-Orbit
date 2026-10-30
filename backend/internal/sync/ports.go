package sync

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// Masters is the masters module (CONVENTIONS section 5).
type Masters interface {
	// CurrentVersion is master_versions kind "all"; part of the snapshot key.
	CurrentVersion(ctx context.Context) (int64, error)
}

// Identity is the identity module (CONVENTIONS section 5).
type Identity interface {
	// MarkSynced sets last_sync_at on the FA and the device.
	MarkSynced(ctx context.Context, faID, deviceID uuid.UUID, at time.Time) error
}

// Ports are the interfaces this module needs from other modules, filled by
// the integrator in internal/app/wire.go.
type Ports struct {
	Masters  Masters
	Identity Identity
}
