// Package audit writes rows to the append-only audit_log table inside the
// caller's transaction, so a state change and its audit row commit together.
//
// The actor (kind, ID, on-behalf-of, device), request ID and client IP are
// taken from the context (auth.Principal + reqctx.Meta). Without a principal
// the actor is "system" (jobs, event subscribers).
//
// Reading the log is the audit module's job (internal/audit).
package audit

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/reqctx"
)

// Entry is one audit event. Action is "<module>.<verb>" in past tense
// (farmers.enrolled). uuid.Nil IDs are stored as NULL. Before/After/Meta are
// marshalled to JSON (nil = NULL); pass domain structs or maps, never secrets
// (password hashes, OTPs, tokens).
type Entry struct {
	Action     string
	EntityType string // "farmer", "plot", "advisory_rule", ...
	EntityID   uuid.UUID
	FarmerID   uuid.UUID
	PlotID     uuid.UUID
	SeasonID   uuid.UUID
	Before     any
	After      any
	Meta       any
}

// Record inserts e into audit_log using tx (normally the pgx.Tx from
// db.WithTx). It returns the new row's ID.
func Record(ctx context.Context, tx db.DBTX, e Entry) (uuid.UUID, error) {
	if e.Action == "" || e.EntityType == "" {
		return uuid.Nil, fmt.Errorf("audit: action and entity type are required")
	}
	before, err := marshal(e.Before)
	if err != nil {
		return uuid.Nil, fmt.Errorf("audit: before: %w", err)
	}
	after, err := marshal(e.After)
	if err != nil {
		return uuid.Nil, fmt.Errorf("audit: after: %w", err)
	}
	meta, err := marshal(e.Meta)
	if err != nil {
		return uuid.Nil, fmt.Errorf("audit: meta: %w", err)
	}

	actorKind := string(auth.KindSystem)
	var actorID, onBehalfOf uuid.NullUUID
	var deviceID *string
	if p, ok := auth.FromContext(ctx); ok && p.ID != uuid.Nil {
		actorKind = string(p.Kind)
		if p.Kind == auth.KindWeb { // signed farmer link: the farmer acted
			actorKind = string(auth.KindFarmer)
		}
		actorID = null(p.ID)
		onBehalfOf = null(p.OnBehalfOf)
		if p.DeviceID != uuid.Nil {
			s := p.DeviceID.String()
			deviceID = &s
		}
	}
	m := reqctx.From(ctx)

	id := ids.New()
	_, err = tx.Exec(ctx, `
		INSERT INTO audit_log (id, actor_kind, actor_id, on_behalf_of, action, entity_type, entity_id,
		                       farmer_id, plot_id, season_id, before, after, meta, ip, device_id, request_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14::inet, $15, $16)`,
		id, actorKind, actorID, onBehalfOf, e.Action, e.EntityType, null(e.EntityID),
		null(e.FarmerID), null(e.PlotID), null(e.SeasonID), before, after, meta,
		strOrNil(m.IP), deviceID, strOrNil(m.RequestID))
	if err != nil {
		return uuid.Nil, fmt.Errorf("audit: insert %s: %w", e.Action, err)
	}
	return id, nil
}

func null(id uuid.UUID) uuid.NullUUID { return uuid.NullUUID{UUID: id, Valid: id != uuid.Nil} }

func strOrNil(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func marshal(v any) ([]byte, error) {
	if v == nil {
		return nil, nil
	}
	if raw, ok := v.(json.RawMessage); ok {
		return raw, nil
	}
	return json.Marshal(v)
}
