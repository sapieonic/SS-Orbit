package masters

import (
	"time"

	"github.com/google/uuid"
)

// Domain types returned by the service. JSON tags matter: these values are
// written to the audit log (before/after) and to the Redis caches.

// Crop with its stage calendar.
type Crop struct {
	ID           uuid.UUID `json:"id"`
	Code         string    `json:"code"`
	Name         string    `json:"name"`
	NameTe       string    `json:"name_te"`
	DurationDays *int32    `json:"duration_days"`
	Active       bool      `json:"active"`
	CreatedAt    time.Time `json:"created_at"`
	Stages       []Stage   `json:"stages"`
}

// Stage is one step of a crop calendar, in days after sowing (inclusive).
type Stage struct {
	ID       uuid.UUID `json:"id"`
	CropID   uuid.UUID `json:"crop_id"`
	Code     string    `json:"code"`
	Name     string    `json:"name"`
	NameTe   string    `json:"name_te"`
	Seq      int32     `json:"seq"`
	StartDay int32     `json:"start_day"`
	EndDay   int32     `json:"end_day"`
	Active   bool      `json:"active"`
}

// StageInput is one stage of a calendar being saved.
type StageInput struct {
	Code     string
	Name     string
	NameTe   string
	StartDay int32
	EndDay   int32
}

// CropInput creates a crop.
type CropInput struct {
	Code         string
	Name         string
	NameTe       string
	DurationDays *int32
	Stages       []StageInput // optional
}

// CropPatch edits a crop; nil fields are unchanged.
type CropPatch struct {
	Name         *string
	NameTe       *string
	DurationDays *int32
	Active       *bool
}

// Salt is an active ingredient.
type Salt struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	NameTe    *string   `json:"name_te"`
	Active    bool      `json:"active"`
	CreatedAt time.Time `json:"created_at"`
}

// SaltPatch edits a salt; nil fields are unchanged.
type SaltPatch struct {
	Name   *string
	NameTe *string
	Active *bool
}

// SKU is a Shanmukha product pack. Competitor brands are never stored.
type SKU struct {
	ID               uuid.UUID `json:"id"`
	Code             string    `json:"code"`
	ProductName      string    `json:"product_name"`
	ProductNameTe    *string   `json:"product_name_te"`
	SaltID           uuid.UUID `json:"salt_id"`
	PackSize         string    `json:"pack_size"`
	MRPPaise         int64     `json:"mrp_paise"`
	CashbackEligible bool      `json:"cashback_eligible"`
	Active           bool      `json:"active"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

// SKUInput creates a SKU.
type SKUInput struct {
	Code             string
	ProductName      string
	ProductNameTe    *string
	SaltID           uuid.UUID
	PackSize         string
	MRPPaise         int64
	CashbackEligible *bool // default true
}

// SKUPatch edits a SKU; nil fields are unchanged.
type SKUPatch struct {
	ProductName      *string
	ProductNameTe    *string
	SaltID           *uuid.UUID
	PackSize         *string
	MRPPaise         *int64
	CashbackEligible *bool
	Active           *bool
}

// Issue is a pest, disease or deficiency of one crop.
type Issue struct {
	ID        uuid.UUID `json:"id"`
	CropID    uuid.UUID `json:"crop_id"`
	Type      string    `json:"type"` // pest | disease | deficiency
	Name      string    `json:"name"`
	NameTe    string    `json:"name_te"`
	Active    bool      `json:"active"`
	CreatedAt time.Time `json:"created_at"`
}

// IssueInput creates an issue.
type IssueInput struct {
	CropID uuid.UUID
	Type   string
	Name   string
	NameTe string
}

// IssuePatch edits an issue; nil fields are unchanged.
type IssuePatch struct {
	Type   *string
	Name   *string
	NameTe *string
	Active *bool
}

// LatLng is a WGS84 point.
type LatLng struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

// Dealer is a shop that stocks Shanmukha SKUs.
type Dealer struct {
	ID          uuid.UUID   `json:"id"`
	Name        string      `json:"name"`
	NameTe      *string     `json:"name_te"`
	Phone       *string     `json:"phone"`
	VillageID   *uuid.UUID  `json:"village_id"`
	VillageName *string     `json:"-"` // from geo, for display only
	MandalName  *string     `json:"-"`
	Location    *LatLng     `json:"location"`
	Status      string      `json:"status"` // to_verify | active | inactive
	Source      string      `json:"source"` // ho | farmer_bill
	SKUIDs      []uuid.UUID `json:"sku_ids"`
	CreatedAt   time.Time   `json:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at"`
}

// DealerInput creates a dealer.
type DealerInput struct {
	Name      string
	NameTe    *string
	Phone     *string
	VillageID *uuid.UUID
	Location  *LatLng
	Status    *string // default to_verify
	SKUIDs    []uuid.UUID
}

// DealerPatch edits a dealer; nil fields are unchanged. SKUIDs, when set,
// replaces the stocked list.
type DealerPatch struct {
	Name      *string
	NameTe    *string
	Phone     *string
	VillageID *uuid.UUID
	Location  *LatLng
	Status    *string
	SKUIDs    *[]uuid.UUID
}

// DealerFilter narrows the admin dealer list.
type DealerFilter struct {
	Status    *string
	VillageID *uuid.UUID
	SKUID     *uuid.UUID
	Q         *string
}

// NearbyQuery is a farmer's "dealers near me" search.
type NearbyQuery struct {
	Lat, Lng float64
	RadiusKM *float64
	SKUID    *uuid.UUID
	Limit    *int
}

// NearbyDealer is an active dealer with its distance from the search point.
type NearbyDealer struct {
	ID        uuid.UUID
	Name      string
	NameTe    *string
	Phone     *string
	Location  LatLng
	DistanceM float64
}

// Rule is one version of an issue -> salt -> product rule, with names.
type Rule struct {
	ID            uuid.UUID  `json:"id"`
	RuleKey       uuid.UUID  `json:"rule_key"`
	Version       int32      `json:"version"`
	IssueID       uuid.UUID  `json:"issue_id"`
	CropID        uuid.UUID  `json:"crop_id"`
	IssueType     string     `json:"issue_type"`
	IssueName     string     `json:"issue_name"`
	IssueNameTe   string     `json:"issue_name_te"`
	SaltID        uuid.UUID  `json:"salt_id"`
	SaltName      string     `json:"salt_name"`
	SaltNameTe    *string    `json:"salt_name_te"`
	SKUID         *uuid.UUID `json:"sku_id"`
	SKUCode       *string    `json:"sku_code"`
	ProductName   *string    `json:"product_name"`
	ProductNameTe *string    `json:"product_name_te"`
	Dose          string     `json:"dose_per_acre"`
	DoseTe        string     `json:"dose_per_acre_te"`
	Status        string     `json:"status"` // draft | approved | superseded | rejected
	ChangeNote    *string    `json:"change_note"`
	CreatedBy     uuid.UUID  `json:"created_by"`
	CreatedAt     time.Time  `json:"created_at"`
	SubmittedBy   *uuid.UUID `json:"submitted_by"`
	SubmittedAt   *time.Time `json:"submitted_at"`
	ApprovedBy    *uuid.UUID `json:"approved_by"`
	ApprovedAt    *time.Time `json:"approved_at"`
	RejectedBy    *uuid.UUID `json:"rejected_by"`
	RejectedAt    *time.Time `json:"rejected_at"`
	ReviewNote    *string    `json:"review_note"`
}

// RuleInput drafts a new rule (RuleKey nil) or a new version of RuleKey.
type RuleInput struct {
	RuleKey    *uuid.UUID
	IssueID    uuid.UUID
	SaltID     uuid.UUID
	SKUID      *uuid.UUID // nil = salt only
	Dose       string
	DoseTe     string
	ChangeNote *string
}

// RuleDraft is the full content of a draft being rewritten.
type RuleDraft struct {
	SaltID     uuid.UUID
	SKUID      *uuid.UUID
	Dose       string
	DoseTe     string
	ChangeNote *string
}

// RuleFilter narrows the rule list. Nil fields are not filtered on.
type RuleFilter struct {
	RuleKey *uuid.UUID
	IssueID *uuid.UUID
	CropID  *uuid.UUID
	Status  *string
}

// Version is the masters version counter.
type Version struct {
	Version   int64
	UpdatedAt time.Time
}

// FarmerCrops is the farmer app's crop list: active crops with active stages.
type FarmerCrops struct {
	Version     int64         `json:"version"`
	Crops       []Crop        `json:"crops"`
	SeasonCodes SeasonCodeSet `json:"-"` // by date, never cached
}
