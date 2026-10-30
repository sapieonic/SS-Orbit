package visits

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/visits/store"
)

// recentVisitsPerFarmer is how many logged visits per farmer go offline.
const recentVisitsPerFarmer = 3

// SnapshotVisit is one visit in the FA's offline snapshot: every planned visit
// of the FA's farmers and the last few logged ones with their advice.
type SnapshotVisit struct {
	ID            uuid.UUID       `json:"id"`
	FarmerID      uuid.UUID       `json:"farmer_id"`
	PlotID        uuid.UUID       `json:"plot_id"`
	SeasonID      uuid.UUID       `json:"season_id"`
	FAID          uuid.UUID       `json:"fa_id"`
	Status        string          `json:"status"`
	PlannedFor    *string         `json:"planned_for"` // YYYY-MM-DD
	PlannedSlot   *string         `json:"planned_slot"`
	Purpose       *string         `json:"purpose"`
	VisitedAt     *time.Time      `json:"visited_at"`
	FarmerPresent *bool           `json:"farmer_present"`
	StageID       *uuid.UUID      `json:"stage_id"`
	StageName     *string         `json:"stage_name"`
	StageNameTe   *string         `json:"stage_name_te"`
	Notes         *string         `json:"notes"`
	PhotoCount    int32           `json:"photo_count"`
	Issues        []SnapshotIssue `json:"issues"`
}

// SnapshotIssue is an issue found on a visit with the advice given. When
// advice_status is unresolved the advice fields are null.
type SnapshotIssue struct {
	ID            uuid.UUID  `json:"id"`
	IssueID       uuid.UUID  `json:"issue_id"`
	IssueName     *string    `json:"issue_name"`
	IssueNameTe   *string    `json:"issue_name_te"`
	Severity      string     `json:"severity"`
	AdviceStatus  string     `json:"advice_status"`
	RuleID        *uuid.UUID `json:"rule_id"`
	SaltID        *uuid.UUID `json:"salt_id"`
	SaltName      *string    `json:"salt_name"`
	SaltNameTe    *string    `json:"salt_name_te"`
	SKUID         *uuid.UUID `json:"sku_id"`
	ProductName   *string    `json:"product_name"`
	ProductNameTe *string    `json:"product_name_te"`
	Dose          *string    `json:"dose"`
	DoseTe        *string    `json:"dose_te"`
}

// SnapshotCallback is an open call-back request for the FA.
type SnapshotCallback struct {
	ID          uuid.UUID `json:"id"`
	FarmerID    uuid.UUID `json:"farmer_id"`
	RequestedAt time.Time `json:"requested_at"`
}

// snapshotVisits provides the `visits` section.
func (s *Service) snapshotVisits(ctx context.Context, sc territory.Scope) (any, error) {
	out := []SnapshotVisit{}
	if len(sc.FarmerIDs) == 0 {
		return out, nil
	}
	q := s.read()
	planned, err := q.ListPlannedVisitsForFarmers(ctx, sc.FarmerIDs)
	if err != nil {
		return nil, apperr.Internalf("visits: snapshot planned: %w", err)
	}
	done, err := q.ListRecentDoneVisitsForFarmers(ctx, store.ListRecentDoneVisitsForFarmersParams{
		FarmerIds: sc.FarmerIDs, PerFarmer: recentVisitsPerFarmer,
	})
	if err != nil {
		return nil, apperr.Internalf("visits: snapshot done: %w", err)
	}
	visits, err := s.withIssues(ctx, q, append(planned, done...))
	if err != nil {
		return nil, err
	}
	for _, v := range visits {
		out = append(out, toSnapshotVisit(v))
	}
	return out, nil
}

func toSnapshotVisit(v VisitRecord) SnapshotVisit {
	sv := SnapshotVisit{
		ID: v.ID, FarmerID: v.FarmerID, PlotID: v.PlotID, SeasonID: v.SeasonID, FAID: v.FAID, Status: v.Status,
		PlannedSlot: v.PlannedSlot, Purpose: v.Purpose, VisitedAt: v.VisitedAt, FarmerPresent: v.FarmerPresent,
		StageID: v.StageID, StageName: v.StageName, StageNameTe: v.StageNameTe, Notes: v.Notes, PhotoCount: v.PhotoCount,
		Issues: make([]SnapshotIssue, len(v.Issues)),
	}
	if v.PlannedFor != nil {
		d := v.PlannedFor.Format(time.DateOnly)
		sv.PlannedFor = &d
	}
	for i, is := range v.Issues {
		a := is.Advice
		sv.Issues[i] = SnapshotIssue{
			ID: is.ID, IssueID: is.IssueID, IssueName: is.IssueName, IssueNameTe: is.IssueNameTe, Severity: is.Severity,
			AdviceStatus: is.AdviceStatus, RuleID: a.RuleID, SaltID: a.SaltID, SaltName: a.SaltName, SaltNameTe: a.SaltNameTe, SKUID: a.SKUID,
			ProductName: a.ProductName, ProductNameTe: a.ProductNameTe, Dose: a.Dose, DoseTe: a.DoseTe,
		}
	}
	return sv
}

// snapshotCallbacks provides the `callbacks` section: the FA's open requests.
func (s *Service) snapshotCallbacks(ctx context.Context, sc territory.Scope) (any, error) {
	rows, err := s.read().ListOpenCallbacksForFA(ctx, sc.FAID)
	if err != nil {
		return nil, apperr.Internalf("visits: snapshot callbacks: %w", err)
	}
	out := make([]SnapshotCallback, len(rows))
	for i, r := range rows {
		out[i] = SnapshotCallback{ID: r.ID, FarmerID: r.FarmerID, RequestedAt: r.RequestedAt.UTC()}
	}
	return out, nil
}
