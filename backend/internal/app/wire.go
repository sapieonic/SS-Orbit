package app

import (
	"github.com/sapionic/orbit/backend/internal/audit"
	"github.com/sapionic/orbit/backend/internal/farmers"
	"github.com/sapionic/orbit/backend/internal/geo"
	"github.com/sapionic/orbit/backend/internal/identity"
	"github.com/sapionic/orbit/backend/internal/masters"
	"github.com/sapionic/orbit/backend/internal/messaging"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/sync"
	"github.com/sapionic/orbit/backend/internal/visits"
)

// wire.go is the ONE place that knows every module. Only the integrator edits
// it. Module agents never need to: hooks (Mount, RegisterWorkers,
// RegisterCommands, RegisterSubscribers, RegisterSnapshot) are discovered by
// interface assertion in hooks.go.

// Modules holds every constructed module.
type Modules struct {
	Identity  *identity.Module
	Geo       *geo.Module
	Farmers   *farmers.Module
	Masters   *masters.Module
	Visits    *visits.Module
	Messaging *messaging.Module
	Sync      *sync.Module
	Audit     *audit.Module

	ports *allPorts
}

// allPorts owns every module's Ports. Modules keep a pointer to their entry and
// read it only at request time, so ports can be connected after all modules
// exist, including cycles (identity <-> farmers, farmers <-> visits).
type allPorts struct {
	Identity  identity.Ports
	Geo       geo.Ports
	Farmers   farmers.Ports
	Masters   masters.Ports
	Visits    visits.Ports
	Messaging messaging.Ports
	Sync      sync.Ports
	Audit     audit.Ports
}

// NewModules constructs every module and connects their ports.
func NewModules(d platform.Deps) *Modules {
	p := &allPorts{}
	m := &Modules{
		Identity:  identity.New(d, &p.Identity),
		Geo:       geo.New(d, &p.Geo),
		Farmers:   farmers.New(d, &p.Farmers),
		Masters:   masters.New(d, &p.Masters),
		Visits:    visits.New(d, &p.Visits),
		Messaging: messaging.New(d, &p.Messaging),
		Sync:      sync.New(d, &p.Sync),
		Audit:     audit.New(d, &p.Audit),
		ports:     p,
	}

	// ---- Ports (CONVENTIONS section 5): each consumer field gets a provider's *Service. ----
	p.Identity.Farmers = m.Farmers.Service() // FindOrCreateByPhone, GetFarmerSummaries
	p.Identity.Geo = m.Geo.Service()         // DistrictIDsForFAs (HO area scope)
	p.Geo.Identity = m.Identity.Service()    // GetFieldAssistants
	p.Farmers.Identity = m.Identity.Service()
	p.Farmers.Geo = m.Geo.Service() // GetVillages, FAsCoveringVillage, VillageIDsForFA
	p.Farmers.Masters = m.Masters.Service()
	p.Farmers.Visits = m.Visits.Service() // NextPlannedVisit
	p.Masters.Geo = m.Geo.Service()
	p.Visits.Farmers = m.Farmers.Service()
	p.Visits.Masters = m.Masters.Service() // RuleForVisit
	p.Visits.Geo = m.Geo.Service()         // GetVillages (visit district)
	p.Visits.Identity = m.Identity.Service()
	p.Visits.Labels = m.Masters.Service() // IssueLabel, StageLabel
	p.Messaging.Farmers = m.Farmers.Service()
	p.Messaging.Geo = m.Geo.Service()
	p.Messaging.Identity = m.Identity.Service() // GetFieldAssistants, PushTokens
	p.Messaging.Visits = m.Visits.Service()     // GetVisitAdvice
	p.Messaging.Masters = m.Masters.Service()   // ProductTerms
	p.Sync.Masters = m.Masters.Service()        // CurrentVersion
	p.Sync.Identity = m.Identity.Service()      // MarkSynced

	return m
}

// all lists every module once, in mount/registration order.
func (m *Modules) all() []namedModule {
	return []namedModule{
		{"identity", m.Identity},
		{"geo", m.Geo},
		{"farmers", m.Farmers},
		{"masters", m.Masters},
		{"visits", m.Visits},
		{"messaging", m.Messaging},
		{"sync", m.Sync},
		{"audit", m.Audit},
	}
}
