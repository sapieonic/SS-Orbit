// Package sync is FA offline sync: snapshot down, commands up.
//
//   - GET /v1/fa/sync/snapshot: everything the FA app keeps offline, built from
//     the section providers other modules register on platform/territory,
//     gzipped, cached in Redis by version, with an ETag.
//   - GET /v1/fa/sync/status: the versions only, for the app to poll.
//   - POST /v1/fa/sync/commands: what the FA did offline, as idempotent
//     commands dispatched to the owning modules via platform/commands. Each
//     command is stored once in sync_commands; repeated server failures are
//     counted in sync_command_failures (the two tables this module owns).
//   - GET /v1/admin/sync/commands: HO review of stored commands.
//   - sync.retention (daily): deletes old sync_commands (jobs.go).
//
// The package is named sync; import the standard library as gosync "sync".
package sync

import (
	"github.com/go-chi/chi/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
	"github.com/sapionic/orbit/backend/internal/sync/store"
)

// Module is the sync module.
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

// Service exposes the service. Sync provides no ports to other modules.
func (m *Module) Service() *Service { return m.svc }

// Mount registers the module's HTTP routes, validated against
// contracts/openapi/sync.yaml. The snapshot route returns pre-encoded gzip
// bytes through a custom strict response (snapshotResponse), so it stays on
// the generated handler and behind the same request validation.
func (m *Module) Mount(r chi.Router) {
	h := NewStrictHandlerWithOptions(m.handler, nil, StrictHTTPServerOptions{
		RequestErrorHandlerFunc:  httpx.RequestErrorHandler,
		ResponseErrorHandlerFunc: httpx.ResponseErrorHandler,
	})
	httpx.MountSpec(r, GetSwagger, func(r chi.Router) {
		HandlerWithOptions(h, ChiServerOptions{BaseRouter: r, ErrorHandlerFunc: httpx.RequestErrorHandler})
	})
}

// RegisterSubscribers subscribes to domain events (CONVENTIONS section 7).
func (m *Module) RegisterSubscribers(bus *events.Bus) {
	events.Handle(bus, "sync.drop_snapshot_cache", m.svc.onDeviceRevoked)
}

// RegisterWorkers registers the sync.retention worker. Its schedule is
// PeriodicJobs, added to the worker's River config by the integrator.
func (m *Module) RegisterWorkers(w *river.Workers) {
	river.AddWorker(w, &retentionWorker{svc: m.svc})
}
