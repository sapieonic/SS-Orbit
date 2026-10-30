package masters

import (
	"context"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Geo is what masters needs from the geo module: village and mandal names for
// the HO dealer list. Optional: when nil, dealers are returned without names.
type Geo interface {
	GetVillages(ctx context.Context, ids []uuid.UUID) ([]xmod.Village, error)
}

// Ports are the interfaces this module needs from other modules
// (CONVENTIONS section 5). The integrator fills them in internal/app/wire.go.
type Ports struct {
	Geo Geo
}
