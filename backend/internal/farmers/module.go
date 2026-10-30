// Package farmers owns farmers, consents, plots and crop seasons: the
// farmer -> plot -> season spine every farm record hangs off (SYS-03, enforced
// with composite foreign keys in the schema).
//
//   - Farmer app (/v1/farmer): home, completing a self sign-up, profile,
//     consents, adding plots and starting/closing seasons.
//   - HO portal (/v1/admin): farmer list, Farmer 360, edit, deactivate,
//     reassign to another FA, season rollover.
//   - FA app: offline sync commands EnrolFarmer, SavePlot, StartSeason and
//     UpdateFarmer and RecordConsent (commands*.go), and the territory resolver plus the farmers,
//     plots and seasons snapshot sections (territory.go).
//   - Other modules: FindOrCreateByPhone, GetFarmerSummaries and
//     FarmerIDsForTargeting (service_provider.go).
package farmers

import (
	"github.com/go-chi/chi/v5"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Module is the farmers module.
type Module struct {
	svc     *Service
	handler *handler
}

// New builds the module. ports is filled by the integrator after every module
// is constructed; only read it at request time, never here.
func New(deps platform.Deps, ports *Ports) *Module {
	svc := NewService(deps, store.New(deps.Pool), ports)
	return &Module{svc: svc, handler: &handler{svc: svc}}
}

// Service exposes the service for other modules' ports (wired in internal/app/wire.go).
func (m *Module) Service() *Service { return m.svc }

// Mount registers the module's HTTP routes, validated against
// contracts/openapi/farmers.yaml.
func (m *Module) Mount(r chi.Router) {
	h := NewStrictHandlerWithOptions(m.handler, nil, StrictHTTPServerOptions{
		RequestErrorHandlerFunc:  httpx.RequestErrorHandler,
		ResponseErrorHandlerFunc: httpx.ResponseErrorHandler,
	})
	httpx.MountSpec(r, GetSwagger, func(r chi.Router) {
		HandlerWithOptions(h, ChiServerOptions{BaseRouter: r, ErrorHandlerFunc: httpx.RequestErrorHandler})
	})
}

// RegisterCommands registers the FA sync command handlers (CONVENTIONS section 6).
func (m *Module) RegisterCommands(reg *commands.Registry) {
	reg.Register("EnrolFarmer", commands.Typed(m.svc.EnrolFarmer))
	reg.Register("SavePlot", commands.Typed(m.svc.SavePlot))
	reg.Register("StartSeason", commands.Typed(m.svc.StartSeason))
	reg.Register("UpdateFarmer", commands.Typed(m.svc.UpdateFarmer))
	reg.Register("RecordConsent", commands.Typed(m.svc.RecordConsent))
}

// RegisterSnapshot sets the territory resolver and the farmers, plots and
// seasons snapshot sections (CONVENTIONS section 8).
func (m *Module) RegisterSnapshot(reg *territory.Registry) {
	reg.SetResolver(m.svc.ResolveTerritory)
	reg.Register(territory.SectionFarmers, m.svc.snapshotFarmers)
	reg.Register(territory.SectionPlots, m.svc.snapshotPlots)
	reg.Register(territory.SectionSeasons, m.svc.snapshotSeasons)
}
