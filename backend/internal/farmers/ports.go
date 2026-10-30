package farmers

import (
	"context"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Ports are the interfaces this module needs from other modules, declared
// consumer-side with the exact signatures in CONVENTIONS section 5. The
// integrator fills the fields in internal/app/wire.go.
type Ports struct {
	Identity IdentityPort
	Geo      GeoPort
	Masters  MastersPort
	Visits   VisitsPort
}

// IdentityPort gives FA details for the FA card, lists and reassignment checks.
type IdentityPort interface {
	GetFieldAssistants(ctx context.Context, ids []uuid.UUID) ([]xmod.FieldAssistant, error)
}

// GeoPort resolves villages and FA coverage, and the districts an FA works in
// (reassignment by an HO user with an area scope).
type GeoPort interface {
	GetVillages(ctx context.Context, ids []uuid.UUID) ([]xmod.Village, error)
	FAsCoveringVillage(ctx context.Context, villageID uuid.UUID) ([]xmod.Coverage, error)
	VillageIDsForFA(ctx context.Context, faID uuid.UUID) ([]uuid.UUID, error)
	DistrictIDsForFAs(ctx context.Context, faIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error)
}

// MastersPort computes the crop stage for a day after sowing.
type MastersPort interface {
	GetStagesForDay(ctx context.Context, cropID uuid.UUID, daysAfterSowing int) (xmod.Stage, error)
}

// VisitsPort gives the next planned FA visit for the farmer home.
type VisitsPort interface {
	NextPlannedVisit(ctx context.Context, farmerID uuid.UUID) (*xmod.PlannedVisit, error)
}
