package geo

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/geo/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// AdminTree returns the district -> mandal tree the HO user can see.
func (s *Service) AdminTree(ctx context.Context) (Hierarchy, error) {
	p, err := requireRead(ctx)
	if err != nil {
		return Hierarchy{}, err
	}
	t, err := s.tree(ctx)
	if err != nil {
		return Hierarchy{}, err
	}
	if !p.HasAreaScope() {
		return t, nil
	}
	out := Hierarchy{Districts: []HierarchyDistrict{}}
	for _, d := range t.Districts {
		if p.CanSeeDistrict(d.ID) {
			out.Districts = append(out.Districts, d)
		}
	}
	return out, nil
}

// FarmerTree returns the whole tree for the farmer's village picker.
func (s *Service) FarmerTree(ctx context.Context) (Hierarchy, error) {
	if _, err := auth.RequireKind(ctx, auth.KindFarmer); err != nil {
		return Hierarchy{}, err
	}
	return s.tree(ctx)
}

// tree builds the full tree, cached in Redis until the next geography write.
func (s *Service) tree(ctx context.Context) (Hierarchy, error) {
	var t Hierarchy
	if s.deps.Cache.GetJSON(ctx, treeCacheKey, &t) {
		return t, nil
	}
	districts, err := s.q.ListDistricts(ctx)
	if err != nil {
		return Hierarchy{}, apperr.Internalf("geo: list districts: %w", err)
	}
	mandals, err := s.q.ListMandalVillageCounts(ctx)
	if err != nil {
		return Hierarchy{}, apperr.Internalf("geo: list mandals: %w", err)
	}
	byDistrict := map[uuid.UUID][]HierarchyMandal{}
	for _, m := range mandals {
		byDistrict[m.DistrictID] = append(byDistrict[m.DistrictID], HierarchyMandal{
			ID: m.ID, Name: m.Name, NameTe: m.NameTe, LGDCode: m.LgdCode, VillageCount: int(m.VillageCount),
		})
	}
	t = Hierarchy{Districts: make([]HierarchyDistrict, 0, len(districts))}
	for _, d := range districts {
		td := HierarchyDistrict{ID: d.ID, Name: d.Name, NameTe: d.NameTe, LGDCode: d.LgdCode, Mandals: byDistrict[d.ID]}
		if td.Mandals == nil {
			td.Mandals = []HierarchyMandal{}
		}
		for _, m := range td.Mandals {
			td.VillageCount += m.VillageCount
		}
		t.Districts = append(t.Districts, td)
	}
	s.deps.Cache.SetJSON(ctx, treeCacheKey, t, treeCacheTTL)
	return t, nil
}

// invalidateTree drops the cached tree. Call it after the write committed.
func (s *Service) invalidateTree(ctx context.Context) { s.deps.Cache.Delete(ctx, treeCacheKey) }

// ListDistricts returns the districts the HO user can see, by name.
func (s *Service) ListDistricts(ctx context.Context) ([]DistrictInfo, error) {
	p, err := requireRead(ctx)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.ListDistricts(ctx)
	if err != nil {
		return nil, apperr.Internalf("geo: list districts: %w", err)
	}
	out := make([]DistrictInfo, 0, len(rows))
	for _, r := range rows {
		if p.CanSeeDistrict(r.ID) {
			out = append(out, toDistrict(r))
		}
	}
	return out, nil
}

// CreateDistrict adds a district. Area-scoped HO users cannot: the new
// district would be outside their scope.
func (s *Service) CreateDistrict(ctx context.Context, f DistrictFields) (DistrictInfo, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return DistrictInfo{}, err
	}
	if p.HasAreaScope() {
		return DistrictInfo{}, apperr.Forbidden("only HO users without an area scope can add districts")
	}
	if f, err = cleanDistrict(f); err != nil {
		return DistrictInfo{}, err
	}
	if f.Name == nil {
		return DistrictInfo{}, apperr.Validation("name", "is required")
	}
	var out DistrictInfo
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		r, err := s.q.WithTx(tx).InsertDistrict(ctx, store.InsertDistrictParams{
			ID: ids.New(), LgdCode: f.LGDCode, Name: *f.Name, NameTe: f.NameTe, State: f.State,
		})
		if err != nil {
			return mapWriteError(err)
		}
		out = toDistrict(r)
		_, err = audit.Record(ctx, tx, audit.Entry{Action: "geo.district_created", EntityType: "district", EntityID: out.ID, After: out})
		return err
	})
	if err != nil {
		return DistrictInfo{}, err
	}
	s.invalidateTree(ctx)
	return out, nil
}

// UpdateDistrict changes the fields given. A rename bumps the territory of
// every FA allocated inside the district (names are in their snapshot).
func (s *Service) UpdateDistrict(ctx context.Context, id uuid.UUID, f DistrictFields) (DistrictInfo, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return DistrictInfo{}, err
	}
	if err := checkDistrict(p, id); err != nil {
		return DistrictInfo{}, err
	}
	if f, err = cleanDistrict(f); err != nil {
		return DistrictInfo{}, err
	}
	var out DistrictInfo
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		before, err := q.GetDistrict(ctx, id)
		if db.IsNoRows(err) {
			return apperr.NotFound("district")
		}
		if err != nil {
			return err
		}
		r, err := q.UpdateDistrict(ctx, store.UpdateDistrictParams{
			ID: id, Name: f.Name, NameTe: f.NameTe, LgdCode: f.LGDCode, State: f.State,
		})
		if err != nil {
			return mapWriteError(err)
		}
		out = toDistrict(r)
		if _, err := audit.Record(ctx, tx, audit.Entry{Action: "geo.district_updated", EntityType: "district", EntityID: id,
			Before: toDistrict(before), After: out}); err != nil {
			return err
		}
		if f.Name == nil && f.NameTe == nil {
			return nil
		}
		fas, err := q.FAIDsCoveringDistrict(ctx, id)
		if err != nil {
			return err
		}
		return territory.Bump(ctx, tx, fas...)
	})
	if err != nil {
		return DistrictInfo{}, err
	}
	s.invalidateTree(ctx)
	return out, nil
}

func cleanDistrict(f DistrictFields) (DistrictFields, error) {
	var err error
	if f.Name, err = cleanName("name", f.Name); err != nil {
		return f, err
	}
	if f.NameTe, err = cleanName("name_te", f.NameTe); err != nil {
		return f, err
	}
	if f.State, err = cleanName("state", f.State); err != nil {
		return f, err
	}
	return f, nil
}

// ListMandals returns mandals, optionally of one district, within the HO
// user's scope.
func (s *Service) ListMandals(ctx context.Context, districtID *uuid.UUID) ([]MandalInfo, error) {
	p, err := requireRead(ctx)
	if err != nil {
		return nil, err
	}
	if districtID != nil {
		if err := checkDistrict(p, *districtID); err != nil {
			return nil, err
		}
	}
	rows, err := s.q.ListMandals(ctx, store.ListMandalsParams{DistrictID: nullUUID(districtID), DistrictScope: scopeIDs(p)})
	if err != nil {
		return nil, apperr.Internalf("geo: list mandals: %w", err)
	}
	out := make([]MandalInfo, len(rows))
	for i, r := range rows {
		out[i] = MandalInfo{ID: r.ID, DistrictID: r.DistrictID, DistrictName: r.DistrictName, DistrictNameTe: r.DistrictNameTe,
			Name: r.Name, NameTe: r.NameTe, LGDCode: r.LgdCode, CreatedAt: r.CreatedAt.UTC()}
	}
	return out, nil
}

// CreateMandal adds a mandal to a district.
func (s *Service) CreateMandal(ctx context.Context, f MandalFields) (MandalInfo, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return MandalInfo{}, err
	}
	if err := checkDistrict(p, f.DistrictID); err != nil {
		return MandalInfo{}, err
	}
	if f, err = cleanMandal(f); err != nil {
		return MandalInfo{}, err
	}
	if f.Name == nil {
		return MandalInfo{}, apperr.Validation("name", "is required")
	}
	var out MandalInfo
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		if _, err := q.GetDistrict(ctx, f.DistrictID); db.IsNoRows(err) {
			return apperr.NotFound("district")
		} else if err != nil {
			return err
		}
		id := ids.New()
		if _, err := q.InsertMandal(ctx, store.InsertMandalParams{
			ID: id, DistrictID: f.DistrictID, LgdCode: f.LGDCode, Name: *f.Name, NameTe: f.NameTe,
		}); err != nil {
			return mapWriteError(err)
		}
		if out, err = s.getMandal(ctx, q, id); err != nil {
			return err
		}
		_, err = audit.Record(ctx, tx, audit.Entry{Action: "geo.mandal_created", EntityType: "mandal", EntityID: id, After: out})
		return err
	})
	if err != nil {
		return MandalInfo{}, err
	}
	s.invalidateTree(ctx)
	return out, nil
}

// UpdateMandal changes the fields given. A rename bumps the territory of the
// FAs covering any of its villages.
func (s *Service) UpdateMandal(ctx context.Context, id uuid.UUID, f MandalFields) (MandalInfo, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return MandalInfo{}, err
	}
	if f, err = cleanMandal(f); err != nil {
		return MandalInfo{}, err
	}
	var out MandalInfo
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		before, err := s.getMandal(ctx, q, id)
		if err != nil {
			return err
		}
		if err := checkDistrict(p, before.DistrictID); err != nil {
			return err
		}
		if _, err := q.UpdateMandal(ctx, store.UpdateMandalParams{ID: id, Name: f.Name, NameTe: f.NameTe, LgdCode: f.LGDCode}); err != nil {
			return mapWriteError(err)
		}
		if out, err = s.getMandal(ctx, q, id); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{Action: "geo.mandal_updated", EntityType: "mandal", EntityID: id,
			Before: before, After: out}); err != nil {
			return err
		}
		if f.Name == nil && f.NameTe == nil {
			return nil
		}
		return s.bumpMandals(ctx, tx, q, id)
	})
	if err != nil {
		return MandalInfo{}, err
	}
	s.invalidateTree(ctx)
	return out, nil
}

func cleanMandal(f MandalFields) (MandalFields, error) {
	var err error
	if f.Name, err = cleanName("name", f.Name); err != nil {
		return f, err
	}
	if f.NameTe, err = cleanName("name_te", f.NameTe); err != nil {
		return f, err
	}
	return f, nil
}

func (s *Service) getMandal(ctx context.Context, q *store.Queries, id uuid.UUID) (MandalInfo, error) {
	r, err := q.GetMandal(ctx, id)
	if db.IsNoRows(err) {
		return MandalInfo{}, apperr.NotFound("mandal")
	}
	if err != nil {
		return MandalInfo{}, err
	}
	return MandalInfo{ID: r.ID, DistrictID: r.DistrictID, DistrictName: r.DistrictName, DistrictNameTe: r.DistrictNameTe,
		Name: r.Name, NameTe: r.NameTe, LGDCode: r.LgdCode, CreatedAt: r.CreatedAt.UTC()}, nil
}

// bumpMandals bumps the territory of every FA covering villages of the
// mandals (their offline village list or names changed).
func (s *Service) bumpMandals(ctx context.Context, tx pgx.Tx, q *store.Queries, mandalIDs ...uuid.UUID) error {
	if len(mandalIDs) == 0 {
		return nil
	}
	fas, err := q.FAIDsCoveringMandals(ctx, mandalIDs)
	if err != nil {
		return err
	}
	return territory.Bump(ctx, tx, fas...)
}
