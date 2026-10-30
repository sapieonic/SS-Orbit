package events

import "github.com/google/uuid"

// Event names (CONVENTIONS section 7). Add new events here with a payload
// struct below; Bus.Subscribe panics for names not in this catalog.
const (
	NameFarmerRegistered       = "farmer.registered"
	NameFarmerProfileCompleted = "farmer.profile_completed"
	NameFarmersReassigned      = "farmers.reassigned"
	NameVisitLogged            = "visit.logged"
	NameCallbackRequested      = "callback.requested"
	NameMastersPublished       = "masters.published"
	NameDeviceRevoked          = "device.revoked"
	// NameSystemPing is a no-op event for smoke tests (`go run ./cmd/worker -ping`).
	NameSystemPing = "system.ping"
)

// catalog lists every known event name.
var catalog = map[string]bool{
	NameFarmerRegistered:       true,
	NameFarmerProfileCompleted: true,
	NameFarmersReassigned:      true,
	NameVisitLogged:            true,
	NameCallbackRequested:      true,
	NameMastersPublished:       true,
	NameDeviceRevoked:          true,
	NameSystemPing:             true,
}

// Known reports whether name is in the catalog.
func Known(name string) bool { return catalog[name] }

// FarmerRegistered: a farmer record was created (self sign-up, FA enrolment, HO).
// Publisher: farmers. Subscribers: messaging (FA + HO alerts, welcome SMS).
type FarmerRegistered struct {
	FarmerID       uuid.UUID  `json:"farmer_id"`
	VillageID      *uuid.UUID `json:"village_id,omitempty"`
	Source         string     `json:"source"` // self | fa | ho
	EnrolledByFAID *uuid.UUID `json:"enrolled_by_fa_id,omitempty"`
}

func (FarmerRegistered) EventName() string { return NameFarmerRegistered }

// FarmerProfileCompleted: a self-signed-up farmer picked their village.
// Publisher: farmers. Subscribers: messaging (alert the FA).
type FarmerProfileCompleted struct {
	FarmerID  uuid.UUID `json:"farmer_id"`
	VillageID uuid.UUID `json:"village_id"`
}

func (FarmerProfileCompleted) EventName() string { return NameFarmerProfileCompleted }

// FarmersReassigned: farmers moved to another FA.
// Publisher: farmers. Subscribers: visits (move open work), messaging (SMS new FA name).
type FarmersReassigned struct {
	FarmerIDs []uuid.UUID `json:"farmer_ids"`
	FromFAID  *uuid.UUID  `json:"from_fa_id,omitempty"`
	ToFAID    uuid.UUID   `json:"to_fa_id"`
}

func (FarmersReassigned) EventName() string { return NameFarmersReassigned }

// VisitLogged: an FA logged a visit.
// Publisher: visits. Subscribers: messaging (advice notice + SMS).
type VisitLogged struct {
	VisitID  uuid.UUID `json:"visit_id"`
	FarmerID uuid.UUID `json:"farmer_id"`
	PlotID   uuid.UUID `json:"plot_id"`
	SeasonID uuid.UUID `json:"season_id"`
	FAID     uuid.UUID `json:"fa_id"`
}

func (VisitLogged) EventName() string { return NameVisitLogged }

// CallbackRequested: a farmer asked their FA to call back.
// Publisher: visits. Subscribers: messaging (FA alert).
type CallbackRequested struct {
	CallbackID uuid.UUID `json:"callback_id"`
	FarmerID   uuid.UUID `json:"farmer_id"`
	FAID       uuid.UUID `json:"fa_id"`
}

func (CallbackRequested) EventName() string { return NameCallbackRequested }

// MastersPublished: a master kind got a new version.
// Publisher: masters. Subscribers: masters (cache invalidation).
type MastersPublished struct {
	Kind    string `json:"kind"`
	Version int64  `json:"version"`
}

func (MastersPublished) EventName() string { return NameMastersPublished }

// DeviceRevoked: a device was revoked by HO.
// Publisher: identity. Subscribers: sync (drop cached snapshot).
type DeviceRevoked struct {
	DeviceID    uuid.UUID `json:"device_id"`
	SubjectKind string    `json:"subject_kind"` // farmer | fa
	SubjectID   uuid.UUID `json:"subject_id"`
}

func (DeviceRevoked) EventName() string { return NameDeviceRevoked }

// SystemPing is a diagnostic event with no business meaning.
type SystemPing struct {
	Message string `json:"message"`
}

func (SystemPing) EventName() string { return NameSystemPing }
