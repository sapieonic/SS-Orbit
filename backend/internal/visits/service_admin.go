package visits

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/visits/store"
)

const (
	adminDefaultLimit = 50
	adminMaxLimit     = 200
	sampleDefaultSize = 20
	sampleMaxSize     = 100
	maxRangeDays      = 366
)

// Visit lists and detail are for admin, ops and agronomy (QA of advice);
// the dashboard counts are for every HO role.
var (
	readRoles  = []auth.Role{auth.RoleAdmin, auth.RoleOps, auth.RoleAgronomy}
	countRoles = []auth.Role{auth.RoleAdmin, auth.RoleOps, auth.RoleAgronomy, auth.RoleFinance}
)

// authorizeHO checks the role and returns the district scope for the queries:
// an HO user with an area scope sees only visits whose district (the farmer's,
// stored on the visit when it was written) is theirs; empty = every district.
func authorizeHO(ctx context.Context, roles []auth.Role) (auth.Principal, []uuid.UUID, error) {
	p, err := auth.RequireRole(ctx, roles...)
	if err != nil {
		return p, nil, err
	}
	scope := p.DistrictIDs
	if scope == nil {
		scope = []uuid.UUID{}
	}
	return p, scope, nil
}

func checkRange(from, to *time.Time) error {
	if from == nil || to == nil {
		return nil
	}
	if to.Before(*from) {
		return apperr.Validation("to", "must not be before from")
	}
	if to.Sub(*from) > maxRangeDays*24*time.Hour {
		return apperr.Validation("to", "range is at most 366 days")
	}
	return nil
}

// List searches visits, newest first.
func (s *Service) List(ctx context.Context, f ListFilter, limit *int, cursor *string) (paging.Page[VisitRecord], error) {
	_, scope, err := authorizeHO(ctx, readRoles)
	if err != nil {
		return paging.Page[VisitRecord]{}, err
	}
	if f.From != nil && f.To != nil && f.To.Before(*f.From) {
		return paging.Page[VisitRecord]{}, apperr.Validation("to", "must not be before from")
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[VisitRecord]{}, err
	}
	n := paging.Limit(limit, adminDefaultLimit, adminMaxLimit)
	q := s.read()
	rows, err := q.AdminListVisits(ctx, store.AdminListVisitsParams{
		FaID: nullUUID(f.FAID), ScopeDistrictIds: scope, FarmerID: nullUUID(f.FarmerID), Status: f.Status,
		FromDate: f.From, ToDate: f.To,
		CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[VisitRecord]{}, apperr.Internalf("visits: list: %w", err)
	}
	return s.visitPage(ctx, q, rows, n)
}

// Overdue lists planned visits whose day has passed without a log.
func (s *Service) Overdue(ctx context.Context, faID *uuid.UUID, limit *int, cursor *string) (paging.Page[VisitRecord], error) {
	_, scope, err := authorizeHO(ctx, readRoles)
	if err != nil {
		return paging.Page[VisitRecord]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[VisitRecord]{}, err
	}
	n := paging.Limit(limit, adminDefaultLimit, adminMaxLimit)
	q := s.read()
	rows, err := q.AdminListOverdue(ctx, store.AdminListOverdueParams{
		Today: s.today(), ScopeDistrictIds: scope, FaID: nullUUID(faID), CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[VisitRecord]{}, apperr.Internalf("visits: overdue: %w", err)
	}
	return s.visitPage(ctx, q, rows, n)
}

func (s *Service) visitPage(ctx context.Context, q *store.Queries, rows []store.VisitDetail, n int) (paging.Page[VisitRecord], error) {
	page := paging.Build(rows, n, func(r store.VisitDetail) paging.Cursor { return paging.Cursor{At: r.EventAt, ID: r.ID} })
	items, err := s.withIssues(ctx, q, page.Items)
	if err != nil {
		return paging.Page[VisitRecord]{}, err
	}
	s.attachNames(ctx, items)
	return paging.Page[VisitRecord]{Items: items, NextCursor: page.NextCursor}, nil
}

// attachNames fills FA names and the farmer (name, masked phone, village)
// on visits for HO screens. Best effort, like faNames.
func (s *Service) attachNames(ctx context.Context, items []VisitRecord) {
	s.attachFANames(ctx, items)
	farmerIDs := make([]uuid.UUID, len(items))
	for i, v := range items {
		farmerIDs[i] = v.FarmerID
	}
	farmers := s.farmerInfos(ctx, farmerIDs)
	for i := range items {
		if f, ok := farmers[items[i].FarmerID]; ok {
			items[i].Farmer = &f
		}
	}
}

func (s *Service) attachFANames(ctx context.Context, items []VisitRecord) {
	faIDs := make([]uuid.UUID, len(items))
	for i, v := range items {
		faIDs[i] = v.FAID
	}
	names := s.faNames(ctx, faIDs)
	for i := range items {
		if n, ok := names[items[i].FAID]; ok {
			items[i].FAName = &n.Name
		}
	}
}

// Get returns one visit with issues, advice and photos (presigned GET URLs).
func (s *Service) Get(ctx context.Context, visitID uuid.UUID) (VisitWithPhotos, error) {
	p, _, err := authorizeHO(ctx, readRoles)
	if err != nil {
		return VisitWithPhotos{}, err
	}
	q := s.read()
	row, err := q.GetVisit(ctx, visitID)
	if db.IsNoRows(err) || (err == nil && p.HasAreaScope() && !(row.DistrictID.Valid && p.CanSeeDistrict(row.DistrictID.UUID))) {
		return VisitWithPhotos{}, apperr.NotFound("visit")
	}
	if err != nil {
		return VisitWithPhotos{}, apperr.Internalf("visits: get: %w", err)
	}
	items, err := s.withIssues(ctx, q, []store.VisitDetail{row})
	if err != nil {
		return VisitWithPhotos{}, err
	}
	s.attachNames(ctx, items)
	photos, err := q.ListVisitPhotos(ctx, visitID)
	if err != nil {
		return VisitWithPhotos{}, apperr.Internalf("visits: photos: %w", err)
	}
	out := VisitWithPhotos{Visit: items[0], Photos: make([]Photo, len(photos))}
	for i, ph := range photos {
		out.Photos[i] = toPhoto(ph)
		if ph.UploadedAt == nil {
			continue
		}
		u, err := s.deps.Storage.PresignGet(ctx, ph.StorageKey, viewURLTTL)
		if err != nil {
			logx.From(ctx).Warn("visits: presign photo", "photo_id", ph.ID, "err", err)
			continue
		}
		out.Photos[i].URL = &u
	}
	return out, nil
}

// Sample draws a random sample of logged visits in [from, to] for QA review.
// The drawn IDs are audited so a QA round can show what it was given.
func (s *Service) Sample(ctx context.Context, from, to time.Time, faID *uuid.UUID, size *int) (Sample, error) {
	_, scope, err := authorizeHO(ctx, readRoles)
	if err != nil {
		return Sample{}, err
	}
	if err := checkRange(&from, &to); err != nil {
		return Sample{}, err
	}
	n := paging.Limit(size, sampleDefaultSize, sampleMaxSize)
	q := s.read()
	rows, err := q.SampleDoneVisits(ctx, store.SampleDoneVisitsParams{
		ScopeDistrictIds: scope, FromDate: from, ToDate: to, FaID: nullUUID(faID), Size: int32(n),
	})
	if err != nil {
		return Sample{}, apperr.Internalf("visits: sample: %w", err)
	}
	items, err := s.withIssues(ctx, q, rows)
	if err != nil {
		return Sample{}, err
	}
	s.attachNames(ctx, items)
	drawn := make([]uuid.UUID, len(items))
	for i, v := range items {
		drawn[i] = v.ID
	}
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		_, err := audit.Record(ctx, tx, audit.Entry{
			Action: "visits.sample_drawn", EntityType: "visit_sample", EntityID: ids.New(),
			Meta: map[string]any{
				"from": from.Format(time.DateOnly), "to": to.Format(time.DateOnly), "fa_id": faID,
				"size": n, "visit_ids": drawn,
			},
		})
		return err
	})
	if err != nil {
		return Sample{}, apperr.Internalf("visits: audit sample: %w", err)
	}
	return Sample{From: from, To: to, Size: n, Items: items}, nil
}

// Counts returns per-FA visit numbers for [from, to] (dashboard), optionally
// for one district and with the daily series for the overview chart.
func (s *Service) Counts(ctx context.Context, from, to time.Time, f CountsFilter) (Counts, error) {
	p, scope, err := authorizeHO(ctx, countRoles)
	if err != nil {
		return Counts{}, err
	}
	if err := checkRange(&from, &to); err != nil {
		return Counts{}, err
	}
	if f.DistrictID != nil && p.HasAreaScope() && !p.CanSeeDistrict(*f.DistrictID) {
		return Counts{}, apperr.Forbidden("this district is outside your area")
	}
	q := s.read()
	rows, err := q.VisitCountsByFA(ctx, store.VisitCountsByFAParams{
		FromDate: from, ToDate: to, Today: s.today(), FaID: nullUUID(f.FAID), ScopeDistrictIds: scope,
		DistrictID: nullUUID(f.DistrictID),
	})
	if err != nil {
		return Counts{}, apperr.Internalf("visits: counts: %w", err)
	}
	faIDs := make([]uuid.UUID, len(rows))
	for i, r := range rows {
		faIDs[i] = r.FaID
	}
	names := s.faNames(ctx, faIDs)
	out := Counts{From: from, To: to, Items: make([]FACounts, len(rows))}
	for i, r := range rows {
		out.Items[i] = FACounts{
			FAID: r.FaID, Planned: int(r.Planned), Done: int(r.Done), Missed: int(r.Missed), FarmersVisited: int(r.FarmersVisited),
		}
		if n, ok := names[r.FaID]; ok {
			out.Items[i].FAName = &n.Name
		}
	}
	if f.ByDay {
		days, err := q.VisitCountsByDay(ctx, store.VisitCountsByDayParams{
			FromDate: from, ToDate: to, Today: s.today(), FaID: nullUUID(f.FAID), ScopeDistrictIds: scope,
			DistrictID: nullUUID(f.DistrictID),
		})
		if err != nil {
			return Counts{}, apperr.Internalf("visits: day counts: %w", err)
		}
		out.Days = make([]DayCounts, len(days))
		for i, d := range days {
			out.Days[i] = DayCounts{Date: d.Day, Planned: int(d.Planned), Done: int(d.Done), Missed: int(d.Missed)}
		}
	}
	return out, nil
}
