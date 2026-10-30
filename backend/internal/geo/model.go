package geo

import (
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Allocation levels (fa_allocations.level).
const (
	LevelVillage  = "village"
	LevelMandal   = "mandal"
	LevelDistrict = "district"
)

// DistrictInfo is one districts row.
type DistrictInfo struct {
	ID        uuid.UUID
	Name      string
	NameTe    *string
	LGDCode   *string
	State     string
	CreatedAt time.Time
}

// MandalInfo is one mandals row with its district's names.
type MandalInfo struct {
	ID             uuid.UUID
	DistrictID     uuid.UUID
	DistrictName   string
	DistrictNameTe *string
	Name           string
	NameTe         *string
	LGDCode        *string
	CreatedAt      time.Time
}

// VillageInfo is a village with its mandal and district. It is JSON-tagged
// because it is also the FA snapshot's "villages" section.
type VillageInfo struct {
	ID             uuid.UUID `json:"id"`
	Name           string    `json:"name"`
	NameTe         *string   `json:"name_te"`
	LGDCode        *string   `json:"lgd_code"`
	Lat            *float64  `json:"lat"`
	Lng            *float64  `json:"lng"`
	MandalID       uuid.UUID `json:"mandal_id"`
	MandalName     string    `json:"mandal_name"`
	MandalNameTe   *string   `json:"mandal_name_te"`
	DistrictID     uuid.UUID `json:"district_id"`
	DistrictName   string    `json:"district_name"`
	DistrictNameTe *string   `json:"district_name_te"`
	CreatedAt      time.Time `json:"created_at"`
}

// Hierarchy is the district -> mandal hierarchy with village counts. JSON-tagged
// because it is cached in Redis.
type Hierarchy struct {
	Districts []HierarchyDistrict `json:"districts"`
}

// HierarchyDistrict is one district in the tree.
type HierarchyDistrict struct {
	ID           uuid.UUID         `json:"id"`
	Name         string            `json:"name"`
	NameTe       *string           `json:"name_te"`
	LGDCode      *string           `json:"lgd_code"`
	VillageCount int               `json:"village_count"`
	Mandals      []HierarchyMandal `json:"mandals"`
}

// HierarchyMandal is one mandal in the tree.
type HierarchyMandal struct {
	ID           uuid.UUID `json:"id"`
	Name         string    `json:"name"`
	NameTe       *string   `json:"name_te"`
	LGDCode      *string   `json:"lgd_code"`
	VillageCount int       `json:"village_count"`
}

// DistrictFields creates or edits a district. Nil fields are not set/changed.
type DistrictFields struct {
	Name    *string
	NameTe  *string
	LGDCode *string
	State   *string
}

// MandalFields creates or edits a mandal. DistrictID is used on create only.
type MandalFields struct {
	DistrictID uuid.UUID
	Name       *string
	NameTe     *string
	LGDCode    *string
}

// VillageFields creates or edits a village. MandalID is used on create only;
// Lat and Lng go together.
type VillageFields struct {
	MandalID uuid.UUID
	Name     *string
	NameTe   *string
	LGDCode  *string
	Lat      *float64
	Lng      *float64
}

// VillageFilter narrows village lists and searches. Q is matched against
// name and name_te; nil fields are not filtered on.
type VillageFilter struct {
	Q          *string
	MandalID   *uuid.UUID
	DistrictID *uuid.UUID
}

// ImportResult counts what a CSV import did.
type ImportResult struct {
	Rows             int
	Created          int
	Updated          int
	Unchanged        int
	DistrictsCreated int
	MandalsCreated   int
}

// FAAllocation is an FA's allocation to one area with the area resolved.
// AreaID/AreaName describe the allocated area at its Level; Mandal* is nil for
// district-level allocations; FA is nil when identity could not be asked.
type FAAllocation struct {
	ID             uuid.UUID
	FAID           uuid.UUID
	FA             *xmod.FieldAssistant
	Level          string
	AreaID         uuid.UUID
	AreaName       string
	AreaNameTe     *string
	VillageID      *uuid.UUID
	MandalID       *uuid.UUID
	MandalName     *string
	MandalNameTe   *string
	DistrictID     uuid.UUID
	DistrictName   string
	DistrictNameTe *string
	IsLead         bool
	ValidFrom      time.Time
	ValidTo        *time.Time
	CreatedBy      *uuid.UUID
	CreatedAt      time.Time
}

// AllocationFilter narrows ListAllocations. Nil fields are not filtered on.
type AllocationFilter struct {
	FAID         *uuid.UUID
	DistrictID   *uuid.UUID // allocations at or below the district
	MandalID     *uuid.UUID // allocations at or below the mandal
	VillageID    *uuid.UUID // village-level allocations of the village
	IncludeEnded bool
}

// NewAllocation is the input of CreateAllocation.
type NewAllocation struct {
	FAID   uuid.UUID
	Level  string
	AreaID uuid.UUID
	IsLead bool
}

// HandoverOutcome is what Handover moved.
type HandoverOutcome struct {
	FromFAID           uuid.UUID
	ToFAID             uuid.UUID
	EndedIDs           []uuid.UUID    // from-FA allocations ended
	Allocations        []FAAllocation // to-FA allocations for the moved areas (new or kept)
	AffectedVillageIDs []uuid.UUID    // every village the moved areas cover
}
