// Package masters holds the reference data the apps run on (ADM-08): crops and
// their stage calendars, issues (pest, disease, deficiency), salts, Shanmukha
// SKUs, versioned advisory rules (issue -> salt -> optional SKU, maker-checker)
// and dealers.
//
//	service.go          auth, transactions, version bump + masters.published
//	service_crops.go    crops, stage calendars, GetStagesForDay, farmer crop list
//	service_catalog.go  salts, SKUs (MRP cap), issues
//	service_rules.go    advisory rule drafts and the approval workflow
//	service_dealers.go  dealers, stocked SKUs, nearest-first search
//	service_advice.go   RuleForVisit, ProductTerms, the FA snapshot section, caches
//	handler*.go         generated strict server <-> service
//
// Every change the FA app can see bumps master_versions('all') and publishes
// masters.published in the same transaction; caches are keyed by that version.
// Rows other records point to are deactivated, never deleted.
package masters

import (
	"github.com/go-chi/chi/v5"

	"github.com/sapionic/orbit/backend/internal/masters/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Module is the masters module.
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
// contracts/openapi/masters.yaml.
func (m *Module) Mount(r chi.Router) {
	h := NewStrictHandlerWithOptions(m.handler, nil, StrictHTTPServerOptions{
		RequestErrorHandlerFunc:  httpx.RequestErrorHandler,
		ResponseErrorHandlerFunc: httpx.ResponseErrorHandler,
	})
	httpx.MountSpec(r, GetSwagger, func(r chi.Router) {
		HandlerWithOptions(h, ChiServerOptions{BaseRouter: r, ErrorHandlerFunc: httpx.RequestErrorHandler})
	})
}

// RegisterSubscribers clears the masters caches when a new version is published.
func (m *Module) RegisterSubscribers(bus *events.Bus) {
	events.Handle(bus, "masters.cache_invalidation", m.svc.onPublished)
}

// RegisterSnapshot provides the "masters" section of the FA snapshot.
func (m *Module) RegisterSnapshot(reg *territory.Registry) {
	reg.Register(territory.SectionMasters, m.svc.SnapshotSection)
}
