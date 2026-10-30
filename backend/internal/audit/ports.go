package audit

// Ports are the interfaces this module needs from other modules
// (CONVENTIONS section 5). Audit reads only its own table, so it needs none.
//
// A module with dependencies declares consumer-side interfaces here, e.g.
//
//	type FarmerDirectory interface {
//		GetFarmerSummaries(ctx context.Context, ids []uuid.UUID) ([]farmers.FarmerSummary, error)
//	}
//
//	type Ports struct {
//		Farmers FarmerDirectory
//	}
type Ports struct{}
