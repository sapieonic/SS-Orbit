package messaging

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Ports are the interfaces this module needs from other modules, declared
// consumer-side with the exact signatures in CONVENTIONS section 5. The
// integrator fills the fields in internal/app/wire.go.
type Ports struct {
	Farmers  FarmerDirectory
	Geo      GeoDirectory
	Identity IdentityDirectory
	Visits   VisitAdviceSource
	Masters  ProductCatalog
}

// FarmerDirectory is provided by the farmers module.
type FarmerDirectory interface {
	// FarmerIDsForTargeting returns active farmers matching t who have current
	// programme consent. Every non-empty list in t narrows the result (AND
	// across lists); scopeTarget relies on this to keep scoped HO users inside
	// their districts.
	FarmerIDsForTargeting(ctx context.Context, t xmod.FarmerTarget) ([]uuid.UUID, error)
	GetFarmerSummaries(ctx context.Context, ids []uuid.UUID) ([]xmod.FarmerSummary, error)
}

// GeoDirectory is provided by the geo module.
type GeoDirectory interface {
	GetVillages(ctx context.Context, ids []uuid.UUID) ([]xmod.Village, error)
	// DistrictIDsForFAs returns the districts of each FA's current allocations
	// (district of the fa_offline HO alert).
	DistrictIDsForFAs(ctx context.Context, faIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error)
}

// IdentityDirectory is provided by the identity module.
type IdentityDirectory interface {
	GetFieldAssistants(ctx context.Context, ids []uuid.UUID) ([]xmod.FieldAssistant, error)
	PushTokens(ctx context.Context, subjectKind string, subjectIDs []uuid.UUID) (map[uuid.UUID][]string, error)
	// FAsNotSyncedSince returns active FAs whose last sync is before since (or
	// who never synced and were created before it).
	FAsNotSyncedSince(ctx context.Context, since time.Time) ([]xmod.FieldAssistant, error)
}

// VisitAdviceSource is provided by the visits module.
type VisitAdviceSource interface {
	GetVisitAdvice(ctx context.Context, visitID uuid.UUID) (xmod.VisitAdvice, error)
}

// ProductCatalog is provided by the masters module.
type ProductCatalog interface {
	// ProductTerms returns the lower-cased active product and salt names,
	// English and Telugu, for the advisory product-mention check.
	ProductTerms(ctx context.Context) ([]string, error)
}
