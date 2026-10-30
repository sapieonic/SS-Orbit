package messaging

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
)

const (
	hoAlertFAOffline = "fa_offline"
	// faOfflineAfter is how long without a sync makes an FA "offline".
	faOfflineAfter = 48 * time.Hour
)

// RaiseFAOfflineAlerts records one fa_offline HO alert per active FA that has
// not synced for faOfflineAfter, at most once per FA per IST day (the unique
// key makes the hourly run idempotent). The alert's district is the FA's
// first allocated district (sorted, so stable); all of them are in the
// payload. It returns how many alerts were created.
func (s *Service) RaiseFAOfflineAlerts(ctx context.Context) (int, error) {
	now := s.now()
	fas, err := s.ports.Identity.FAsNotSyncedSince(ctx, now.Add(-faOfflineAfter))
	if err != nil {
		return 0, fmt.Errorf("messaging: fas not synced: %w", err)
	}
	if len(fas) == 0 {
		return 0, nil
	}
	faIDs := make([]uuid.UUID, len(fas))
	for i, fa := range fas {
		faIDs[i] = fa.ID
	}
	districts, err := s.ports.Geo.DistrictIDsForFAs(ctx, faIDs)
	if err != nil {
		return 0, fmt.Errorf("messaging: fa districts: %w", err)
	}
	l := now.In(ist)
	day := time.Date(l.Year(), l.Month(), l.Day(), 0, 0, 0, 0, time.UTC)

	created := 0
	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		for _, fa := range fas {
			ds := slices.Clone(districts[fa.ID])
			slices.SortFunc(ds, func(a, b uuid.UUID) int { return slices.Compare(a[:], b[:]) })
			var district uuid.NullUUID
			if len(ds) > 0 {
				district = someUUID(ds[0])
			}
			payload, err := json.Marshal(map[string]any{
				"fa_code": fa.Code, "fa_name": fa.Name, "last_sync_at": utcPtr(fa.LastSyncAt), "district_ids": nonNil(ds),
			})
			if err != nil {
				return err
			}
			row, err := q.InsertFAOfflineAlert(ctx, store.InsertFAOfflineAlertParams{
				ID: ids.New(), FaID: someUUID(fa.ID), DistrictID: district, Payload: payload, AlertDay: &day,
			})
			if db.IsNoRows(err) {
				continue // already raised today
			}
			if err != nil {
				return fmt.Errorf("messaging: insert fa_offline alert: %w", err)
			}
			created++
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "messaging.ho_alert_recorded", EntityType: "ho_alert", EntityID: row.ID,
				After: map[string]any{"kind": hoAlertFAOffline, "fa_id": fa.ID, "district_id": uuidPtr(district)},
			}); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return 0, err
	}
	return created, nil
}

func nonNil[T any](s []T) []T {
	if s == nil {
		return []T{}
	}
	return s
}
