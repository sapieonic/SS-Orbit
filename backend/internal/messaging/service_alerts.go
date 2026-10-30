package messaging

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// FA alert kinds and HO alert kinds.
const (
	faAlertNewFarmer = "new_farmer"
	faAlertCallback  = "callback"
	faAlertHONote    = "ho_note"

	hoAlertNewFarmer       = "new_farmer"
	hoAlertFarmerWithoutFA = "farmer_without_fa"
)

const (
	alertListDefault = 50
	alertListMax     = 200
)

// ListFAAlerts is the FA app's Alerts tab, newest first, with the farmer's
// name and phone for the Call button.
func (s *Service) ListFAAlerts(ctx context.Context, status *string, limit *int, cursor *string) (paging.Page[FieldAlert], error) {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return paging.Page[FieldAlert]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[FieldAlert]{}, err
	}
	n := paging.Limit(limit, alertListDefault, alertListMax)
	rows, err := s.q.ListFAAlerts(ctx, store.ListFAAlertsParams{
		FaID: p.ID, Status: status, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[FieldAlert]{}, apperr.Internalf("messaging: list fa alerts: %w", err)
	}
	page := paging.Map(paging.Build(rows, n, func(r store.FaAlert) paging.Cursor {
		return paging.Cursor{At: r.CreatedAt, ID: r.ID}
	}), toFAAlert)

	var farmerIDs []uuid.UUID
	for _, a := range page.Items {
		if a.FarmerID != nil {
			farmerIDs = append(farmerIDs, *a.FarmerID)
		}
	}
	farmers, err := s.farmerSummaries(ctx, dedupe(farmerIDs))
	if err != nil { // names are a convenience; the alert list still works
		logx.From(ctx).WarnContext(ctx, "messaging: farmer names for alerts", "err", err)
		return page, nil
	}
	for i, a := range page.Items {
		if a.FarmerID == nil {
			continue
		}
		if f, ok := farmers[*a.FarmerID]; ok {
			if name := displayName(f, "en"); name != "" {
				page.Items[i].FarmerName = &name
			}
			page.Items[i].FarmerPhone = &f.Phone
		}
	}
	return page, nil
}

// snapshotAlerts is the offline snapshot's "alerts" section: the FA's alerts
// that are not closed, from the last snapshotAlertDays days.
func (s *Service) snapshotAlerts(ctx context.Context, sc territory.Scope) (any, error) {
	rows, err := s.q.ListSnapshotFAAlerts(ctx, store.ListSnapshotFAAlertsParams{
		FaID: sc.FAID, Since: s.now().AddDate(0, 0, -snapshotAlertDays), RowLimit: snapshotAlertLimit,
	})
	if err != nil {
		return nil, err
	}
	out := make([]FieldAlert, len(rows))
	for i, r := range rows {
		out[i] = toFAAlert(r)
	}
	return out, nil
}

// ackAlertPayload is the AckAlert sync command.
type ackAlertPayload struct {
	AlertID uuid.UUID `json:"alert_id"`
}

// ackAlert handles the AckAlert sync command. Acknowledging twice, or an
// alert that is already closed, is applied (idempotent).
func (s *Service) ackAlert(ctx context.Context, p auth.Principal, _ commands.Command, in ackAlertPayload) (commands.Result, error) {
	if p.Kind != auth.KindFA {
		return commands.Result{}, apperr.Forbidden("only field assistants acknowledge alerts")
	}
	if in.AlertID == uuid.Nil {
		return commands.Rejected(uuid.Nil, "alert_id is required"), nil
	}
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		now := s.now()
		row, err := q.AckFAAlert(ctx, store.AckFAAlertParams{ID: in.AlertID, FaID: p.ID, At: &now})
		if db.IsNoRows(err) {
			existing, err := q.GetFAAlert(ctx, in.AlertID)
			if err != nil {
				return notFoundOr(err, "alert")
			}
			if existing.FaID != p.ID {
				return apperr.NotFound("alert")
			}
			return nil // already acknowledged or closed
		}
		if err != nil {
			return apperr.Internalf("messaging: ack alert: %w", err)
		}
		if err := territory.Bump(ctx, tx, p.ID); err != nil {
			return err
		}
		_, err = audit.Record(ctx, tx, audit.Entry{
			Action: "messaging.fa_alert_acknowledged", EntityType: "fa_alert", EntityID: row.ID,
			FarmerID: uuidOrNil(row.FarmerID), Before: map[string]any{"status": "open"},
			After: map[string]any{"status": row.Status},
		})
		return err
	})
	if err != nil {
		return commands.Result{EntityID: in.AlertID}, err
	}
	return commands.Applied(in.AlertID), nil
}

// CreateHONote sends a note from HO to an FA's Alerts tab.
func (s *Service) CreateHONote(ctx context.Context, in HONote) (FieldAlert, error) {
	p, err := auth.RequireRole(ctx, advisoryRoles...)
	if err != nil {
		return FieldAlert{}, err
	}
	in.Title = strings.TrimSpace(in.Title)
	in.Body = trimOptional(in.Body)
	in.TitleTe, in.BodyTe = trimOptional(in.TitleTe), trimOptional(in.BodyTe)
	if in.Title == "" {
		return FieldAlert{}, apperr.Validation("title", "is required")
	}
	// Existence check. The geo port offers no FA -> district lookup, so the HO
	// area scope is not applied to notes.
	if _, err := s.fieldAssistant(ctx, in.FAID); err != nil {
		return FieldAlert{}, err
	}
	var out FieldAlert
	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		a, _, err := s.insertFAAlert(ctx, tx, q, store.InsertFAAlertParams{
			ID: ids.New(), FaID: in.FAID, Kind: faAlertHONote, FarmerID: nullUUID(in.FarmerID),
			Title: in.Title, Body: in.Body, TitleTe: in.TitleTe, BodyTe: in.BodyTe, CreatedBy: someUUID(p.ID),
		})
		out = a
		if db.IsForeignKeyViolation(err) {
			return apperr.NotFound("farmer")
		}
		return err
	})
	return out, err
}

// insertFAAlert creates an alert unless the FA already has one of the same
// kind for the same record. It bumps the FA's territory version (alerts are
// in the offline snapshot), queues the push to the FA's devices and audits.
// created is false for a duplicate.
func (s *Service) insertFAAlert(ctx context.Context, tx pgx.Tx, q *store.Queries, arg store.InsertFAAlertParams) (FieldAlert, bool, error) {
	row, err := q.InsertFAAlert(ctx, arg)
	if db.IsNoRows(err) {
		return FieldAlert{}, false, nil
	}
	if err != nil {
		if db.IsForeignKeyViolation(err) {
			return FieldAlert{}, false, err
		}
		return FieldAlert{}, false, apperr.Internalf("messaging: insert fa alert: %w", err)
	}
	if err := territory.Bump(ctx, tx, arg.FaID); err != nil {
		return FieldAlert{}, false, err
	}
	// FA-10: the FA hears about it within minutes, not at the next sync.
	if err := s.deps.Jobs.Insert(ctx, tx, faAlertPushArgs{AlertID: row.ID},
		&river.InsertOpts{MaxAttempts: faAlertPushMaxAttempts}); err != nil {
		return FieldAlert{}, false, apperr.Internalf("messaging: queue fa alert push: %w", err)
	}
	a := toFAAlert(row)
	_, err = audit.Record(ctx, tx, audit.Entry{
		Action: "messaging.fa_alert_created", EntityType: "fa_alert", EntityID: a.ID,
		FarmerID: uuidOrNil(row.FarmerID), After: a,
	})
	return a, true, err
}

// ListHOAlerts is the HO overview's alert list, newest first.
func (s *Service) ListHOAlerts(ctx context.Context, kind *string, limit *int, cursor *string) (paging.Page[OverviewAlert], error) {
	p, err := auth.RequireRole(ctx, auth.RoleAdmin, auth.RoleAgronomy, auth.RoleFinance, auth.RoleOps)
	if err != nil {
		return paging.Page[OverviewAlert]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[OverviewAlert]{}, err
	}
	n := paging.Limit(limit, alertListDefault, alertListMax)
	arg := store.ListHOAlertsParams{Kind: kind, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1)}
	if p.HasAreaScope() {
		arg.ScopeDistrictIds = p.DistrictIDs
	}
	rows, err := s.q.ListHOAlerts(ctx, arg)
	if err != nil {
		return paging.Page[OverviewAlert]{}, apperr.Internalf("messaging: list ho alerts: %w", err)
	}
	page := paging.Build(rows, n, func(r store.HoAlert) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} })
	return paging.Map(page, toHOAlert), nil
}

// upsertHOAlert records (or completes) the HO alert of kind for a farmer.
// Empty payload values are dropped so a later, better-informed event fills
// them without an earlier one blanking them.
func (s *Service) upsertHOAlert(ctx context.Context, tx pgx.Tx, q *store.Queries, kind string, farmerID uuid.UUID,
	faID, districtID uuid.NullUUID, payload map[string]any) error {
	for k, v := range payload {
		if v == nil || v == "" {
			delete(payload, k)
		}
	}
	raw, err := json.Marshal(payload)
	if err != nil {
		return apperr.Internalf("messaging: ho alert payload: %w", err)
	}
	row, err := q.UpsertHOAlert(ctx, store.UpsertHOAlertParams{
		ID: ids.New(), Kind: kind, FarmerID: someUUID(farmerID), FaID: faID, DistrictID: districtID, Payload: raw,
	})
	if err != nil {
		return apperr.Internalf("messaging: upsert ho alert: %w", err)
	}
	_, err = audit.Record(ctx, tx, audit.Entry{
		Action: "messaging.ho_alert_recorded", EntityType: "ho_alert", EntityID: row.ID, FarmerID: farmerID,
		After: map[string]any{"kind": kind, "district_id": uuidPtr(row.DistrictID), "fa_id": uuidPtr(row.FaID)},
	})
	return err
}

func uuidOrNil(n uuid.NullUUID) uuid.UUID {
	if !n.Valid {
		return uuid.Nil
	}
	return n.UUID
}
