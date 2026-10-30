// Package identity signs people in and keeps track of who they are:
//
//   - farmers: phone + 6-digit SMS OTP (/v1/auth/otp/*); the farmer record is
//     found or created through the farmers port in the same transaction
//   - field assistants: HO-issued login ID + password (/v1/auth/fa/login);
//     the 4-digit offline PIN lives on the phone, we only return its policy
//   - HO users: email + password + TOTP (/v1/auth/ho/*), four fixed roles and
//     an optional district scope
//
// It owns sessions (refresh-token rotation with reuse detection and a short
// retry grace), the device registry (heartbeat, remote wipe via revocation),
// HO management of FA logins (/v1/admin/field-assistants, area scoped) and HO
// users (/v1/admin/ho-users), the consent OTP the FA app uses at enrolment
// (/v1/fa/consent-otp/*), the surface guard's revocation check
// (CheckPrincipal) and the provider methods in provider.go (CONVENTIONS
// section 5).
//
// Files: service_farmer.go, service_fa_auth.go, service_ho_auth.go (sign-in),
// otp.go (OTP challenges), service_consent.go, service_sessions.go (refresh,
// logout), service_guard.go, service_devices.go, service_admin_*.go,
// service_scope.go (HO area scope), totp_seal.go, jobs.go (maintenance),
// handler*.go (DTO mapping only).
package identity

import (
	"github.com/go-chi/chi/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
)

// Module is the identity module.
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
// contracts/openapi/identity.yaml.
func (m *Module) Mount(r chi.Router) {
	h := NewStrictHandlerWithOptions(m.handler, nil, StrictHTTPServerOptions{
		RequestErrorHandlerFunc:  httpx.RequestErrorHandler,
		ResponseErrorHandlerFunc: httpx.ResponseErrorHandler,
	})
	httpx.MountSpec(r, GetSwagger, func(r chi.Router) {
		HandlerWithOptions(h, ChiServerOptions{BaseRouter: r, ErrorHandlerFunc: httpx.RequestErrorHandler})
	})
}

// RegisterWorkers adds the maintenance worker (scheduled by PeriodicJobs).
func (m *Module) RegisterWorkers(w *river.Workers) {
	river.AddWorker(w, &maintenanceWorker{svc: m.svc})
}
