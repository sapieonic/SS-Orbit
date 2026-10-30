package sync

import (
	"context"

	"github.com/sapionic/orbit/backend/internal/platform/events"
)

// onDeviceRevoked drops the FA's cached snapshots so their data does not sit
// in Redis after HO revoked a phone. The revoked device itself can no longer
// fetch (the surface guard refuses it); this is about not keeping copies.
// Idempotent: deleting absent keys is a no-op.
func (s *Service) onDeviceRevoked(ctx context.Context, e events.DeviceRevoked) error {
	if e.SubjectKind != "fa" {
		return nil
	}
	s.DropCachedSnapshots(ctx, e.SubjectID)
	return nil
}
