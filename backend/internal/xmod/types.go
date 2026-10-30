// Package xmod holds the plain value types passed across module ports
// (CONVENTIONS section 5). They live here, not in the provider package, so
// modules that call each other (farmers <-> visits, identity <-> farmers) never
// import each other. Only the integrator changes this file; providers fill the
// fields, consumers read them.
package xmod

import (
	"time"

	"github.com/google/uuid"
)

// FieldAssistant is an FA as other modules see it. Provider: identity.
type FieldAssistant struct {
	ID           uuid.UUID
	Code         string // login ID, e.g. FA-KDP-014
	Name         string
	NameTe       *string
	Phone        string // E.164
	Level        string // village | mandal | district
	Languages    []string
	WorkingHours *string
	PhotoKey     *string
	Status       string // active | leaving | inactive
	LastSyncAt   *time.Time
}

// FarmerSummary is a farmer as other modules see it. Provider: farmers.
type FarmerSummary struct {
	ID           uuid.UUID
	Phone        string // E.164
	Name         *string
	NameTe       *string
	Language     string // te | en
	VillageID    uuid.NullUUID
	AssignedFAID uuid.NullUUID
	Plan         string // free | premium
	Status       string // pending_profile | active | inactive
	// ProgrammeConsent is true when the latest 'programme' consent row is a grant.
	ProgrammeConsent bool
}

// FarmerTarget selects farmers for an advisory. Empty slices mean "any".
// Provider: farmers.
type FarmerTarget struct {
	CropIDs     []uuid.UUID
	DistrictIDs []uuid.UUID
	MandalIDs   []uuid.UUID
	VillageIDs  []uuid.UUID
	StageCodes  []string // current stage of an active season
	Plan        *string  // free | premium; nil = any
}

// Village with its mandal and district. Provider: geo.
type Village struct {
	ID             uuid.UUID
	Name           string
	NameTe         *string
	MandalID       uuid.UUID
	MandalName     string
	MandalNameTe   *string
	DistrictID     uuid.UUID
	DistrictName   string
	DistrictNameTe *string
}

// Coverage is one FA allocation that covers a village. Provider: geo.
type Coverage struct {
	FAID   uuid.UUID
	Level  string // village | mandal | district
	IsLead bool
}

// Advice is one approved (or since superseded) advisory rule: issue -> salt,
// with the Shanmukha product if one maps to the salt (FA-09). SKUID and
// ProductName are nil when it is salt only.
// Provider: masters.
type Advice struct {
	RuleID        uuid.UUID
	RuleVersion   int32
	RuleStatus    string // approved (live) | superseded
	IssueID       uuid.UUID
	SaltID        uuid.UUID
	SaltName      string
	SaltNameTe    *string
	SKUID         *uuid.UUID
	ProductName   *string
	ProductNameTe *string
	Dose          string
	DoseTe        *string
}

// Stage is the crop stage for a given day after sowing. Provider: masters.
type Stage struct {
	ID       uuid.UUID
	CropID   uuid.UUID
	Code     string
	Name     string
	NameTe   string
	Seq      int32
	StartDay int32
	EndDay   int32
}

// PlannedVisit is the next planned FA visit for a farmer. Provider: visits.
type PlannedVisit struct {
	VisitID     uuid.UUID
	FAID        uuid.UUID
	PlotID      uuid.UUID
	SeasonID    uuid.UUID
	PlannedFor  time.Time // date, UTC midnight
	PlannedSlot string    // morning | afternoon | any
	Purpose     *string
}

// VisitAdvice is what a logged visit found and advised, for the farmer's
// notice and SMS. Provider: visits.
type VisitAdvice struct {
	VisitID   uuid.UUID
	FarmerID  uuid.UUID
	FAID      uuid.UUID
	VisitedAt time.Time
	Items     []AdviceItem
}

// AdviceItem is one issue found on a visit with the advice given.
type AdviceItem struct {
	IssueName     string
	IssueNameTe   string
	Severity      string // low | moderate | high
	SaltName      string
	SaltNameTe    *string
	ProductName   *string // nil = salt only
	ProductNameTe *string
	Dose          *string
	DoseTe        *string
}
