package visits

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/visits/store"
)

// Sync command types this module handles (CONVENTIONS section 6).
const (
	CmdPlanVisit     = "PlanVisit"
	CmdLogVisit      = "LogVisit"
	CmdCancelVisit   = "CancelVisit"
	CmdCloseCallback = "CloseCallback"
)

type planVisitPayload struct {
	VisitID     uuid.UUID `json:"visit_id"`
	FarmerID    uuid.UUID `json:"farmer_id"`
	PlotID      uuid.UUID `json:"plot_id"`
	SeasonID    uuid.UUID `json:"season_id"`
	PlannedFor  string    `json:"planned_for"`
	PlannedSlot string    `json:"planned_slot"`
	Purpose     *string   `json:"purpose"`
}

type cancelVisitPayload struct {
	VisitID uuid.UUID `json:"visit_id"`
	Reason  *string   `json:"reason"`
}

type closeCallbackPayload struct {
	CallbackID uuid.UUID `json:"callback_id"`
	Note       *string   `json:"note"`
}

// rejection is a business refusal inside a command transaction. It rolls the
// transaction back and becomes a `rejected` result with this reason.
type rejection struct{ reason string }

func (r *rejection) Error() string { return "rejected: " + r.reason }

func reject(format string, args ...any) error {
	return &rejection{reason: fmt.Sprintf(format, args...)}
}

// commandResult turns the outcome of a command into a Result: nil is applied;
// rejections, constraint violations and apperr business errors are rejected
// with a readable reason; anything else is an infrastructure error the sync
// module retries.
func commandResult(id uuid.UUID, err error) (commands.Result, error) {
	if err == nil {
		return commands.Applied(id), nil
	}
	var r *rejection
	if errors.As(err, &r) {
		return commands.Rejected(id, r.reason), nil
	}
	if reason, ok := constraintReason(err); ok {
		return commands.Rejected(id, reason), nil
	}
	if e, ok := apperr.As(err); ok {
		switch e.Kind {
		case apperr.KindValidation, apperr.KindNotFound, apperr.KindForbidden, apperr.KindConflict:
			return commands.Rejected(id, e.Message), nil
		}
	}
	return commands.Result{EntityID: id}, err
}

// constraintReason explains a unique, foreign-key or check violation. The
// composite (season_id, plot_id, farmer_id) keys are what keep a visit's
// farmer, plot and season consistent, so that case gets a specific message.
// IDs minted on the phone (issue_visit_id, photo_id) that already exist belong
// to another visit (a logged visit is never written twice).
func constraintReason(err error) (string, bool) {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		return "", false
	}
	switch pgErr.Code {
	case db.CodeUniqueViolation:
		return uniqueReason(pgErr.ConstraintName), true
	case db.CodeCheckViolation:
		return "invalid value (" + pgErr.ConstraintName + ")", true
	case db.CodeForeignKeyViolation:
	default:
		return "", false
	}
	c := pgErr.ConstraintName
	switch {
	case strings.Contains(c, "season_id_plot_id_farmer_id"):
		return "season does not exist or does not belong to this farmer and plot", true
	case strings.Contains(c, "stage_id"):
		return "unknown crop stage", true
	case strings.Contains(c, "fa_id"):
		return "field assistant not found", true
	case strings.Contains(c, "issue_id"):
		return "unknown issue", true
	case strings.Contains(c, "salt_id"), strings.Contains(c, "sku_id"), strings.Contains(c, "advisory_rule_id"):
		return "advice refers to a master record that does not exist", true
	case strings.Contains(c, "farmer_id"):
		return "farmer not found", true
	}
	return "a referenced record does not exist (" + c + ")", true
}

func uniqueReason(constraint string) string {
	switch constraint {
	case "visit_issues_pkey":
		return "issue_visit_id is already used by another visit; send a new ID"
	case "visit_photos_pkey", "visit_photos_storage_key_key":
		return "photo_id is already used by another visit; send a new ID"
	case "visits_pkey":
		return "visit_id is already used"
	case "callback_requests_one_open":
		return "the farmer already has an open call-back request"
	}
	return "a record with this ID already exists (" + constraint + ")"
}

func requireFA(p auth.Principal) error {
	if p.Kind != auth.KindFA || p.ID == uuid.Nil {
		return reject("only a field assistant can send this command")
	}
	return nil
}

func validSlot(s string) bool { return s == "morning" || s == "afternoon" || s == "any" }

// sameTarget reports whether an existing visit is for the same farmer, plot
// and season as the command.
func sameTarget(v store.LockVisitRow, farmerID, plotID, seasonID uuid.UUID) bool {
	return v.FarmerID == farmerID && v.PlotID == plotID && v.SeasonID == seasonID
}

// planVisit handles PlanVisit: a new planned visit, or a re-plan (new day or
// slot) of a planned or missed one. Replaying the same plan changes nothing.
func (s *Service) planVisit(ctx context.Context, p auth.Principal, cmd commands.Command, in planVisitPayload) (commands.Result, error) {
	id := in.VisitID
	if err := requireFA(p); err != nil {
		return commandResult(id, err)
	}
	if id == uuid.Nil || in.FarmerID == uuid.Nil || in.PlotID == uuid.Nil || in.SeasonID == uuid.Nil {
		return commandResult(id, reject("visit_id, farmer_id, plot_id and season_id are required"))
	}
	day, err := parseDay(in.PlannedFor)
	if err != nil {
		return commandResult(id, reject("planned_for must be a date (YYYY-MM-DD)"))
	}
	if !validSlot(in.PlannedSlot) {
		return commandResult(id, reject("planned_slot must be morning, afternoon or any"))
	}
	if in.FarmerID, err = s.resolveFarmer(ctx, p.ID, in.FarmerID); err != nil {
		return commandResult(id, err)
	}
	district, err := s.farmerDistrict(ctx, in.FarmerID)
	if err != nil {
		return commandResult(id, err)
	}

	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := store.New(tx)
		action := "visits.planned"
		var before any
		cur, err := q.LockVisit(ctx, id)
		switch {
		case db.IsNoRows(err):
		case err != nil:
			return err
		default:
			if cur.FaID != p.ID {
				return reject("visit belongs to another field assistant")
			}
			if !sameTarget(cur, in.FarmerID, in.PlotID, in.SeasonID) {
				return reject("visit_id is already used for a different farmer, plot or season")
			}
			switch cur.Status {
			case StatusDone:
				return reject("visit is already logged")
			case StatusCancelled:
				return reject("visit was cancelled; plan a new one")
			}
			if cur.Status == StatusPlanned && cur.PlannedFor != nil && cur.PlannedFor.Equal(day) &&
				deref(cur.PlannedSlot) == in.PlannedSlot && deref(cur.Purpose) == deref(in.Purpose) {
				return nil // same plan again
			}
			action = "visits.replanned"
			before = planSnapshot(cur.Status, cur.PlannedFor, cur.PlannedSlot, cur.Purpose)
		}
		if err := q.UpsertPlannedVisit(ctx, store.UpsertPlannedVisitParams{
			ID: id, FarmerID: in.FarmerID, PlotID: in.PlotID, SeasonID: in.SeasonID, FaID: p.ID,
			PlannedFor: &day, PlannedSlot: &in.PlannedSlot, Purpose: in.Purpose, ClientCreatedAt: utcPtr(cmd.ClientCreatedAt),
			DistrictID: district,
		}); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: action, EntityType: "visit", EntityID: id,
			FarmerID: in.FarmerID, PlotID: in.PlotID, SeasonID: in.SeasonID,
			Before: before, After: planSnapshot(StatusPlanned, &day, &in.PlannedSlot, in.Purpose),
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, p.ID)
	})
	return commandResult(id, err)
}

func planSnapshot(status string, day *time.Time, slot, purpose *string) map[string]any {
	m := map[string]any{"status": status, "planned_slot": slot, "purpose": purpose}
	if day != nil {
		m["planned_for"] = day.Format(time.DateOnly)
	}
	return m
}

// cancelVisit handles CancelVisit for a planned or missed visit of this FA.
func (s *Service) cancelVisit(ctx context.Context, p auth.Principal, _ commands.Command, in cancelVisitPayload) (commands.Result, error) {
	id := in.VisitID
	if err := requireFA(p); err != nil {
		return commandResult(id, err)
	}
	err := db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := store.New(tx)
		cur, err := q.LockVisit(ctx, id)
		if db.IsNoRows(err) {
			return reject("visit not found")
		}
		if err != nil {
			return err
		}
		if cur.FaID != p.ID {
			return reject("visit belongs to another field assistant")
		}
		switch cur.Status {
		case StatusCancelled:
			return nil
		case StatusDone:
			return reject("visit is already logged and cannot be cancelled")
		}
		if err := q.SetVisitStatus(ctx, store.SetVisitStatusParams{ID: id, Status: StatusCancelled}); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "visits.cancelled", EntityType: "visit", EntityID: id,
			FarmerID: cur.FarmerID, PlotID: cur.PlotID, SeasonID: cur.SeasonID,
			Before: map[string]any{"status": cur.Status}, After: map[string]any{"status": StatusCancelled},
			Meta: map[string]any{"reason": in.Reason},
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, p.ID)
	})
	return commandResult(id, err)
}

// closeCallback handles CloseCallback: the FA called the farmer back.
func (s *Service) closeCallback(ctx context.Context, p auth.Principal, _ commands.Command, in closeCallbackPayload) (commands.Result, error) {
	id := in.CallbackID
	if err := requireFA(p); err != nil {
		return commandResult(id, err)
	}
	err := db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := store.New(tx)
		cur, err := q.LockCallback(ctx, id)
		if db.IsNoRows(err) {
			return reject("call-back request not found")
		}
		if err != nil {
			return err
		}
		if cur.FaID != p.ID {
			return reject("call-back request is assigned to another field assistant")
		}
		if cur.Status != CallbackOpen {
			return nil // already closed or withdrawn by the farmer
		}
		now := s.deps.Clock.Now()
		if _, err := q.FinishCallback(ctx, store.FinishCallbackParams{
			ID: id, Status: CallbackClosed, ClosedAt: &now, ClosedBy: uuid.NullUUID{UUID: p.ID, Valid: true}, Note: in.Note,
		}); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "visits.callback_closed", EntityType: "callback_request", EntityID: id, FarmerID: cur.FarmerID,
			Before: map[string]any{"status": cur.Status}, After: map[string]any{"status": CallbackClosed, "note": in.Note},
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, p.ID)
	})
	return commandResult(id, err)
}
