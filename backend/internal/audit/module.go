// Package audit is the HO portal's read side of the append-only audit log:
// search (GET /v1/admin/audit) and the full history of one record
// (GET /v1/admin/audit/chain/{entity_type}/{entity_id}).
//
// Writes do not live here: every module records its own events with
// platform/audit.Record inside its transaction.
//
// This is the REFERENCE MODULE. Its layout is the pattern for every module:
//
//	module.go   Module, New, Mount (+ Register* hooks when needed)
//	ports.go    interfaces this module needs from other modules
//	model.go    domain types returned by the service
//	service.go  business rules; no HTTP types
//	handler.go  implements StrictServerInterface; DTO <-> domain only
//	queries/    sqlc SQL -> store/ (generated)
//	api.gen.go  oapi-codegen output from contracts/openapi/audit.yaml (generated)
package audit

import (
	"github.com/go-chi/chi/v5"

	"github.com/sapionic/orbit/backend/internal/audit/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
)

// Module is the audit module.
type Module struct {
	svc     *Service
	handler *handler
}

// New builds the module. ports is filled by the integrator after every
// module is constructed; do not read it here (cycles between modules are
// allowed because ports are only used at request time).
func New(deps platform.Deps, ports *Ports) *Module {
	svc := NewService(store.New(deps.Pool), ports)
	return &Module{svc: svc, handler: &handler{svc: svc}}
}

// Service exposes the service so the integrator can pass it to other
// modules' ports. Audit provides no ports today.
func (m *Module) Service() *Service { return m.svc }

// Mount registers the module's HTTP routes, validated against its spec.
func (m *Module) Mount(r chi.Router) {
	h := NewStrictHandlerWithOptions(m.handler, nil, StrictHTTPServerOptions{
		RequestErrorHandlerFunc:  httpx.RequestErrorHandler,
		ResponseErrorHandlerFunc: httpx.ResponseErrorHandler,
	})
	httpx.MountSpec(r, GetSwagger, func(r chi.Router) {
		HandlerWithOptions(h, ChiServerOptions{BaseRouter: r, ErrorHandlerFunc: httpx.RequestErrorHandler})
	})
}
