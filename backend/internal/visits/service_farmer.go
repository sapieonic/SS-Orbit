package visits

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/visits/store"
)

const (
	farmerDefaultLimit = 20
	farmerMaxLimit     = 50
)

// MyVisits is the farmer's logged visits, newest first, with the advice.
func (s *Service) MyVisits(ctx context.Context, limit *int, cursor *string) (paging.Page[FarmerVisitRecord], error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return paging.Page[FarmerVisitRecord]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[FarmerVisitRecord]{}, err
	}
	n := paging.Limit(limit, farmerDefaultLimit, farmerMaxLimit)
	q := s.read()
	rows, err := q.ListFarmerDoneVisits(ctx, store.ListFarmerDoneVisitsParams{
		FarmerID: p.ID, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[FarmerVisitRecord]{}, apperr.Internalf("visits: farmer visits: %w", err)
	}
	page := paging.Build(rows, n, func(r store.VisitDetail) paging.Cursor {
		return paging.Cursor{At: *r.VisitedAt, ID: r.ID}
	})
	visits, err := s.withIssues(ctx, q, page.Items)
	if err != nil {
		return paging.Page[FarmerVisitRecord]{}, err
	}
	faIDs := make([]uuid.UUID, len(visits))
	for i, v := range visits {
		faIDs[i] = v.FAID
	}
	names := s.faNames(ctx, faIDs)
	out := paging.Page[FarmerVisitRecord]{Items: make([]FarmerVisitRecord, len(visits)), NextCursor: page.NextCursor}
	for i, v := range visits {
		out.Items[i] = FarmerVisitRecord{
			ID: v.ID, PlotID: v.PlotID, VisitedAt: *v.VisitedAt, FA: faNamePtr(names, v.FAID),
			StageName: v.StageName, StageNameTe: v.StageNameTe, Issues: v.Issues,
		}
	}
	return out, nil
}

// MyNextVisit is the farmer's next planned visit, or nil.
func (s *Service) MyNextVisit(ctx context.Context) (*UpcomingVisit, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return nil, err
	}
	r, err := s.read().NextPlannedVisit(ctx, store.NextPlannedVisitParams{FarmerID: p.ID, Today: s.today()})
	if db.IsNoRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, apperr.Internalf("visits: next visit: %w", err)
	}
	nv := toNextVisit(r)
	nv.FA = faNamePtr(s.faNames(ctx, []uuid.UUID{r.FaID}), r.FaID)
	return &nv, nil
}

func toNextVisit(r store.VisitDetail) UpcomingVisit {
	nv := UpcomingVisit{VisitID: r.ID, PlotID: r.PlotID, PlannedSlot: "any", Purpose: r.Purpose}
	if r.PlannedFor != nil {
		nv.PlannedFor = *r.PlannedFor
	}
	if r.PlannedSlot != nil {
		nv.PlannedSlot = *r.PlannedSlot
	}
	return nv
}

// MyOpenCallback is the farmer's open call-back request, or nil.
func (s *Service) MyOpenCallback(ctx context.Context) (*CallbackInfo, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return nil, err
	}
	r, err := s.read().GetOpenCallbackForFarmer(ctx, p.ID)
	if db.IsNoRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, apperr.Internalf("visits: open callback: %w", err)
	}
	c := toCallback(r)
	return &c, nil
}

// errCallbackRace means a concurrent request opened the call-back first.
var errCallbackRace = errors.New("visits: concurrent callback request")

// RequestCallback asks the farmer's FA to call back. One request is open at a
// time: if one is open it is returned with created=false.
func (s *Service) RequestCallback(ctx context.Context) (CallbackInfo, bool, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return CallbackInfo{}, false, err
	}
	f, err := s.farmerSummary(ctx, p.ID)
	if err != nil {
		return CallbackInfo{}, false, err
	}
	if !f.AssignedFAID.Valid {
		return CallbackInfo{}, false, apperr.Conflict("no_fa_assigned", nil).
			WithMessage("you don't have a field assistant yet; one will call you within 2 days")
	}
	faID := f.AssignedFAID.UUID

	var out CallbackInfo
	created := false
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := store.New(tx)
		open, err := q.GetOpenCallbackForFarmer(ctx, p.ID)
		if err == nil {
			out = toCallback(open)
			return nil
		}
		if !db.IsNoRows(err) {
			return err
		}
		row, err := q.InsertCallback(ctx, store.InsertCallbackParams{
			ID: ids.New(), FarmerID: p.ID, FaID: faID, RequestedAt: s.deps.Clock.Now(),
		})
		if db.IsUniqueViolation(err, "callback_requests_one_open") {
			return errCallbackRace
		}
		if err != nil {
			return err
		}
		out, created = toCallback(row), true
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "visits.callback_requested", EntityType: "callback_request", EntityID: row.ID, FarmerID: p.ID,
			After: map[string]any{"status": CallbackOpen, "fa_id": faID},
		}); err != nil {
			return err
		}
		if err := s.deps.Events.Publish(ctx, tx, events.CallbackRequested{CallbackID: row.ID, FarmerID: p.ID, FAID: faID}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, faID)
	})
	if errors.Is(err, errCallbackRace) {
		c, err := s.MyOpenCallback(ctx)
		if err != nil || c == nil {
			return CallbackInfo{}, false, apperr.Internalf("visits: callback race: %v", err)
		}
		return *c, false, nil
	}
	if err != nil {
		return CallbackInfo{}, false, apperr.Internalf("visits: request callback: %w", err)
	}
	return out, created, nil
}

// CancelMyCallback withdraws the farmer's own open request. Idempotent.
func (s *Service) CancelMyCallback(ctx context.Context, callbackID uuid.UUID) (CallbackInfo, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return CallbackInfo{}, err
	}
	var out CallbackInfo
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := store.New(tx)
		cur, err := q.LockCallback(ctx, callbackID)
		if db.IsNoRows(err) || (err == nil && cur.FarmerID != p.ID) {
			return apperr.NotFound("call-back request")
		}
		if err != nil {
			return err
		}
		switch cur.Status {
		case CallbackCancelled:
			out = toCallback(cur)
			return nil
		case CallbackClosed:
			return apperr.Conflict("callback_closed", nil).WithMessage("your field assistant has already closed this request")
		}
		now := s.deps.Clock.Now()
		row, err := q.FinishCallback(ctx, store.FinishCallbackParams{
			ID: callbackID, Status: CallbackCancelled, ClosedAt: &now, ClosedBy: uuid.NullUUID{UUID: p.ID, Valid: true},
		})
		if err != nil {
			return err
		}
		out = toCallback(row)
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "visits.callback_cancelled", EntityType: "callback_request", EntityID: callbackID, FarmerID: p.ID,
			Before: map[string]any{"status": cur.Status}, After: map[string]any{"status": CallbackCancelled},
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, cur.FaID)
	})
	if err != nil {
		if _, ok := apperr.As(err); ok {
			return CallbackInfo{}, err
		}
		return CallbackInfo{}, apperr.Internalf("visits: cancel callback: %w", err)
	}
	return out, nil
}
