// Package visits owns FA field visits: planned and logged visits, the issues
// found with the salt-first advice given (the exact rule, salt and Shanmukha
// SKU, or salt only), visit photos, and farmers' "call me back" requests.
//
//   - FA writes arrive as sync commands (commands.go, service_log.go):
//     PlanVisit, LogVisit, CancelVisit, CloseCallback.
//   - FA photo upload (service_photos.go), farmer app visits and call-backs
//     (service_farmer.go), HO lists, sampling and counts (service_admin.go).
//   - Snapshot sections `visits` and `callbacks` (snapshot.go).
//   - River job visits.mark_missed (jobs.go); subscriber for
//     farmers.reassigned (events.go); provider methods (provider.go).
package visits

import (
	"github.com/go-chi/chi/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Module is the visits module.
type Module struct {
	svc     *Service
	handler *handler
}

// New builds the module. ports is filled by the integrator after every module
// is constructed; only read it at request time, never here.
func New(deps platform.Deps, ports *Ports) *Module {
	svc := NewService(deps, ports)
	return &Module{svc: svc, handler: &handler{svc: svc}}
}

// Service exposes the service for other modules' ports (wired in internal/app/wire.go).
func (m *Module) Service() *Service { return m.svc }

// Mount registers the module's HTTP routes, validated against
// contracts/openapi/visits.yaml.
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
	reg.Register(CmdPlanVisit, commands.Typed(m.svc.planVisit))
	reg.Register(CmdLogVisit, commands.Typed(m.svc.logVisit))
	reg.Register(CmdCancelVisit, commands.Typed(m.svc.cancelVisit))
	reg.Register(CmdCloseCallback, commands.Typed(m.svc.closeCallback))
}

// RegisterSubscribers subscribes to farmers.reassigned (CONVENTIONS section 7).
func (m *Module) RegisterSubscribers(bus *events.Bus) {
	events.Handle(bus, subscriberReassigned, m.svc.onFarmersReassigned)
}

// RegisterSnapshot registers the `visits` and `callbacks` snapshot sections.
func (m *Module) RegisterSnapshot(reg *territory.Registry) {
	reg.Register(territory.SectionVisits, m.svc.snapshotVisits)
	reg.Register(territory.SectionCallbacks, m.svc.snapshotCallbacks)
}

// RegisterWorkers registers the visits.mark_missed worker. Its schedule is
// MarkMissedPeriodicJob, added to the worker's River config by the integrator.
func (m *Module) RegisterWorkers(w *river.Workers) {
	river.AddWorker(w, &markMissedWorker{svc: m.svc})
}
