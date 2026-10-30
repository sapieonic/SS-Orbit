package identity

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// FarmerDirectory is what identity needs from the farmers module
// (CONVENTIONS section 5).
type FarmerDirectory interface {
	// FindOrCreateByPhone runs inside identity's OTP sign-in transaction so the
	// farmer row, device and session commit together.
	FindOrCreateByPhone(ctx context.Context, tx pgx.Tx, phone string, source string) (farmerID uuid.UUID, created bool, err error)
	// GetFarmerSummaries gives the farmer status hint returned at sign-in.
	GetFarmerSummaries(ctx context.Context, ids []uuid.UUID) ([]xmod.FarmerSummary, error)
}

// GeoDirectory is what identity needs from the geo module: the districts of
// each FA's current allocations, for HO area scope on FA management.
type GeoDirectory interface {
	DistrictIDsForFAs(ctx context.Context, faIDs []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error)
}

// Ports are the interfaces this module needs from other modules. The
// integrator fills them in internal/app/wire.go:
//
//	p.Identity.Farmers = m.Farmers.Service()
//	p.Identity.Geo = m.Geo.Service()
type Ports struct {
	Farmers FarmerDirectory
	Geo     GeoDirectory
}
