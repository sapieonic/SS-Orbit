package visits

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
	"github.com/sapionic/orbit/backend/internal/visits/store"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Service holds the visits business rules: FA sync commands, photos, the
// farmer app's visits and call-backs, HO reads, the missed-visit job and the
// reassignment subscriber.
type Service struct {
	deps  platform.Deps
	ports *Ports
}

// NewService builds the service. Ports are read at call time, never here.
func NewService(deps platform.Deps, ports *Ports) *Service {
	if ports == nil {
		ports = &Ports{}
	}
	return &Service{deps: deps, ports: ports}
}

// read returns queries on the pool, for reads outside a transaction.
func (s *Service) read() *store.Queries { return store.New(s.deps.Pool) }

// ist is India Standard Time. Visit days (planned_for, "missed the day after")
// are IST calendar days. A fixed zone avoids depending on tzdata.
var ist = time.FixedZone("IST", 5*60*60+30*60)

// dayOf returns t's IST calendar day as UTC midnight (how pgx reads a date).
func dayOf(t time.Time) time.Time {
	t = t.In(ist)
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// today is the current IST calendar day.
func (s *Service) today() time.Time { return dayOf(s.deps.Clock.Now()) }

// parseDay parses YYYY-MM-DD as UTC midnight.
func parseDay(v string) (time.Time, error) { return time.Parse(time.DateOnly, v) }

// farmerSummary fetches one farmer through the farmers port.
func (s *Service) farmerSummary(ctx context.Context, farmerID uuid.UUID) (xmod.FarmerSummary, error) {
	if s.ports.Farmers == nil {
		return xmod.FarmerSummary{}, errors.New("visits: farmers port not wired")
	}
	list, err := s.ports.Farmers.GetFarmerSummaries(ctx, []uuid.UUID{farmerID})
	if err != nil {
		return xmod.FarmerSummary{}, fmt.Errorf("visits: farmer summary: %w", err)
	}
	for _, f := range list {
		if f.ID == farmerID {
			return f, nil
		}
	}
	return xmod.FarmerSummary{}, apperr.NotFound("farmer")
}

// resolveFarmer applies the one FA-authorisation rule through the farmers
// port: it follows merge aliases and returns the canonical farmer ID the FA
// may act on (apperr.NotFound / Forbidden otherwise).
func (s *Service) resolveFarmer(ctx context.Context, faID, farmerID uuid.UUID) (uuid.UUID, error) {
	if s.ports.Farmers == nil {
		return uuid.Nil, errors.New("visits: farmers port not wired")
	}
	return s.ports.Farmers.ResolveFarmerForFA(ctx, faID, farmerID)
}

// farmerDistrict is the district of the farmer's village, stored on the visit
// for HO area scope. Null when the geo port is not wired or the farmer has no
// village.
func (s *Service) farmerDistrict(ctx context.Context, farmerID uuid.UUID) (uuid.NullUUID, error) {
	if s.ports.Geo == nil {
		return uuid.NullUUID{}, nil
	}
	f, err := s.farmerSummary(ctx, farmerID)
	if err != nil {
		return uuid.NullUUID{}, err
	}
	if !f.VillageID.Valid {
		return uuid.NullUUID{}, nil
	}
	vs, err := s.ports.Geo.GetVillages(ctx, []uuid.UUID{f.VillageID.UUID})
	if err != nil {
		return uuid.NullUUID{}, fmt.Errorf("visits: farmer village: %w", err)
	}
	for _, v := range vs {
		if v.ID == f.VillageID.UUID {
			return uuid.NullUUID{UUID: v.DistrictID, Valid: true}, nil
		}
	}
	return uuid.NullUUID{}, nil
}

// faNames looks up FA names. Names are decoration: if identity is not wired
// or fails, the lists still load without them.
func (s *Service) faNames(ctx context.Context, ids []uuid.UUID) map[uuid.UUID]FARef {
	out := map[uuid.UUID]FARef{}
	ids = uniqueIDs(ids)
	if s.ports.Identity == nil || len(ids) == 0 {
		return out
	}
	fas, err := s.ports.Identity.GetFieldAssistants(ctx, ids)
	if err != nil {
		logx.From(ctx).Warn("visits: FA names unavailable", "err", err)
		return out
	}
	for _, f := range fas {
		out[f.ID] = FARef{ID: f.ID, Name: f.Name, NameTe: f.NameTe}
	}
	return out
}

// farmerInfos looks up farmers (name, masked phone) and their villages for HO
// visit screens. Decoration like faNames: a missing or failing port leaves
// the fields out instead of failing the list.
func (s *Service) farmerInfos(ctx context.Context, ids []uuid.UUID) map[uuid.UUID]FarmerInfo {
	out := map[uuid.UUID]FarmerInfo{}
	ids = uniqueIDs(ids)
	if s.ports.Farmers == nil || len(ids) == 0 {
		return out
	}
	farmers, err := s.ports.Farmers.GetFarmerSummaries(ctx, ids)
	if err != nil {
		logx.From(ctx).Warn("visits: farmer names unavailable", "err", err)
		return out
	}
	var villageIDs []uuid.UUID
	for _, f := range farmers {
		if f.VillageID.Valid {
			villageIDs = append(villageIDs, f.VillageID.UUID)
		}
	}
	villages := map[uuid.UUID]xmod.Village{}
	if villageIDs = uniqueIDs(villageIDs); s.ports.Geo != nil && len(villageIDs) > 0 {
		vs, err := s.ports.Geo.GetVillages(ctx, villageIDs)
		if err != nil {
			logx.From(ctx).Warn("visits: village names unavailable", "err", err)
		}
		for _, v := range vs {
			villages[v.ID] = v
		}
	}
	for _, f := range farmers {
		info := FarmerInfo{Name: f.Name, NameTe: f.NameTe, PhoneMasked: phone.Mask(f.Phone)}
		if f.VillageID.Valid {
			id := f.VillageID.UUID
			info.VillageID = &id
			if v, ok := villages[id]; ok {
				info.VillageName, info.VillageNameTe = &v.Name, v.NameTe
			}
		}
		out[f.ID] = info
	}
	return out
}

func faNamePtr(names map[uuid.UUID]FARef, id uuid.UUID) *FARef {
	if n, ok := names[id]; ok {
		return &n
	}
	return nil
}

// issuesByVisit loads the issues of several visits, grouped by visit.
func (s *Service) issuesByVisit(ctx context.Context, q *store.Queries, visitIDs []uuid.UUID) (map[uuid.UUID][]IssueAdvice, error) {
	out := map[uuid.UUID][]IssueAdvice{}
	if len(visitIDs) == 0 {
		return out, nil
	}
	rows, err := q.ListVisitIssues(ctx, visitIDs)
	if err != nil {
		return nil, apperr.Internalf("visits: list issues: %w", err)
	}
	for _, r := range rows {
		out[r.VisitID] = append(out[r.VisitID], toIssue(r))
	}
	return out, nil
}

// withIssues converts rows to visits with their issues attached.
func (s *Service) withIssues(ctx context.Context, q *store.Queries, rows []store.VisitDetail) ([]VisitRecord, error) {
	ids := make([]uuid.UUID, len(rows))
	for i, r := range rows {
		ids[i] = r.ID
	}
	issues, err := s.issuesByVisit(ctx, q, ids)
	if err != nil {
		return nil, err
	}
	out := make([]VisitRecord, len(rows))
	for i, r := range rows {
		out[i] = toVisit(r)
		out[i].Issues = issues[r.ID]
		if out[i].Issues == nil {
			out[i].Issues = []IssueAdvice{}
		}
	}
	return out, nil
}

func toVisit(r store.VisitDetail) VisitRecord {
	return VisitRecord{
		ID:            r.ID,
		FarmerID:      r.FarmerID,
		PlotID:        r.PlotID,
		SeasonID:      r.SeasonID,
		FAID:          r.FaID,
		Status:        r.Status,
		PlannedFor:    r.PlannedFor,
		PlannedSlot:   r.PlannedSlot,
		Purpose:       r.Purpose,
		VisitedAt:     utcPtr(r.VisitedAt),
		Location:      parsePoint(r.LocationGeojson),
		FarmerPresent: r.FarmerPresent,
		StageID:       uuidPtr(r.StageID),
		StageName:     r.StageName,
		StageNameTe:   r.StageNameTe,
		Notes:         r.Notes,
		PhotoCount:    r.PhotoCount,
		Issues:        []IssueAdvice{},
		CreatedAt:     r.CreatedAt.UTC(),
		UpdatedAt:     r.UpdatedAt.UTC(),
	}
}

func toIssue(r store.VisitIssue) IssueAdvice {
	a := AdviceGiven{
		RuleID:      uuidPtr(r.AdvisoryRuleID),
		RuleVersion: r.RuleVersion,
		SaltID:      uuidPtr(r.SaltID),
		SaltName:    r.SaltName,
		SaltNameTe:  r.SaltNameTe,
		SKUID:       uuidPtr(r.SkuID),
		Dose:        r.DosePerAcre,
		DoseTe:      r.DosePerAcreTe,
	}
	// Product names only travel with a Shanmukha SKU; salt-only advice never
	// carries a brand.
	if a.SKUID != nil {
		a.ProductName, a.ProductNameTe = r.ProductName, r.ProductNameTe
	}
	return IssueAdvice{
		ID:               r.ID,
		IssueID:          r.IssueID,
		IssueName:        r.IssueName,
		IssueNameTe:      r.IssueNameTe,
		Severity:         r.Severity,
		AdviceStatus:     r.AdviceStatus,
		RequestedRuleID:  uuidPtr(r.RequestedRuleID),
		UnresolvedReason: r.UnresolvedReason,
		Advice:           a,
	}
}

func toCallback(r store.CallbackRequest) CallbackInfo {
	return CallbackInfo{
		ID:          r.ID,
		FarmerID:    r.FarmerID,
		FAID:        r.FaID,
		Status:      r.Status,
		Note:        r.Note,
		RequestedAt: r.RequestedAt.UTC(),
		ClosedAt:    utcPtr(r.ClosedAt),
	}
}

// pointGeoJSON encodes a point for ST_GeomFromGeoJSON.
func pointGeoJSON(p *Point) *string {
	if p == nil {
		return nil
	}
	s := `{"type":"Point","coordinates":[` + strconv.FormatFloat(p.Lng, 'f', -1, 64) + "," +
		strconv.FormatFloat(p.Lat, 'f', -1, 64) + "]}"
	return &s
}

// parsePoint decodes ST_AsGeoJSON output; "" means no location.
func parsePoint(geojson string) *Point {
	if geojson == "" {
		return nil
	}
	var g struct {
		Coordinates []float64 `json:"coordinates"`
	}
	if err := json.Unmarshal([]byte(geojson), &g); err != nil || len(g.Coordinates) < 2 {
		return nil
	}
	return &Point{Lng: g.Coordinates[0], Lat: g.Coordinates[1]}
}

func uniqueIDs(ids []uuid.UUID) []uuid.UUID {
	seen := make(map[uuid.UUID]bool, len(ids))
	out := make([]uuid.UUID, 0, len(ids))
	for _, id := range ids {
		if id != uuid.Nil && !seen[id] {
			seen[id] = true
			out = append(out, id)
		}
	}
	return out
}

func nullUUID(id *uuid.UUID) uuid.NullUUID {
	if id == nil {
		return uuid.NullUUID{}
	}
	return uuid.NullUUID{UUID: *id, Valid: true}
}

func uuidPtr(n uuid.NullUUID) *uuid.UUID {
	if !n.Valid {
		return nil
	}
	return &n.UUID
}

func utcPtr(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	u := t.UTC()
	return &u
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
