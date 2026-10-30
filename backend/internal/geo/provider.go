package geo

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Provider methods other modules call through their ports (CONVENTIONS
// section 5). They run as the calling module's request, so they do no
// authorisation of their own.

// GetVillages returns the villages with their mandal and district. Unknown
// IDs are skipped; the order is by village name.
func (s *Service) GetVillages(ctx context.Context, ids []uuid.UUID) ([]xmod.Village, error) {
	if len(ids) == 0 {
		return []xmod.Village{}, nil
	}
	rows, err := s.q.GetVillageDetails(ctx, ids)
	if err != nil {
		return nil, fmt.Errorf("geo: get villages: %w", err)
	}
	out := make([]xmod.Village, len(rows))
	for i, r := range rows {
		out[i] = toXmodVillage(toVillage(r))
	}
	return out, nil
}

// FAsCoveringVillage returns the FAs whose current allocations cover the
// village: village level first, then mandal, then district; leads first
// within a level. An FA allocated at several levels appears once, at its most
// specific one. Empty (not an error) for an unknown or uncovered village.
func (s *Service) FAsCoveringVillage(ctx context.Context, villageID uuid.UUID) ([]xmod.Coverage, error) {
	rows, err := s.q.FAsCoveringVillage(ctx, villageID)
	if err != nil {
		return nil, fmt.Errorf("geo: fas covering village: %w", err)
	}
	out := make([]xmod.Coverage, 0, len(rows))
	seen := map[uuid.UUID]bool{}
	for _, r := range rows {
		if seen[r.FaID] {
			continue
		}
		seen[r.FaID] = true
		out = append(out, xmod.Coverage{FAID: r.FaID, Level: r.Level, IsLead: r.IsLead})
	}
	return out, nil
}

// VillageIDsForFA returns every village the FA's current allocations cover,
// mandal and district allocations expanded, sorted by ID. Cached in Redis
// under the FA's territory version: every allocation change and every new
// village in a covered area bumps it, so a stale entry is never read.
func (s *Service) VillageIDsForFA(ctx context.Context, faID uuid.UUID) ([]uuid.UUID, error) {
	// Read the version before the data: a concurrent bump then at worst
	// stores newer data under the older key, never older data under the newer.
	version, err := territory.Version(ctx, s.deps.Pool, faID)
	if err != nil {
		return nil, fmt.Errorf("geo: territory version: %w", err)
	}
	key := fmt.Sprintf("%s%s:v%d", faVillagesKeyBase, faID, version)
	var cached []uuid.UUID
	if s.deps.Cache.GetJSON(ctx, key, &cached) {
		return cached, nil
	}
	out, err := s.q.VillageIDsForFA(ctx, faID)
	if err != nil {
		return nil, fmt.Errorf("geo: village ids for fa: %w", err)
	}
	s.deps.Cache.SetJSON(ctx, key, out, faVillagesTTL)
	return out, nil
}

// DistrictIDsForFAs returns the districts of each FA's current allocations
// (village and mandal allocations resolved to their district). FAs with no
// current allocation are absent from the map.
func (s *Service) DistrictIDsForFAs(ctx context.Context, faIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error) {
	out := map[uuid.UUID][]uuid.UUID{}
	if len(faIDs) == 0 {
		return out, nil
	}
	rows, err := s.q.DistrictIDsForFAs(ctx, faIDs)
	if err != nil {
		return nil, fmt.Errorf("geo: district ids for fas: %w", err)
	}
	for _, r := range rows {
		out[r.FaID] = append(out[r.FaID], r.DistrictID)
	}
	return out, nil
}

// snapshotVillages is the FA snapshot's "villages" section: the villages in
// the FA's scope with mandal and district names, for offline enrolment.
func (s *Service) snapshotVillages(ctx context.Context, sc territory.Scope) (any, error) {
	if len(sc.VillageIDs) == 0 {
		return []VillageInfo{}, nil
	}
	rows, err := s.q.GetVillageDetails(ctx, sc.VillageIDs)
	if err != nil {
		return nil, fmt.Errorf("geo: snapshot villages: %w", err)
	}
	out := make([]VillageInfo, len(rows))
	for i, r := range rows {
		out[i] = toVillage(r)
	}
	return out, nil
}
