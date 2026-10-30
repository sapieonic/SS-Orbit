// Package httpx is the HTTP layer shared by every module: the chi router with
// its middleware stack (request ID, structured logging, panic recovery, CORS,
// surface guard), JSON helpers, the single error writer, and MountSpec, which
// mounts a module's oapi-codegen strict handler behind kin-openapi request
// validation for that module's spec.
//
// Module Mount pattern (see internal/audit/module.go):
//
//	func (m *Module) Mount(r chi.Router) {
//		h := NewStrictHandlerWithOptions(m.handler, nil, StrictHTTPServerOptions{
//			RequestErrorHandlerFunc:  httpx.RequestErrorHandler,
//			ResponseErrorHandlerFunc: httpx.ResponseErrorHandler,
//		})
//		httpx.MountSpec(r, GetSwagger, func(r chi.Router) {
//			HandlerWithOptions(h, ChiServerOptions{BaseRouter: r, ErrorHandlerFunc: httpx.RequestErrorHandler})
//		})
//	}
package httpx

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

// WriteJSON writes v as JSON with status.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// WriteError writes err in the shared error shape with the status from
// apperr.HTTPStatus. Non-apperr errors are logged and sent as a generic 500.
func WriteError(w http.ResponseWriter, r *http.Request, err error) {
	status := apperr.HTTPStatus(err)
	log := logx.From(r.Context())
	if status >= 500 {
		log.ErrorContext(r.Context(), "request failed", "err", err, "status", status)
	} else {
		log.DebugContext(r.Context(), "request rejected", "err", err, "status", status)
	}
	if ra := apperr.RetryAfterHeader(err); ra != "" {
		w.Header().Set("Retry-After", ra)
	}
	WriteJSON(w, status, apperr.ToBody(err))
}

// RequestErrorHandler is for oapi-codegen's RequestErrorHandlerFunc (strict
// server) and ErrorHandlerFunc (chi wrapper): the request could not be bound
// (bad path/query param, malformed JSON): 400 "invalid_request", or 413 when
// the body was over the BodyLimit cap.
func RequestErrorHandler(w http.ResponseWriter, r *http.Request, err error) {
	if tl, ok := tooLarge(err); ok {
		WriteError(w, r, tl)
		return
	}
	var ae *apperr.Error
	if errors.As(err, &ae) {
		WriteError(w, r, ae)
		return
	}
	WriteError(w, r, apperr.BadRequest("invalid_request", err.Error()))
}

// ResponseErrorHandler is for oapi-codegen's ResponseErrorHandlerFunc: the
// error a strict handler method returned. Handlers return service errors
// (apperr) as-is and this writes them.
func ResponseErrorHandler(w http.ResponseWriter, r *http.Request, err error) {
	WriteError(w, r, err)
}

func notFound(w http.ResponseWriter, r *http.Request) {
	WriteError(w, r, apperr.NotFound("route"))
}

func methodNotAllowed(w http.ResponseWriter, r *http.Request) {
	WriteJSON(w, http.StatusMethodNotAllowed, apperr.Body{Error: apperr.BodyError{
		Code: "method_not_allowed", Message: r.Method + " is not allowed here",
	}})
}

// discardLogger is used when no logger is configured.
var discardLogger = slog.New(slog.DiscardHandler)
