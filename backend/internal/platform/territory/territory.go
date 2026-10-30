// Package territory supports the FA offline snapshot (CONVENTIONS section 8).
//
//   - Bump: any write to data inside an FA's territory bumps that FA's version
//     in territory_versions, in the same transaction. The version is part of
//     the snapshot cache key, so the next sync rebuilds.
//   - Registry: the farmers module sets the Resolver (FA -> villages/farmers);
//     modules register section Providers; the sync module calls Build.
package territory

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"sort"
	"sync"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/db"
)

// Bump increments the territory version of each FA (duplicates and uuid.Nil
// are ignored). Call it with the pgx.Tx of the write.
func Bump(ctx context.Context, tx db.DBTX, faIDs ...uuid.UUID) error {
	uniq := make([]uuid.UUID, 0, len(faIDs))
	for _, id := range faIDs {
		if id != uuid.Nil && !slices.Contains(uniq, id) {
			uniq = append(uniq, id)
		}
	}
	if len(uniq) == 0 {
		return nil
	}
	// Sorted to keep row-lock order stable across concurrent transactions.
	slices.SortFunc(uniq, func(a, b uuid.UUID) int { return slices.Compare(a[:], b[:]) })
	_, err := tx.Exec(ctx, `
		INSERT INTO territory_versions (fa_id, version, updated_at)
		SELECT id, 1, now() FROM unnest($1::uuid[]) AS t(id)
		ON CONFLICT (fa_id) DO UPDATE
		  SET version = territory_versions.version + 1, updated_at = now()`, uniq)
	if err != nil {
		return fmt.Errorf("territory: bump: %w", err)
	}
	return nil
}

// Version returns the FA's current territory version (0 if never bumped).
func Version(ctx context.Context, q db.DBTX, faID uuid.UUID) (int64, error) {
	var v int64
	err := q.QueryRow(ctx, `SELECT version FROM territory_versions WHERE fa_id = $1`, faID).Scan(&v)
	if db.IsNoRows(err) {
		return 0, nil
	}
	return v, err
}

// Scope is what an FA can see offline.
type Scope struct {
	FAID       uuid.UUID
	VillageIDs []uuid.UUID
	FarmerIDs  []uuid.UUID
}

// Resolver computes an FA's scope. Registered by the farmers module.
type Resolver func(ctx context.Context, faID uuid.UUID) (Scope, error)

// Provider returns one snapshot section for a scope. The value is JSON-encoded
// by the sync module, so return JSON-tagged structs or slices.
type Provider func(ctx context.Context, s Scope) (any, error)

// Snapshot section names (CONVENTIONS section 8).
const (
	SectionFarmers   = "farmers"
	SectionPlots     = "plots"
	SectionSeasons   = "seasons"
	SectionVisits    = "visits"
	SectionCallbacks = "callbacks"
	SectionAlerts    = "alerts"
	SectionMasters   = "masters"
	SectionVillages  = "villages"
)

// ErrNoResolver is returned by Build before the farmers module registered.
var ErrNoResolver = errors.New("territory: no resolver registered")

// Registry holds the resolver and section providers.
type Registry struct {
	mu        sync.RWMutex
	resolver  Resolver
	providers map[string]Provider
}

// NewRegistry returns an empty registry.
func NewRegistry() *Registry { return &Registry{providers: map[string]Provider{}} }

// SetResolver sets the scope resolver. Panics if one is already set.
func (r *Registry) SetResolver(fn Resolver) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.resolver != nil {
		panic("territory: resolver already set")
	}
	r.resolver = fn
}

// Register adds a section provider. Panics on duplicates.
func (r *Registry) Register(section string, p Provider) {
	if section == "" || p == nil {
		panic("territory: empty section or nil provider")
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, dup := r.providers[section]; dup {
		panic(fmt.Sprintf("territory: duplicate provider for section %q", section))
	}
	r.providers[section] = p
}

// Sections returns registered section names, sorted.
func (r *Registry) Sections() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]string, 0, len(r.providers))
	for s := range r.providers {
		out = append(out, s)
	}
	sort.Strings(out)
	return out
}

// Resolve returns the FA's scope.
func (r *Registry) Resolve(ctx context.Context, faID uuid.UUID) (Scope, error) {
	r.mu.RLock()
	res := r.resolver
	r.mu.RUnlock()
	if res == nil {
		return Scope{}, ErrNoResolver
	}
	s, err := res(ctx, faID)
	if err != nil {
		return Scope{}, fmt.Errorf("territory: resolve %s: %w", faID, err)
	}
	s.FAID = faID
	return s, nil
}

// Build resolves the FA's scope and runs every provider, returning
// section -> value. Any provider error fails the whole build.
func (r *Registry) Build(ctx context.Context, faID uuid.UUID) (map[string]any, error) {
	scope, err := r.Resolve(ctx, faID)
	if err != nil {
		return nil, err
	}
	out := map[string]any{}
	for _, section := range r.Sections() {
		r.mu.RLock()
		p := r.providers[section]
		r.mu.RUnlock()
		v, err := p(ctx, scope)
		if err != nil {
			return nil, fmt.Errorf("territory: section %s: %w", section, err)
		}
		out[section] = v
	}
	return out, nil
}
