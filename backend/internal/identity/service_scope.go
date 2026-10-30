package identity

import (
	"context"
	"slices"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
)

// HO area scope on FA management. An HO user with districts sees and manages
// only FAs with a current allocation in one of those districts (geo port).
// FAs without any allocation (new logins, between hand-overs) are visible to
// unscoped users and to admins only. Out-of-scope FAs look like they do not
// exist (404), so a scoped user cannot probe for them.

// faVisibleTo applies the rule to one FA's districts.
func faVisibleTo(p auth.Principal, districts []uuid.UUID) bool {
	if !p.HasAreaScope() {
		return true
	}
	if len(districts) == 0 {
		return p.Role == auth.RoleAdmin
	}
	return slices.ContainsFunc(districts, p.CanSeeDistrict)
}

func (s *Service) faDistricts(ctx context.Context, faIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error) {
	if s.ports.Geo == nil {
		return nil, apperr.Internalf("identity: geo port is not wired")
	}
	m, err := s.ports.Geo.DistrictIDsForFAs(ctx, faIDs)
	if err != nil {
		return nil, apperr.Internalf("identity: fa districts: %w", err)
	}
	return m, nil
}

// checkFAScope returns NotFound when p may not see FA faID. Unscoped users
// pass without a geo call.
func (s *Service) checkFAScope(ctx context.Context, p auth.Principal, faID uuid.UUID) error {
	if !p.HasAreaScope() {
		return nil
	}
	m, err := s.faDistricts(ctx, []uuid.UUID{faID})
	if err != nil {
		return err
	}
	if !faVisibleTo(p, m[faID]) {
		return apperr.NotFound("field assistant")
	}
	return nil
}

// scopedFAIDs returns the FAs p may see, or nil for "every FA" (unscoped).
// There are a few hundred FAs at most, so this reads them all and asks geo
// once; the list query then filters by ID, which keeps keyset paging exact.
func (s *Service) scopedFAIDs(ctx context.Context, p auth.Principal) ([]uuid.UUID, error) {
	if !p.HasAreaScope() {
		return nil, nil
	}
	all, err := s.q.ListFieldAssistantIDs(ctx)
	if err != nil {
		return nil, apperr.Internalf("identity: list fa ids: %w", err)
	}
	if len(all) == 0 {
		return []uuid.UUID{}, nil
	}
	m, err := s.faDistricts(ctx, all)
	if err != nil {
		return nil, err
	}
	out := make([]uuid.UUID, 0, len(all))
	for _, id := range all {
		if faVisibleTo(p, m[id]) {
			out = append(out, id)
		}
	}
	return out, nil
}

// authorizeManageFA allows admin and ops users who can see FA id (area scope).
func (s *Service) authorizeManageFA(ctx context.Context, id uuid.UUID) error {
	p, err := authorizeManage(ctx)
	if err != nil {
		return err
	}
	return s.checkFAScope(ctx, p, id)
}

// FAStats returns the ADM-01 overview counts within the caller's area scope.
// Any HO role may read them.
func (s *Service) FAStats(ctx context.Context) (FACounts, error) {
	p, err := auth.RequireKind(ctx, auth.KindHO)
	if err != nil {
		return FACounts{}, err
	}
	scope, err := s.scopedFAIDs(ctx, p)
	if err != nil {
		return FACounts{}, err
	}
	r, err := s.q.FieldAssistantStats(ctx, store.FieldAssistantStatsParams{SyncedSince: tp(s.now().Add(-24 * time.Hour)), Ids: scope})
	if err != nil {
		return FACounts{}, apperr.Internalf("identity: fa stats: %w", err)
	}
	return FACounts{Active: int(r.Active), Leaving: int(r.Leaving), Inactive: int(r.Inactive), SyncedLast24h: int(r.SyncedRecently)}, nil
}
