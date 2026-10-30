package geo

import (
	"context"
	"strings"

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
	villageListDefault   = 50
	villageListMax       = 200
	farmerSearchDefault  = 20
	farmerSearchMaxLimit = 50
)

// ListVillages lists villages for HO. With f.Q it returns the best matches
// (no next page); without, every matching village keyset-paginated.
func (s *Service) ListVillages(ctx context.Context, f VillageFilter, limit *int, cursor *string) (paging.Page[VillageInfo], error) {
	p, err := requireRead(ctx)
	if err != nil {
		return paging.Page[VillageInfo]{}, err
	}
	if f.DistrictID != nil {
		if err := checkDistrict(p, *f.DistrictID); err != nil {
			return paging.Page[VillageInfo]{}, err
		}
	}
	n := paging.Limit(limit, villageListDefault, villageListMax)
	if q := searchText(f.Q); q != "" {
		items, err := s.search(ctx, q, f, scopeIDs(p), n)
		return paging.Page[VillageInfo]{Items: items}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[VillageInfo]{}, err
	}
	rows, err := s.q.ListVillages(ctx, store.ListVillagesParams{
		MandalID: nullUUID(f.MandalID), DistrictID: nullUUID(f.DistrictID), DistrictScope: scopeIDs(p),
		CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[VillageInfo]{}, apperr.Internalf("geo: list villages: %w", err)
	}
	page := paging.Build(rows, n, func(r store.VillageDetail) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} })
	return paging.Map(page, toVillage), nil
}

// SearchVillagesForFarmer is the self sign-up "pick your village" search.
// Without a query it lists the filtered villages by name.
func (s *Service) SearchVillagesForFarmer(ctx context.Context, f VillageFilter, limit *int) ([]VillageInfo, error) {
	if _, err := auth.RequireKind(ctx, auth.KindFarmer); err != nil {
		return nil, err
	}
	return s.search(ctx, searchText(f.Q), f, []uuid.UUID{}, paging.Limit(limit, farmerSearchDefault, farmerSearchMaxLimit))
}

func (s *Service) search(ctx context.Context, q string, f VillageFilter, scope []uuid.UUID, n int) ([]VillageInfo, error) {
	esc := escapeLike(q)
	rows, err := s.q.SearchVillages(ctx, store.SearchVillagesParams{
		MandalID: nullUUID(f.MandalID), DistrictID: nullUUID(f.DistrictID), DistrictScope: scope,
		Q: q, Pattern: "%" + esc + "%", Prefix: esc + "%", RowLimit: int32(n),
	})
	if err != nil {
		return nil, apperr.Internalf("geo: search villages: %w", err)
	}
	out := make([]VillageInfo, len(rows))
	for i, r := range rows {
		out[i] = toVillage(r)
	}
	return out, nil
}

// searchText normalises a search query: trimmed, inner whitespace collapsed.
func searchText(q *string) string {
	if q == nil {
		return ""
	}
	return strings.Join(strings.Fields(*q), " ")
}

// escapeLike escapes LIKE wildcards so user input matches literally.
func escapeLike(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

// GetVillage returns one village for HO.
func (s *Service) GetVillage(ctx context.Context, id uuid.UUID) (VillageInfo, error) {
	p, err := requireRead(ctx)
	if err != nil {
		return VillageInfo{}, err
	}
	v, err := s.getVillage(ctx, s.q, id)
	if err != nil {
		return VillageInfo{}, err
	}
	if err := checkDistrict(p, v.DistrictID); err != nil {
		return VillageInfo{}, err
	}
	return v, nil
}

func (s *Service) getVillage(ctx context.Context, q *store.Queries, id uuid.UUID) (VillageInfo, error) {
	r, err := q.GetVillageDetail(ctx, id)
	if db.IsNoRows(err) {
		return VillageInfo{}, apperr.NotFound("village")
	}
	if err != nil {
		return VillageInfo{}, err
	}
	return toVillage(r), nil
}

// CreateVillage adds a village. FAs covering its mandal or district get it in
// their territory, so their versions are bumped.
func (s *Service) CreateVillage(ctx context.Context, f VillageFields) (VillageInfo, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return VillageInfo{}, err
	}
	if f, err = cleanVillage(f); err != nil {
		return VillageInfo{}, err
	}
	if f.Name == nil {
		return VillageInfo{}, apperr.Validation("name", "is required")
	}
	var out VillageInfo
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		m, err := s.getMandal(ctx, q, f.MandalID)
		if err != nil {
			return err
		}
		if err := checkDistrict(p, m.DistrictID); err != nil {
			return err
		}
		id := ids.New()
		if err := q.InsertVillage(ctx, store.InsertVillageParams{
			ID: id, MandalID: f.MandalID, LgdCode: f.LGDCode, Name: *f.Name, NameTe: f.NameTe, Lat: f.Lat, Lng: f.Lng,
		}); err != nil {
			return mapWriteError(err)
		}
		if out, err = s.getVillage(ctx, q, id); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{Action: "geo.village_created", EntityType: "village", EntityID: id, After: out}); err != nil {
			return err
		}
		return s.bumpMandals(ctx, tx, q, f.MandalID)
	})
	if err != nil {
		return VillageInfo{}, err
	}
	s.invalidateTree(ctx)
	return out, nil
}

// UpdateVillage changes the fields given and bumps the FAs covering it.
func (s *Service) UpdateVillage(ctx context.Context, id uuid.UUID, f VillageFields) (VillageInfo, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return VillageInfo{}, err
	}
	if f, err = cleanVillage(f); err != nil {
		return VillageInfo{}, err
	}
	var out VillageInfo
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := s.q.WithTx(tx)
		before, err := s.getVillage(ctx, q, id)
		if err != nil {
			return err
		}
		if err := checkDistrict(p, before.DistrictID); err != nil {
			return err
		}
		if _, err := q.UpdateVillage(ctx, store.UpdateVillageParams{
			ID: id, Name: f.Name, NameTe: f.NameTe, LgdCode: f.LGDCode, Lat: f.Lat, Lng: f.Lng,
		}); err != nil {
			return mapWriteError(err)
		}
		if out, err = s.getVillage(ctx, q, id); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{Action: "geo.village_updated", EntityType: "village", EntityID: id,
			Before: before, After: out}); err != nil {
			return err
		}
		cov, err := q.FAsCoveringVillage(ctx, id)
		if err != nil {
			return err
		}
		fas := make([]uuid.UUID, len(cov))
		for i, c := range cov {
			fas[i] = c.FaID
		}
		return territory.Bump(ctx, tx, fas...)
	})
	if err != nil {
		return VillageInfo{}, err
	}
	s.invalidateTree(ctx)
	return out, nil
}

func cleanVillage(f VillageFields) (VillageFields, error) {
	var err error
	if f.Name, err = cleanName("name", f.Name); err != nil {
		return f, err
	}
	if f.NameTe, err = cleanName("name_te", f.NameTe); err != nil {
		return f, err
	}
	if (f.Lat == nil) != (f.Lng == nil) {
		return f, apperr.Validation("lng", "lat and lng must be given together")
	}
	return f, nil
}
