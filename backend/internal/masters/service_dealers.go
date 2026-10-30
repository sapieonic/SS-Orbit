package masters

import (
	"context"
	"math"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/masters/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
)

// Dealer statuses.
const (
	dealerActive   = "active"
	dealerToVerify = "to_verify"
)

// Nearby search defaults.
const (
	nearbyDefaultRadiusKM = 25.0
	nearbyDefaultLimit    = 20
	nearbyMaxLimit        = 50
)

// Dealers are not part of the FA snapshot (farmers see them online through
// /v1/farmer/dealers), so dealer changes do not bump the masters version.

// ListDealers lists dealers with their stocked SKUs, oldest first.
func (s *Service) ListDealers(ctx context.Context, f DealerFilter, limit *int, cursor *string) (paging.Page[Dealer], error) {
	if err := requireRead(ctx); err != nil {
		return paging.Page[Dealer]{}, err
	}
	cur, n, err := pageArgs(limit, cursor)
	if err != nil {
		return paging.Page[Dealer]{}, err
	}
	rows, err := s.q.ListDealers(ctx, store.ListDealersParams{
		Status: f.Status, VillageID: nullUUID(f.VillageID), SkuID: nullUUID(f.SKUID), Q: f.Q,
		CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[Dealer]{}, apperr.Internalf("masters: list dealers: %w", err)
	}
	page := paging.Build(rows, n, func(r store.ListDealersRow) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} })
	dealers, err := toDealers(ctx, s.q, page.Items)
	if err != nil {
		return paging.Page[Dealer]{}, err
	}
	if err := s.addPlaceNames(ctx, dealers); err != nil {
		return paging.Page[Dealer]{}, err
	}
	return paging.Page[Dealer]{Items: dealers, NextCursor: page.NextCursor}, nil
}

// GetDealer returns one dealer.
func (s *Service) GetDealer(ctx context.Context, id uuid.UUID) (Dealer, error) {
	if err := requireRead(ctx); err != nil {
		return Dealer{}, err
	}
	d, err := loadDealer(ctx, s.q, id)
	if err != nil {
		return Dealer{}, err
	}
	list := []Dealer{d}
	if err := s.addPlaceNames(ctx, list); err != nil {
		return Dealer{}, err
	}
	return list[0], nil
}

// CreateDealer adds a dealer (source "ho"), to_verify unless a status is given.
func (s *Service) CreateDealer(ctx context.Context, in DealerInput) (Dealer, error) {
	if _, err := auth.RequireRole(ctx, dealerWriteRoles...); err != nil {
		return Dealer{}, err
	}
	errs := map[string]string{}
	in.Name = text("name", in.Name, errs)
	in.NameTe = optText("name_te", in.NameTe, errs)
	in.Phone = normalizePhone(in.Phone, errs)
	status := dealerToVerify
	if in.Status != nil {
		status = *in.Status
	}
	if status == dealerActive && in.Location == nil {
		errs["location"] = "a dealer needs a pinned location to be active"
	}
	if err := validationErr(errs); err != nil {
		return Dealer{}, err
	}
	var out Dealer
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		params := store.CreateDealerParams{
			ID: ids.New(), Name: in.Name, NameTe: in.NameTe, Phone: in.Phone, VillageID: nullUUID(in.VillageID),
			Status: status, Source: "ho",
		}
		if in.Location != nil {
			params.Lat, params.Lng = &in.Location.Lat, &in.Location.Lng
		}
		id, err := q.CreateDealer(ctx, params)
		if err != nil {
			if db.IsForeignKeyViolation(err) {
				return apperr.Validation("village_id", "unknown village")
			}
			return apperr.Internalf("masters: create dealer: %w", err)
		}
		if err := setDealerSKUs(ctx, q, id, in.SKUIDs); err != nil {
			return err
		}
		if out, err = loadDealer(ctx, q, id); err != nil {
			return err
		}
		return record(ctx, tx, "masters.dealer_created", "dealer", id, nil, out, nil)
	})
	return out, err
}

// UpdateDealer edits, verifies or deactivates a dealer. Dealers are never
// deleted: bills and invoices name them.
func (s *Service) UpdateDealer(ctx context.Context, id uuid.UUID, p DealerPatch) (Dealer, error) {
	if _, err := auth.RequireRole(ctx, dealerWriteRoles...); err != nil {
		return Dealer{}, err
	}
	errs := map[string]string{}
	p.Name = optText("name", p.Name, errs)
	p.NameTe = optText("name_te", p.NameTe, errs)
	p.Phone = normalizePhone(p.Phone, errs)
	if err := validationErr(errs); err != nil {
		return Dealer{}, err
	}
	var out Dealer
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if _, err := q.LockDealer(ctx, id); err != nil {
			return notFound(err, "dealer")
		}
		before, err := loadDealer(ctx, q, id)
		if err != nil {
			return err
		}
		status := before.Status
		if p.Status != nil {
			status = *p.Status
		}
		if status == dealerActive && before.Location == nil && p.Location == nil {
			return apperr.Validation("location", "a dealer needs a pinned location to be active")
		}
		params := store.UpdateDealerParams{
			ID: id, Name: p.Name, NameTe: p.NameTe, Phone: p.Phone, VillageID: nullUUID(p.VillageID), Status: p.Status,
		}
		if p.Location != nil {
			params.Lat, params.Lng = &p.Location.Lat, &p.Location.Lng
		}
		if err := q.UpdateDealer(ctx, params); err != nil {
			if db.IsForeignKeyViolation(err) {
				return apperr.Validation("village_id", "unknown village")
			}
			return apperr.Internalf("masters: update dealer: %w", err)
		}
		if p.SKUIDs != nil {
			if err := q.DeleteDealerSkus(ctx, id); err != nil {
				return apperr.Internalf("masters: clear dealer skus: %w", err)
			}
			if err := setDealerSKUs(ctx, q, id, *p.SKUIDs); err != nil {
				return err
			}
		}
		if out, err = loadDealer(ctx, q, id); err != nil {
			return err
		}
		return record(ctx, tx, "masters.dealer_updated", "dealer", id, before, out, nil)
	})
	return out, err
}

// NearbyDealers returns active dealers with a pinned location within the
// radius, nearest first (farmer product card). Only dealers stocking skuID
// when it is given.
func (s *Service) NearbyDealers(ctx context.Context, nq NearbyQuery) ([]NearbyDealer, error) {
	radius := nearbyDefaultRadiusKM
	if nq.RadiusKM != nil {
		radius = *nq.RadiusKM
	}
	n := paging.Limit(nq.Limit, nearbyDefaultLimit, nearbyMaxLimit)
	rows, err := s.q.NearbyDealers(ctx, store.NearbyDealersParams{
		Lat: nq.Lat, Lng: nq.Lng, RadiusM: radius * 1000, SkuID: nullUUID(nq.SKUID), RowLimit: int32(n),
	})
	if err != nil {
		return nil, apperr.Internalf("masters: nearby dealers: %w", err)
	}
	out := make([]NearbyDealer, len(rows))
	for i, r := range rows {
		out[i] = NearbyDealer{
			ID: r.ID, Name: r.Name, NameTe: r.NameTe, Phone: r.Phone,
			Location: LatLng{Lat: r.Lat, Lng: r.Lng}, DistanceM: math.Round(r.DistanceM),
		}
	}
	return out, nil
}

// setDealerSKUs adds the stocked SKUs; every one must be an active SKU.
func setDealerSKUs(ctx context.Context, q *store.Queries, dealerID uuid.UUID, skuIDs []uuid.UUID) error {
	uniq := dedupe(skuIDs)
	if len(uniq) == 0 {
		return nil
	}
	n, err := q.CountActiveSkus(ctx, uniq)
	if err != nil {
		return apperr.Internalf("masters: check skus: %w", err)
	}
	if int(n) != len(uniq) {
		return apperr.Validation("sku_ids", "every SKU must exist and be active")
	}
	if err := q.AddDealerSkus(ctx, store.AddDealerSkusParams{DealerID: dealerID, SkuIds: uniq}); err != nil {
		return apperr.Internalf("masters: add dealer skus: %w", err)
	}
	return nil
}

func loadDealer(ctx context.Context, q *store.Queries, id uuid.UUID) (Dealer, error) {
	rows, err := q.ListDealers(ctx, store.ListDealersParams{DealerID: uuid.NullUUID{UUID: id, Valid: true}, RowLimit: 1})
	if err != nil {
		return Dealer{}, apperr.Internalf("masters: load dealer: %w", err)
	}
	if len(rows) == 0 {
		return Dealer{}, apperr.NotFound("dealer")
	}
	list, err := toDealers(ctx, q, rows)
	if err != nil {
		return Dealer{}, err
	}
	return list[0], nil
}

// toDealers maps rows and attaches stocked SKU IDs with one query.
func toDealers(ctx context.Context, q *store.Queries, rows []store.ListDealersRow) ([]Dealer, error) {
	dealerIDs := make([]uuid.UUID, len(rows))
	for i, r := range rows {
		dealerIDs[i] = r.ID
	}
	links, err := q.ListDealerSkus(ctx, dealerIDs)
	if err != nil {
		return nil, apperr.Internalf("masters: dealer skus: %w", err)
	}
	skus := map[uuid.UUID][]uuid.UUID{}
	for _, l := range links {
		skus[l.DealerID] = append(skus[l.DealerID], l.SkuID)
	}
	out := make([]Dealer, len(rows))
	for i, r := range rows {
		d := Dealer{
			ID: r.ID, Name: r.Name, NameTe: r.NameTe, Phone: r.Phone, VillageID: uuidPtr(r.VillageID),
			Status: r.Status, Source: r.Source, SKUIDs: skus[r.ID],
			CreatedAt: r.CreatedAt.UTC(), UpdatedAt: r.UpdatedAt.UTC(),
		}
		if d.SKUIDs == nil {
			d.SKUIDs = []uuid.UUID{}
		}
		if r.HasLocation {
			d.Location = &LatLng{Lat: r.Lat, Lng: r.Lng}
		}
		out[i] = d
	}
	return out, nil
}

// addPlaceNames fills village and mandal names through the geo port. Without
// the port (tests, or before wiring) names are left empty.
func (s *Service) addPlaceNames(ctx context.Context, dealers []Dealer) error {
	if s.ports.Geo == nil {
		return nil
	}
	var villageIDs []uuid.UUID
	for _, d := range dealers {
		if d.VillageID != nil {
			villageIDs = append(villageIDs, *d.VillageID)
		}
	}
	villageIDs = dedupe(villageIDs)
	if len(villageIDs) == 0 {
		return nil
	}
	villages, err := s.ports.Geo.GetVillages(ctx, villageIDs)
	if err != nil {
		return apperr.Internalf("masters: village names: %w", err)
	}
	for _, v := range villages {
		for i := range dealers {
			if dealers[i].VillageID != nil && *dealers[i].VillageID == v.ID {
				name, mandal := v.Name, v.MandalName
				dealers[i].VillageName, dealers[i].MandalName = &name, &mandal
			}
		}
	}
	return nil
}

func normalizePhone(p *string, errs map[string]string) *string {
	if p == nil {
		return nil
	}
	e164, err := phone.Normalize(*p)
	if err != nil {
		errs["phone"] = "not a valid Indian mobile number"
		return nil
	}
	return &e164
}

func dedupe(in []uuid.UUID) []uuid.UUID {
	seen := make(map[uuid.UUID]bool, len(in))
	out := make([]uuid.UUID, 0, len(in))
	for _, id := range in {
		if !seen[id] {
			seen[id] = true
			out = append(out, id)
		}
	}
	return out
}
