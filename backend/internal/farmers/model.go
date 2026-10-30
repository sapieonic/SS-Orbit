package farmers

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Farmer statuses, plans, sources, consent purposes and methods (schema CHECKs).
const (
	StatusPending  = "pending_profile"
	StatusActive   = "active"
	StatusInactive = "inactive"

	SourceSelf = "self"
	SourceFA   = "fa"
	SourceHO   = "ho"

	PurposeProgramme = "programme"

	MethodApp   = "app"
	MethodFAOTP = "fa_otp"

	AreaBoundary = "boundary"
	AreaTyped    = "typed"

	SeasonActive    = "active"
	SeasonHarvested = "harvested"
	SeasonAbandoned = "abandoned"
)

// Purposes lists every consent purpose in display order.
var Purposes = []string{"programme", "soil_partner", "schemes_finance", "loyalty"}

// FarmerRecord is a farmer record as the service returns it.
type FarmerRecord struct {
	ID                 uuid.UUID
	Phone              string // E.164
	Name               *string
	NameTe             *string
	Language           string
	VillageID          *uuid.UUID
	MandalID           *uuid.UUID
	DistrictID         *uuid.UUID
	AssignedFAID       *uuid.UUID
	Source             string
	EnrolledByFAID     *uuid.UUID
	PhotoKey           *string
	Plan               string
	Status             string
	ProfileCompletedAt *time.Time
	Version            int32
	CreatedAt          time.Time
	UpdatedAt          time.Time
}

// Point is a WGS84 point.
type Point struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

// PlotRecord is a farmer's plot. Boundary is GeoJSON (nil when only a pin exists).
type PlotRecord struct {
	ID           uuid.UUID
	FarmerID     uuid.UUID
	Label        string
	VillageID    *uuid.UUID
	Boundary     json.RawMessage
	Pin          *Point
	AreaAcres    float64
	AreaSource   string
	GPSAccuracyM *float64
	Status       string
	Version      int32
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// SeasonRecord is one crop season on a plot.
type SeasonRecord struct {
	ID             uuid.UUID
	FarmerID       uuid.UUID
	PlotID         uuid.UUID
	SeasonCode     string
	CropID         uuid.UUID
	SowingDate     *time.Time // date, UTC midnight
	PreviousCropID *uuid.UUID
	Status         string
	Version        int32
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// ConsentRecord is one append-only consent row.
type ConsentRecord struct {
	ID             uuid.UUID
	Purpose        string
	Granted        bool
	Method         string
	CapturedByFAID *uuid.UUID
	NoticeVersion  string
	Language       string
	AudioPlayed    bool
	CreatedAt      time.Time
}

// ConsentState is the latest consent for one purpose. Granted is nil when
// the farmer was never asked.
type ConsentState struct {
	Purpose       string
	Granted       *bool
	Method        *string
	NoticeVersion *string
	UpdatedAt     *time.Time
}

// Home is the farmer app home screen.
type Home struct {
	Farmer    FarmerRecord
	PhotoURL  *string // presigned GET, nil without a photo
	Village   *xmod.Village
	Plots     []HomePlotView
	FA        *xmod.FieldAssistant
	NextVisit *xmod.PlannedVisit
}

// HomePlotView is a plot with its active season and the stage computed from the
// sowing date.
type HomePlotView struct {
	Plot            PlotRecord
	ActiveSeason    *SeasonRecord
	DaysAfterSowing *int
	Stage           *xmod.Stage
}

// ProfileInput completes or edits a farmer's own profile.
type ProfileInput struct {
	Name      *string
	NameTe    *string
	Language  *string
	VillageID *uuid.UUID
	PhotoKey  *string // farmer app only (PATCH /v1/farmer/me)
}

// ConsentInput grants or withdraws one purpose from the farmer app.
type ConsentInput struct {
	Purpose       string
	Granted       bool
	NoticeVersion string
	AudioPlayed   bool
}

// NewPlotInput adds a plot from the farmer app (pin + typed area).
type NewPlotInput struct {
	Label     *string
	Pin       Point
	AreaAcres float64
}

// NewSeasonInput starts a season.
type NewSeasonInput struct {
	SeasonCode     string
	CropID         uuid.UUID
	SowingDate     *time.Time
	PreviousCropID *uuid.UUID
}

// ListFilter narrows the HO farmer list. Nil fields are not filtered on.
type ListFilter struct {
	DistrictID *uuid.UUID
	MandalID   *uuid.UUID
	VillageID  *uuid.UUID
	FAID       *uuid.UUID
	Unassigned bool
	CropID     *uuid.UUID
	Status     *string
	Plan       *string
	Q          *string
}

// ListItem is one row of the HO farmer list.
type ListItem struct {
	Farmer           FarmerRecord
	Village          *xmod.Village
	FA               *xmod.FieldAssistant
	ActiveCropIDs    []uuid.UUID
	TotalAreaAcres   float64
	PlotCount        int32
	ProgrammeConsent *bool
	ConsentsGranted  int
	ConsentPending   bool // no programme consent recorded yet
}

// Farmer360View is everything the HO portal shows about one farmer.
type Farmer360View struct {
	Farmer         FarmerRecord
	PhotoURL       *string // presigned GET, nil without a photo
	Village        *xmod.Village
	AssignedFA     *xmod.FieldAssistant
	EnrolledByFA   *xmod.FieldAssistant
	Consents       []ConsentState
	ConsentPending bool // no programme consent recorded yet
	ConsentHistory []ConsentRecord
	Plots          []PlotWithSeasons
}

// PlotWithSeasons is a plot and its seasons, newest first.
type PlotWithSeasons struct {
	Plot    PlotRecord
	Seasons []SeasonRecord
}

// AdminUpdate edits a farmer from the HO portal.
type AdminUpdate struct {
	ExpectedVersion int32
	Name            *string
	NameTe          *string
	Language        *string
	VillageID       *uuid.UUID
	Phone           *string
	Plan            *string
	Reason          *string // required when the plan changes
}

// ReassignInput selects farmers by ID or by village for a new FA.
type ReassignInput struct {
	ToFAID     uuid.UUID
	FromFAID   *uuid.UUID // required with VillageIDs: only that FA's farmers move
	FarmerIDs  []uuid.UUID
	VillageIDs []uuid.UUID
}

// OverviewStats are the HO overview numbers (ADM-01). Total excludes
// deactivated farmers; ConsentPending counts farmers (not deactivated) with no
// programme consent recorded.
type OverviewStats struct {
	Total          int
	Active         int
	PendingProfile int
	Inactive       int
	Premium        int
	ConsentPending int
	NewLast7Days   int
	Unassigned     int // active farmers with no FA
}

// CoveringFA is one FA covering the farmer's village, for "Look for FAs"
// (FAR-08/09). CoverageLevel is the allocation level that covers the village.
type CoveringFA struct {
	FA            xmod.FieldAssistant
	CoverageLevel string
	IsLead        bool
	IsMyFA        bool
}

// Phone lookup outcomes for the FA app's "already registered?" check.
const (
	LookupNew                = "new"
	LookupMine               = "mine"
	LookupUnassignedInMyArea = "unassigned_in_my_area"
	LookupOutsideMyArea      = "outside_my_area"
	LookupOtherFA            = "other_fa"
	LookupDeactivated        = "deactivated"
)

// LookupResult is the result of an FA's phone check. FarmerID is set only when
// the FA may act on (mine) or claim (unassigned_in_my_area) the farmer.
type LookupResult struct {
	Status   string
	FarmerID *uuid.UUID
}
