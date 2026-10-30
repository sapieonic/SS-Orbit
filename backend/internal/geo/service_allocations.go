package geo

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/geo/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Page sizes.
const (
	allocationListDefault = 50
	allocationListMax     = 200
)

// ListAllocations lists allocations (current only unless f.IncludeEnded),
// newest first, within the HO user's scope.
func (s *Service) ListAllocations(ctx context.Context, f AllocationFilter, limit *int, cursor *string) (paging.Page[FAAllocation], error) {
	p, err := requireRead(ctx)
	if err != nil {
		return paging.Page[FAAllocation]{}, err
	}
	if f.DistrictID != nil {
		if err := checkDistrict(p, *f.DistrictID); err != nil {
			return paging.Page[FAAllocation]{}, err
		}
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[FAAllocation]{}, err
	}
	n := paging.Limit(limit, allocationListDefault, allocationListMax)
	rows, err := s.q.ListAllocations(ctx, store.ListAllocationsParams{
		FaID: nullUUID(f.FAID), DistrictID: nullUUID(f.DistrictID), MandalID: nullUUID(f.MandalID), VillageID: nullUUID(f.VillageID),
		DistrictScope: scopeIDs(p), IncludeEnded: f.IncludeEnded,
		CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[FAAllocation]{}, apperr.Internalf("geo: list allocations: %w", err)
	}
	page := paging.Map(paging.Build(rows, n, func(r store.AllocationDetail) paging.Cursor {
		return paging.Cursor{At: r.CreatedAt, ID: r.ID}
	}), toAllocation)
	s.attachFAs(ctx, page.Items)
	return page, nil
}

// CreateAllocation allocates an FA to an area. One current lead per area
// (409 area_has_lead) and one current allocation per FA per area (409
// allocation_exists); the DB unique indexes back both checks under races.
func (s *Service) CreateAllocation(ctx context.Context, in NewAllocation) (FAAllocation, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return FAAllocation{}, err
	}
	if in.Level != LevelVillage && in.Level != LevelMandal && in.Level != LevelDistrict {
		return FAAllocation{}, apperr.Validation("level", "must be village, mandal or district")
	}
	districtID, err := s.areaDistrict(ctx, s.q, in.Level, in.AreaID)
	if err != nil {
		return FAAllocation{}, err
	}
	if err := checkDistrict(p, districtID); err != nil {
		return FAAllocation{}, err
	}
	if err := s.requireFAs(ctx, []uuid.UUID{in.FAID}); err != nil {
		return FAAllocation{}, err
	}
	var out FAAllocation
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		if err := checkAreaFree(ctx, q, in); err != nil {
			return err
		}
		id, err := insertAllocation(ctx, q, p, in.FAID, in.Level, in.AreaID, in.IsLead, s.deps.Clock.Now())
		if err != nil {
			return err
		}
		if out, err = getAllocation(ctx, q, id); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{Action: "geo.allocation_created", EntityType: "fa_allocation", EntityID: id, After: out}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, in.FAID)
	})
	if err != nil {
		return FAAllocation{}, err
	}
	items := []FAAllocation{out}
	s.attachFAs(ctx, items)
	return items[0], nil
}

// checkAreaFree reports the friendly 409s before the insert would hit an index.
func checkAreaFree(ctx context.Context, q *store.Queries, in NewAllocation) error {
	own, err := q.CurrentAllocationOnArea(ctx, store.CurrentAllocationOnAreaParams{FaID: in.FAID, Level: in.Level, AreaID: in.AreaID})
	if err == nil {
		return apperr.Conflict("allocation_exists", map[string]any{"allocation_id": own.ID}).
			WithMessage("this field assistant is already allocated to this area")
	}
	if !db.IsNoRows(err) {
		return err
	}
	if !in.IsLead {
		return nil
	}
	lead, err := q.CurrentLeadOnArea(ctx, store.CurrentLeadOnAreaParams{Level: in.Level, AreaID: in.AreaID})
	if err == nil {
		return apperr.Conflict("area_has_lead", map[string]any{"allocation_id": lead.ID, "fa_id": lead.FaID}).
			WithMessage("this area already has a lead field assistant; end that allocation or add this one as support")
	}
	if !db.IsNoRows(err) {
		return err
	}
	return nil
}

// insertAllocation inserts one allocation, mapping index and FK violations.
func insertAllocation(ctx context.Context, q *store.Queries, p auth.Principal, faID uuid.UUID, level string, areaID uuid.UUID, isLead bool, now time.Time) (uuid.UUID, error) {
	arg := store.InsertAllocationParams{
		ID: ids.New(), FaID: faID, Level: level, IsLead: isLead, ValidFrom: now,
		CreatedBy: uuid.NullUUID{UUID: p.ID, Valid: p.ID != uuid.Nil},
	}
	area := uuid.NullUUID{UUID: areaID, Valid: true}
	switch level {
	case LevelVillage:
		arg.VillageID = area
	case LevelMandal:
		arg.MandalID = area
	default:
		arg.DistrictID = area
	}
	r, err := q.InsertAllocation(ctx, arg)
	if db.IsForeignKeyViolation(err) {
		return uuid.Nil, apperr.NotFound("field assistant").WithDetail("fa_id", faID)
	}
	if err != nil {
		return uuid.Nil, mapWriteError(err)
	}
	return r.ID, nil
}

func getAllocation(ctx context.Context, q *store.Queries, id uuid.UUID) (FAAllocation, error) {
	r, err := q.GetAllocationDetail(ctx, id)
	if db.IsNoRows(err) {
		return FAAllocation{}, apperr.NotFound("allocation")
	}
	if err != nil {
		return FAAllocation{}, err
	}
	return toAllocation(r), nil
}

// areaDistrict checks the area exists and returns its district.
func (s *Service) areaDistrict(ctx context.Context, q *store.Queries, level string, areaID uuid.UUID) (uuid.UUID, error) {
	switch level {
	case LevelVillage:
		v, err := s.getVillage(ctx, q, areaID)
		return v.DistrictID, err
	case LevelMandal:
		m, err := s.getMandal(ctx, q, areaID)
		return m.DistrictID, err
	default:
		d, err := q.GetDistrict(ctx, areaID)
		if db.IsNoRows(err) {
			return uuid.Nil, apperr.NotFound("district")
		}
		return d.ID, err
	}
}

// EndAllocation ends a current allocation now.
func (s *Service) EndAllocation(ctx context.Context, id uuid.UUID) (FAAllocation, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return FAAllocation{}, err
	}
	var out FAAllocation
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		row, err := q.GetAllocationForUpdate(ctx, id)
		if db.IsNoRows(err) {
			return apperr.NotFound("allocation")
		}
		if err != nil {
			return err
		}
		before, err := getAllocation(ctx, q, id)
		if err != nil {
			return err
		}
		if err := checkDistrict(p, before.DistrictID); err != nil {
			return err
		}
		if row.ValidTo != nil {
			return apperr.Conflict("allocation_ended", map[string]any{"valid_to": row.ValidTo.UTC()}).
				WithMessage("this allocation has already ended")
		}
		if err := q.EndAllocation(ctx, store.EndAllocationParams{ID: id, ValidTo: ptr(s.deps.Clock.Now())}); err != nil {
			return err
		}
		if out, err = getAllocation(ctx, q, id); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{Action: "geo.allocation_ended", EntityType: "fa_allocation", EntityID: id,
			Before: before, After: out}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, row.FaID)
	})
	if err != nil {
		return FAAllocation{}, err
	}
	items := []FAAllocation{out}
	s.attachFAs(ctx, items)
	return items[0], nil
}

// Handover moves every current allocation of from to to in one transaction:
// from's allocations end and to gets the same areas with the same lead flag.
// If to already covers an area its allocation is kept, re-created as lead if
// from was the lead there. Farmers are not reassigned here (that is the
// farmers module's endpoint); AffectedVillageIDs tells the caller which.
func (s *Service) Handover(ctx context.Context, from, to uuid.UUID) (HandoverOutcome, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return HandoverOutcome{}, err
	}
	if from == to {
		return HandoverOutcome{}, apperr.Validation("to_fa_id", "must be a different field assistant")
	}
	if err := s.requireFAs(ctx, []uuid.UUID{to}, from); err != nil {
		return HandoverOutcome{}, err
	}
	res := HandoverOutcome{FromFAID: from, ToFAID: to, EndedIDs: []uuid.UUID{}, Allocations: []FAAllocation{}, AffectedVillageIDs: []uuid.UUID{}}
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		current, err := q.LockCurrentAllocationsForFA(ctx, from)
		if err != nil {
			return err
		}
		if len(current) == 0 {
			return nil
		}
		currentIDs := make([]uuid.UUID, len(current))
		for i, a := range current {
			currentIDs[i] = a.ID
		}
		details, err := q.GetAllocationDetails(ctx, currentIDs)
		if err != nil {
			return err
		}
		for _, d := range details {
			if err := checkDistrict(p, d.DistrictID); err != nil {
				return err
			}
		}
		// Expand before ending: afterwards from covers nothing.
		if res.AffectedVillageIDs, err = q.VillageIDsForFA(ctx, from); err != nil {
			return err
		}
		now := s.deps.Clock.Now()
		var kept []uuid.UUID
		for _, a := range current {
			id, err := handOverOne(ctx, q, p, a, to, now)
			if err != nil {
				return err
			}
			res.EndedIDs = append(res.EndedIDs, a.ID)
			kept = append(kept, id)
		}
		moved, err := q.GetAllocationDetails(ctx, kept)
		if err != nil {
			return err
		}
		for _, r := range moved {
			res.Allocations = append(res.Allocations, toAllocation(r))
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{Action: "geo.allocations_handed_over", EntityType: "field_assistant", EntityID: from,
			Meta: map[string]any{"to_fa_id": to, "ended_allocation_ids": res.EndedIDs, "allocation_ids": kept,
				"village_count": len(res.AffectedVillageIDs)}}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, from, to)
	})
	if err != nil {
		return HandoverOutcome{}, err
	}
	s.attachFAs(ctx, res.Allocations)
	return res, nil
}

// handOverOne ends a and returns the ID of to's allocation on the same area.
func handOverOne(ctx context.Context, q *store.Queries, p auth.Principal, a store.FaAllocation, to uuid.UUID, now time.Time) (uuid.UUID, error) {
	if err := q.EndAllocation(ctx, store.EndAllocationParams{ID: a.ID, ValidTo: &now}); err != nil {
		return uuid.Nil, err
	}
	areaID := allocationArea(a)
	existing, err := q.CurrentAllocationOnArea(ctx, store.CurrentAllocationOnAreaParams{FaID: to, Level: a.Level, AreaID: areaID})
	switch {
	case db.IsNoRows(err):
		return insertAllocation(ctx, q, p, to, a.Level, areaID, a.IsLead, now)
	case err != nil:
		return uuid.Nil, err
	case a.IsLead && !existing.IsLead:
		// Allocations are history: end the support row and start a lead row.
		if err := q.EndAllocation(ctx, store.EndAllocationParams{ID: existing.ID, ValidTo: &now}); err != nil {
			return uuid.Nil, err
		}
		return insertAllocation(ctx, q, p, to, a.Level, areaID, true, now)
	default:
		return existing.ID, nil
	}
}

func allocationArea(a store.FaAllocation) uuid.UUID {
	switch a.Level {
	case LevelVillage:
		return a.VillageID.UUID
	case LevelMandal:
		return a.MandalID.UUID
	default:
		return a.DistrictID.UUID
	}
}

func ptr[T any](v T) *T { return &v }
