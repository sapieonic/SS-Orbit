package visits

import (
	"context"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// FarmerDirectory is provided by the farmers module: farmer details, and the
// one FA-authorisation rule (CONVENTIONS section 6). ResolveFarmerForFA
// follows merge aliases, so a farmer_id the FA phone minted for an enrolment
// that merged into an existing farmer resolves to that farmer.
type FarmerDirectory interface {
	GetFarmerSummaries(ctx context.Context, ids []uuid.UUID) ([]xmod.FarmerSummary, error)
	ResolveFarmerForFA(ctx context.Context, faID, farmerID uuid.UUID) (uuid.UUID, error)
}

// AdviceResolver is provided by the masters module: the rule version an FA
// picked offline (approved or since superseded), apperr.NotFound otherwise.
type AdviceResolver interface {
	RuleForVisit(ctx context.Context, ruleID uuid.UUID) (xmod.Advice, error)
}

// FADirectory is provided by the identity module (FA names in lists).
type FADirectory interface {
	GetFieldAssistants(ctx context.Context, ids []uuid.UUID) ([]xmod.FieldAssistant, error)
}

// MasterLabels is provided by the masters module: display names for an issue
// and a crop stage, copied onto the visit at log time. Optional: when nil the
// names are stored empty and the apps fall back to their offline masters.
type MasterLabels interface {
	IssueLabel(ctx context.Context, issueID uuid.UUID) (name, nameTe string, err error)
	StageLabel(ctx context.Context, stageID uuid.UUID) (name, nameTe string, err error)
}

// VillageDirectory is provided by the geo module (GetVillages, CONVENTIONS
// section 5): the farmer's village gives the visit its district, so HO users
// with an area scope see their districts' visits. Optional: when nil, visits
// are stored without a district and only unscoped HO users see them.
type VillageDirectory interface {
	GetVillages(ctx context.Context, ids []uuid.UUID) ([]xmod.Village, error)
}

// Ports are the interfaces this module needs from other modules, declared
// consumer-side with the exact signatures in CONVENTIONS section 5. The
// integrator fills the fields in internal/app/wire.go.
type Ports struct {
	Farmers  FarmerDirectory
	Masters  AdviceResolver
	Identity FADirectory
	Labels   MasterLabels     // optional
	Geo      VillageDirectory // optional
}
