// Package geo owns the district -> mandal -> village hierarchy (LGD codes,
// Telugu names) and FA allocations to areas.
//
//   - HO masters and CSV import: /v1/admin/geo/... (service_masters.go,
//     service_villages.go, service_import.go)
//   - Village picker for farmer self sign-up: /v1/farmer/villages, /v1/farmer/geo/tree
//   - FA allocations and territory hand-over: /v1/admin/allocations (service_allocations.go)
//   - Provider methods for other modules and the "villages" snapshot section (provider.go)
//
// Every allocation change, and every village edit inside an FA's area, bumps
// that FA's territory version in the same transaction.
package geo

import (
	"github.com/go-chi/chi/v5"

	"github.com/sapionic/orbit/backend/internal/geo/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Module is the geo module.
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
// contracts/openapi/geo.yaml.
func (m *Module) Mount(r chi.Router) {
	h := NewStrictHandlerWithOptions(m.handler, nil, StrictHTTPServerOptions{
		RequestErrorHandlerFunc:  httpx.RequestErrorHandler,
		ResponseErrorHandlerFunc: httpx.ResponseErrorHandler,
	})
	httpx.MountSpec(r, GetSwagger, func(r chi.Router) {
		HandlerWithOptions(h, ChiServerOptions{BaseRouter: r, ErrorHandlerFunc: httpx.RequestErrorHandler})
	})
}

// RegisterSnapshot provides the FA snapshot's "villages" section.
func (m *Module) RegisterSnapshot(reg *territory.Registry) {
	reg.Register(territory.SectionVillages, m.svc.snapshotVillages)
}
