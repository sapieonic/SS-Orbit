// Package messaging: advisories, the farmer inbox ("My Crop Advisory"), the
// farmer web page for a notice, channel deliveries (SMS, push, WhatsApp stub),
// FA alerts and HO alerts.
//
// Layout:
//
//	service_advisories.go  compose, approve, schedule, cancel (HO)
//	service_fanout.go      advisory fan-out into notices + deliveries (River)
//	service_delivery.go    sending one delivery, retries, signed page links
//	service_inbox.go       farmer inbox and web page
//	service_alerts.go      FA alerts (snapshot, AckAlert, HO notes), HO alerts
//	service_fa_push.go     push of new FA alerts to the FA's devices
//	service_fa_offline.go  periodic fa_offline HO alerts
//	service_products.go    product-mention check for advisories
//	events.go              event subscribers
//	templates.go           every message text (Telugu + English), DLT IDs
//	quiet.go               quiet hours (21:00-07:00 IST)
package messaging

import (
	"github.com/go-chi/chi/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Module is the messaging module.
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
// contracts/openapi/messaging.yaml.
func (m *Module) Mount(r chi.Router) {
	h := NewStrictHandlerWithOptions(m.handler, nil, StrictHTTPServerOptions{
		RequestErrorHandlerFunc:  httpx.RequestErrorHandler,
		ResponseErrorHandlerFunc: httpx.ResponseErrorHandler,
	})
	httpx.MountSpec(r, GetSwagger, func(r chi.Router) {
		HandlerWithOptions(h, ChiServerOptions{BaseRouter: r, ErrorHandlerFunc: httpx.RequestErrorHandler})
	})
}

// RegisterCommands registers the AckAlert sync command.
func (m *Module) RegisterCommands(reg *commands.Registry) { m.registerCommands(reg) }

// RegisterSubscribers subscribes to farmer, visit and callback events (events.go).
func (m *Module) RegisterSubscribers(bus *events.Bus) { m.subscribe(bus) }

// RegisterWorkers adds the advisory fan-out, delivery, FA alert push and
// fa_offline workers (jobs.go). The fa_offline schedule is PeriodicJobs,
// added to the worker's River config by the integrator.
func (m *Module) RegisterWorkers(w *river.Workers) {
	river.AddWorker(w, &advisoryFanoutWorker{svc: m.svc})
	river.AddWorker(w, &deliveryWorker{svc: m.svc})
	river.AddWorker(w, &faAlertPushWorker{svc: m.svc})
	river.AddWorker(w, &faOfflineWorker{svc: m.svc})
}

// RegisterSnapshot provides the FA snapshot's "alerts" section.
func (m *Module) RegisterSnapshot(reg *territory.Registry) {
	reg.Register(territory.SectionAlerts, m.svc.snapshotAlerts)
}
