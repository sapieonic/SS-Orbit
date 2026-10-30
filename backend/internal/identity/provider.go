package identity

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Provider methods other modules call through their ports (CONVENTIONS
// section 5). IsDeviceRevoked lives in service_devices.go; CheckPrincipal
// (surface guard) in service_guard.go.

// GetFieldAssistants returns the FAs with the given IDs (unknown IDs are
// skipped), ordered by login ID.
func (s *Service) GetFieldAssistants(ctx context.Context, ids []uuid.UUID) ([]xmod.FieldAssistant, error) {
	ids = dedupeUUIDs(ids)
	if len(ids) == 0 {
		return []xmod.FieldAssistant{}, nil
	}
	rows, err := s.q.GetFieldAssistantsByIDs(ctx, ids)
	if err != nil {
		return nil, apperr.Internalf("identity: get field assistants: %w", err)
	}
	out := make([]xmod.FieldAssistant, len(rows))
	for i, r := range rows {
		out[i] = toXmodFA(r)
	}
	return out, nil
}

// PushTokens returns the push tokens of the subjects' live (not revoked)
// devices, most recently seen first. Subjects without a token are absent.
func (s *Service) PushTokens(ctx context.Context, subjectKind string, subjectIDs []uuid.UUID) (map[uuid.UUID][]string, error) {
	if subjectKind != SubjectFA && subjectKind != SubjectFarmer {
		return nil, fmt.Errorf("identity: push tokens: unknown subject kind %q", subjectKind)
	}
	out := map[uuid.UUID][]string{}
	subjectIDs = dedupeUUIDs(subjectIDs)
	if len(subjectIDs) == 0 {
		return out, nil
	}
	rows, err := s.q.ListPushTokens(ctx, store.ListPushTokensParams{SubjectKind: subjectKind, SubjectIds: subjectIDs})
	if err != nil {
		return nil, apperr.Internalf("identity: push tokens: %w", err)
	}
	for _, r := range rows {
		out[r.SubjectID] = append(out[r.SubjectID], r.PushToken)
	}
	return out, nil
}

// MarkSynced records a successful FA sync on the FA and, when known, the
// device. Bookkeeping only, so it is not audited.
func (s *Service) MarkSynced(ctx context.Context, faID, deviceID uuid.UUID, at time.Time) error {
	at = at.UTC()
	return s.withTx(ctx, func(_ pgx.Tx, q *store.Queries) error {
		n, err := q.MarkFieldAssistantSynced(ctx, store.MarkFieldAssistantSyncedParams{SyncedAt: &at, ID: faID})
		if err != nil {
			return apperr.Internalf("identity: mark fa synced: %w", err)
		}
		if n == 0 {
			return apperr.NotFound("field assistant")
		}
		if deviceID == uuid.Nil {
			return nil
		}
		if err := q.MarkDeviceSynced(ctx, store.MarkDeviceSyncedParams{SyncedAt: &at, ID: deviceID, FaID: faID}); err != nil {
			return apperr.Internalf("identity: mark device synced: %w", err)
		}
		return nil
	})
}

// FAsNotSyncedSince returns the active FAs whose last sync is before since,
// or who never synced and were created before it, ordered by login ID
// (messaging's fa_offline HO alert).
func (s *Service) FAsNotSyncedSince(ctx context.Context, since time.Time) ([]xmod.FieldAssistant, error) {
	since = since.UTC()
	rows, err := s.q.FieldAssistantsNotSyncedSince(ctx, &since)
	if err != nil {
		return nil, apperr.Internalf("identity: fas not synced: %w", err)
	}
	out := make([]xmod.FieldAssistant, len(rows))
	for i, r := range rows {
		out[i] = toXmodFA(r)
	}
	return out, nil
}

func toXmodFA(r store.FieldAssistant) xmod.FieldAssistant {
	return xmod.FieldAssistant{
		ID: r.ID, Code: r.Code, Name: r.Name, NameTe: r.NameTe, Phone: r.Phone, Level: r.Level,
		Languages: r.Languages, WorkingHours: r.WorkingHours, PhotoKey: r.PhotoKey, Status: r.Status,
		LastSyncAt: utcPtr(r.LastSyncAt),
	}
}
