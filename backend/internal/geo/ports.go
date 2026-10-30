package geo

import (
	"context"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Identity is what geo needs from the identity module: FA names and status
// for allocation responses and checks (CONVENTIONS section 5).
type Identity interface {
	GetFieldAssistants(ctx context.Context, ids []uuid.UUID) ([]xmod.FieldAssistant, error)
}

// Ports are the interfaces this module needs from other modules. The
// integrator fills them in internal/app/wire.go. A nil Identity is tolerated:
// responses then carry no FA names and FA checks fall back to the foreign key.
type Ports struct {
	Identity Identity
}
