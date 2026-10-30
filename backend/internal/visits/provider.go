package visits

import (
	"context"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/visits/store"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Provider methods other modules call through their ports (CONVENTIONS
// section 5). They do no authorisation: the caller already did.

// NextPlannedVisit is the farmer's next planned visit from today (IST), or
// nil when none is planned. Used by farmers (home screen).
func (s *Service) NextPlannedVisit(ctx context.Context, farmerID uuid.UUID) (*xmod.PlannedVisit, error) {
	r, err := s.read().NextPlannedVisit(ctx, store.NextPlannedVisitParams{FarmerID: farmerID, Today: s.today()})
	if db.IsNoRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, apperr.Internalf("visits: next planned visit: %w", err)
	}
	nv := toNextVisit(r)
	return &xmod.PlannedVisit{
		VisitID: nv.VisitID, FAID: r.FaID, PlotID: r.PlotID, SeasonID: r.SeasonID,
		PlannedFor: nv.PlannedFor, PlannedSlot: nv.PlannedSlot, Purpose: nv.Purpose,
	}, nil
}

// GetVisitAdvice is what a logged visit found and advised, for the farmer's
// notice and SMS. Used by messaging (visit.logged). Issues whose advice is
// unresolved are left out: there is no confirmed advice to send.
func (s *Service) GetVisitAdvice(ctx context.Context, visitID uuid.UUID) (xmod.VisitAdvice, error) {
	q := s.read()
	v, err := q.GetVisit(ctx, visitID)
	if db.IsNoRows(err) {
		return xmod.VisitAdvice{}, apperr.NotFound("visit")
	}
	if err != nil {
		return xmod.VisitAdvice{}, apperr.Internalf("visits: visit advice: %w", err)
	}
	if v.Status != StatusDone || v.VisitedAt == nil {
		return xmod.VisitAdvice{}, apperr.NotFound("logged visit")
	}
	issues, err := s.issuesByVisit(ctx, q, []uuid.UUID{visitID})
	if err != nil {
		return xmod.VisitAdvice{}, err
	}
	out := xmod.VisitAdvice{
		VisitID: v.ID, FarmerID: v.FarmerID, FAID: v.FaID, VisitedAt: v.VisitedAt.UTC(),
		Items: make([]xmod.AdviceItem, 0, len(issues[visitID])),
	}
	for _, is := range issues[visitID] {
		if is.Unresolved() {
			continue // no confirmed advice to tell the farmer; HO follows up
		}
		a := is.Advice
		out.Items = append(out.Items, xmod.AdviceItem{
			IssueName: deref(is.IssueName), IssueNameTe: deref(is.IssueNameTe), Severity: is.Severity,
			SaltName: deref(a.SaltName), SaltNameTe: a.SaltNameTe,
			ProductName: a.ProductName, ProductNameTe: a.ProductNameTe, Dose: a.Dose, DoseTe: a.DoseTe,
		})
	}
	return out, nil
}
