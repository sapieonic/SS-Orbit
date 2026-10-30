package farmers

import (
	"context"
	"slices"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Service holds the farmers business rules. Every state change runs in one
// transaction with its audit row, territory bumps and events.
type Service struct {
	deps  platform.Deps
	q     *store.Queries
	ports *Ports
}

// NewService builds the service. q reads outside transactions (store.New(pool)).
func NewService(deps platform.Deps, q *store.Queries, ports *Ports) *Service {
	if ports == nil {
		ports = &Ports{}
	}
	return &Service{deps: deps, q: q, ports: ports}
}

// inTx runs fn in a transaction with a store bound to it.
func (s *Service) inTx(ctx context.Context, fn func(q *store.Queries, tx pgx.Tx) error) error {
	return db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		return fn(store.New(tx), tx)
	})
}

// notFound maps "no rows" to apperr.NotFound(entity) and wraps anything else.
func notFound(err error, entity string) error {
	if db.IsNoRows(err) {
		return apperr.NotFound(entity)
	}
	return apperr.Internalf("farmers: load %s: %w", entity, err)
}

// village looks one village up through geo; unknown IDs are a validation error.
func (s *Service) village(ctx context.Context, id uuid.UUID) (xmod.Village, error) {
	vs, err := s.ports.Geo.GetVillages(ctx, []uuid.UUID{id})
	if err != nil {
		return xmod.Village{}, apperr.Internalf("farmers: get village: %w", err)
	}
	for _, v := range vs {
		if v.ID == id {
			return v, nil
		}
	}
	return xmod.Village{}, apperr.Validation("village_id", "unknown village")
}

// villages looks villages up by ID. Lookup failures are logged and give an
// empty map: names are decoration on lists, not worth failing a page for.
func (s *Service) villages(ctx context.Context, ids []uuid.UUID) map[uuid.UUID]xmod.Village {
	out := map[uuid.UUID]xmod.Village{}
	ids = uniq(ids)
	if len(ids) == 0 || s.ports.Geo == nil {
		return out
	}
	vs, err := s.ports.Geo.GetVillages(ctx, ids)
	if err != nil {
		logx.From(ctx).Warn("farmers: village lookup failed", "err", err)
		return out
	}
	for _, v := range vs {
		out[v.ID] = v
	}
	return out
}

// fieldAssistants looks FAs up by ID, logging failures like villages.
func (s *Service) fieldAssistants(ctx context.Context, ids []uuid.UUID) map[uuid.UUID]xmod.FieldAssistant {
	out := map[uuid.UUID]xmod.FieldAssistant{}
	ids = uniq(ids)
	if len(ids) == 0 || s.ports.Identity == nil {
		return out
	}
	fas, err := s.ports.Identity.GetFieldAssistants(ctx, ids)
	if err != nil {
		logx.From(ctx).Warn("farmers: FA lookup failed", "err", err)
		return out
	}
	for _, fa := range fas {
		out[fa.ID] = fa
	}
	return out
}

// faMayActOn is the one FA-authorisation rule (CONVENTIONS section 6): an FA
// acts only on active or pending farmers assigned to them. The FA snapshot
// holds exactly these farmers. (EnrolFarmer's claim of an unassigned farmer is
// the one exception, see enrolClaimCheck.)
func faMayActOn(faID uuid.UUID, f store.Farmer) error {
	if f.Status == StatusInactive {
		return apperr.Forbidden("this farmer was deactivated by HO")
	}
	if !f.AssignedFaID.Valid || f.AssignedFaID.UUID != faID {
		return apperr.Forbidden("this farmer is not assigned to you")
	}
	return nil
}

// resolveAlias follows a merge alias: an FA phone's farmer_id that was merged
// into another farmer resolves to that farmer. Other IDs are returned as is.
func resolveAlias(ctx context.Context, q *store.Queries, id uuid.UUID) (uuid.UUID, error) {
	a, err := q.GetAlias(ctx, id)
	if err == nil {
		return a.FarmerID, nil
	}
	if !db.IsNoRows(err) {
		return uuid.Nil, apperr.Internalf("farmers: alias: %w", err)
	}
	return id, nil
}

// leadFAForVillage returns the first lead FA covering the village (geo lists
// the most specific level first, leads first), or uuid.Nil when none.
func (s *Service) leadFAForVillage(ctx context.Context, villageID uuid.UUID) (uuid.UUID, error) {
	cov, err := s.ports.Geo.FAsCoveringVillage(ctx, villageID)
	if err != nil {
		return uuid.Nil, apperr.Internalf("farmers: FAs covering village: %w", err)
	}
	for _, c := range cov {
		if c.IsLead {
			return c.FAID, nil
		}
	}
	return uuid.Nil, nil
}

func uniq(ids []uuid.UUID) []uuid.UUID {
	out := make([]uuid.UUID, 0, len(ids))
	for _, id := range ids {
		if id != uuid.Nil && !slices.Contains(out, id) {
			out = append(out, id)
		}
	}
	return out
}
