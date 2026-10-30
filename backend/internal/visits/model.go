package visits

import (
	"time"

	"github.com/google/uuid"
)

// Visit statuses (visits.status).
const (
	StatusPlanned   = "planned"
	StatusDone      = "done"
	StatusCancelled = "cancelled"
	StatusMissed    = "missed"
)

// Call-back statuses (callback_requests.status).
const (
	CallbackOpen      = "open"
	CallbackClosed    = "closed"
	CallbackCancelled = "cancelled"
)

// VisitRecord is a planned or logged visit as the service returns it.
type VisitRecord struct {
	ID            uuid.UUID
	FarmerID      uuid.UUID
	PlotID        uuid.UUID
	SeasonID      uuid.UUID
	FAID          uuid.UUID
	FAName        *string     // filled for HO lists
	Farmer        *FarmerInfo // filled for HO lists and detail
	Status        string
	PlannedFor    *time.Time // date, UTC midnight
	PlannedSlot   *string
	Purpose       *string
	VisitedAt     *time.Time
	Location      *Point
	FarmerPresent *bool
	StageID       *uuid.UUID
	StageName     *string
	StageNameTe   *string
	Notes         *string
	PhotoCount    int32
	Issues        []IssueAdvice
	CreatedAt     time.Time
	UpdatedAt     time.Time
}

// Point is a WGS84 point.
type Point struct {
	Lat float64
	Lng float64
}

// Advice statuses (visit_issues.advice_status).
const (
	AdviceGivenStatus = "given"
	AdviceUnresolved  = "unresolved"
)

// IssueAdvice is one issue found on a visit with the advice given. When
// AdviceStatus is unresolved the rule the FA picked did not check out:
// Advice is empty, RequestedRuleID is what the FA sent and UnresolvedReason
// says why.
type IssueAdvice struct {
	ID               uuid.UUID
	IssueID          uuid.UUID
	IssueName        *string
	IssueNameTe      *string
	Severity         string
	AdviceStatus     string
	RequestedRuleID  *uuid.UUID
	UnresolvedReason *string
	Advice           AdviceGiven
}

// Unresolved reports an issue stored without advice.
func (i IssueAdvice) Unresolved() bool { return i.AdviceStatus == AdviceUnresolved }

// AdviceGiven is the salt-first advice as copied at log time. SKUID and the
// product names are nil when no Shanmukha product maps to the salt.
type AdviceGiven struct {
	RuleID        *uuid.UUID
	RuleVersion   *int32
	SaltID        *uuid.UUID // nil when unresolved
	SaltName      *string
	SaltNameTe    *string
	SKUID         *uuid.UUID
	ProductName   *string
	ProductNameTe *string
	Dose          *string
	DoseTe        *string
}

// SaltOnly reports advice of a salt without a Shanmukha product (false when
// there is no advice at all).
func (a AdviceGiven) SaltOnly() bool { return a.SaltID != nil && a.SKUID == nil }

// Photo is a visit photo. URL is a presigned GET, set for HO once uploaded.
type Photo struct {
	ID          uuid.UUID
	VisitID     uuid.UUID
	ContentType string
	Bytes       *int32
	UploadedAt  *time.Time
	URL         *string
}

// VisitWithPhotos is a visit with its photos (HO detail page).
type VisitWithPhotos struct {
	Visit  VisitRecord
	Photos []Photo
}

// UploadTarget tells the phone where and how to upload a photo.
type UploadTarget struct {
	PhotoID    uuid.UUID
	StorageKey string
	URL        string
	Method     string
	Headers    map[string]string
	ExpiresAt  time.Time
}

// CallbackInfo is a farmer's "call me back" request.
type CallbackInfo struct {
	ID          uuid.UUID
	FarmerID    uuid.UUID
	FAID        uuid.UUID
	Status      string
	Note        *string
	RequestedAt time.Time
	ClosedAt    *time.Time
}

// FARef identifies an FA for the farmer app.
type FARef struct {
	ID     uuid.UUID
	Name   string
	NameTe *string
}

// FarmerVisitRecord is a logged visit as the farmer sees it.
type FarmerVisitRecord struct {
	ID          uuid.UUID
	PlotID      uuid.UUID
	VisitedAt   time.Time
	FA          *FARef
	StageName   *string
	StageNameTe *string
	Issues      []IssueAdvice
}

// UpcomingVisit is the farmer's next planned visit.
type UpcomingVisit struct {
	VisitID     uuid.UUID
	PlotID      uuid.UUID
	PlannedFor  time.Time
	PlannedSlot string
	Purpose     *string
	FA          *FARef
}

// ListFilter narrows the HO visit list. Nil fields are not filtered on.
// From and To are IST calendar days, inclusive.
type ListFilter struct {
	FAID     *uuid.UUID
	FarmerID *uuid.UUID
	Status   *string
	From     *time.Time
	To       *time.Time
}

// Sample is a random sample of logged visits for QA review.
type Sample struct {
	From  time.Time
	To    time.Time
	Size  int
	Items []VisitRecord
}

// FACounts are one FA's visit numbers for a date range.
type FACounts struct {
	FAID           uuid.UUID
	FAName         *string
	Planned        int
	Done           int
	Missed         int
	FarmersVisited int
}

// Counts are visit numbers per FA for a date range; Days is the daily
// series (nil unless asked for).
type Counts struct {
	From  time.Time
	To    time.Time
	Items []FACounts
	Days  []DayCounts
}

// DayCounts are one day's visit numbers summed over the matching FAs.
type DayCounts struct {
	Date    time.Time // UTC midnight of the IST day
	Planned int
	Done    int
	Missed  int
}

// CountsFilter narrows the dashboard counts. ByDay adds the daily series.
type CountsFilter struct {
	FAID       *uuid.UUID
	DistrictID *uuid.UUID
	ByDay      bool
}

// FarmerInfo is the farmer as HO visit screens show them: current name, masked
// phone and village (looked up through the farmers and geo ports).
type FarmerInfo struct {
	Name          *string
	NameTe        *string
	PhoneMasked   string
	VillageID     *uuid.UUID
	VillageName   *string
	VillageNameTe *string
}
