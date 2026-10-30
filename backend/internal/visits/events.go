package visits

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/visits/store"
)

// subscriberReassigned keys the delivery jobs; do not rename.
const subscriberReassigned = "visits.move_open_work"

// onFarmersReassigned moves the farmers' planned visits and open call-back
// requests to the new FA and bumps both FAs. Done and missed visits stay with
// the FA who had them. Idempotent: a redelivery finds nothing left to move.
func (s *Service) onFarmersReassigned(ctx context.Context, e events.FarmersReassigned) error {
	if len(e.FarmerIDs) == 0 || e.ToFAID == uuid.Nil {
		return nil
	}
	return db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := store.New(tx)
		visits, err := q.ReassignPlannedVisits(ctx, store.ReassignPlannedVisitsParams{ToFaID: e.ToFAID, FarmerIds: e.FarmerIDs})
		if err != nil {
			return err
		}
		callbacks, err := q.ReassignOpenCallbacks(ctx, store.ReassignOpenCallbacksParams{ToFaID: e.ToFAID, FarmerIds: e.FarmerIDs})
		if err != nil {
			return err
		}
		if len(visits) == 0 && len(callbacks) == 0 {
			return nil
		}
		bump := []uuid.UUID{e.ToFAID}
		if e.FromFAID != nil {
			bump = append(bump, *e.FromFAID)
		}
		for _, v := range visits {
			bump = append(bump, v.FromFaID)
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "visits.reassigned", EntityType: "visit", EntityID: v.ID, FarmerID: v.FarmerID,
				Before: map[string]any{"fa_id": v.FromFaID}, After: map[string]any{"fa_id": e.ToFAID},
			}); err != nil {
				return err
			}
		}
		for _, c := range callbacks {
			bump = append(bump, c.FromFaID)
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "visits.callback_reassigned", EntityType: "callback_request", EntityID: c.ID, FarmerID: c.FarmerID,
				Before: map[string]any{"fa_id": c.FromFaID}, After: map[string]any{"fa_id": e.ToFAID},
			}); err != nil {
				return err
			}
		}
		return territory.Bump(ctx, tx, bump...)
	})
}
