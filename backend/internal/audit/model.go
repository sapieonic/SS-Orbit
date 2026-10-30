package audit

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// Event is one audit_log row as the service returns it.
type Event struct {
	ID         uuid.UUID
	OccurredAt time.Time
	ActorKind  string // farmer | fa | ho | system
	ActorID    *uuid.UUID
	OnBehalfOf *uuid.UUID
	Action     string
	EntityType string
	EntityID   *uuid.UUID
	FarmerID   *uuid.UUID
	PlotID     *uuid.UUID
	SeasonID   *uuid.UUID
	Before     json.RawMessage // nil when absent
	After      json.RawMessage
	Meta       json.RawMessage
	IP         *string
	DeviceID   *string
	RequestID  *string
}

// Filter narrows List. Nil fields are not filtered on.
type Filter struct {
	EntityType   *string
	EntityID     *uuid.UUID
	ActorID      *uuid.UUID
	FarmerID     *uuid.UUID
	ActionPrefix *string
	From         *time.Time // inclusive
	To           *time.Time // exclusive
}
