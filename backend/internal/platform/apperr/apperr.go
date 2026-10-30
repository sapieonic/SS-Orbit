// Package apperr defines the typed errors services return. httpx maps them to
// HTTP status codes and the shared error JSON shape:
//
//	{"error": {"code": "...", "message": "...", "details": {...}}}
//
// Services return these (never HTTP types); anything else is treated as an
// internal error (500, logged, message hidden from the client).
package apperr

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"time"
)

// Kind classifies an error; it decides the HTTP status.
type Kind string

const (
	KindValidation   Kind = "validation"   // 400
	KindUnauthorized Kind = "unauthorized" // 401
	KindForbidden    Kind = "forbidden"    // 403
	KindNotFound     Kind = "not_found"    // 404
	KindConflict     Kind = "conflict"     // 409
	KindTooLarge     Kind = "too_large"    // 413
	KindRateLimited  Kind = "rate_limited" // 429
	KindUnavailable  Kind = "unavailable"  // 503
)

// Error is a client-facing error. Code is a stable machine-readable string the
// apps switch on; Message is human-readable English; Details is optional
// structured context (field names, current version, ...).
type Error struct {
	Kind    Kind
	Code    string
	Message string
	Details map[string]any
	// RetryAfter is set for KindRateLimited; httpx sends it as Retry-After.
	RetryAfter time.Duration
	// Err is an optional wrapped cause (logged, never sent to clients).
	Err error
}

func (e *Error) Error() string {
	msg := string(e.Kind) + ": " + e.Code
	if e.Message != "" {
		msg += ": " + e.Message
	}
	if e.Err != nil {
		msg += ": " + e.Err.Error()
	}
	return msg
}

func (e *Error) Unwrap() error { return e.Err }

// WithMessage returns a copy of e with Message replaced.
func (e *Error) WithMessage(msg string) *Error {
	c := *e
	c.Message = msg
	return &c
}

// WithDetail returns a copy of e with details[key] = value added.
func (e *Error) WithDetail(key string, value any) *Error {
	c := *e
	c.Details = make(map[string]any, len(e.Details)+1)
	for k, v := range e.Details {
		c.Details[k] = v
	}
	c.Details[key] = value
	return &c
}

// Wrap returns a copy of e with cause attached (for logs only).
func (e *Error) Wrap(cause error) *Error {
	c := *e
	c.Err = cause
	return &c
}

// NotFound reports a missing record. entity is a human noun ("farmer", "plot").
// Code: "not_found".
func NotFound(entity string) *Error {
	return &Error{Kind: KindNotFound, Code: "not_found", Message: entity + " not found"}
}

// Validation reports one invalid input field. Code: "validation_failed",
// details: {"fields": {field: msg}}.
func Validation(field, msg string) *Error {
	return &Error{
		Kind:    KindValidation,
		Code:    "validation_failed",
		Message: field + ": " + msg,
		Details: map[string]any{"fields": map[string]string{field: msg}},
	}
}

// ValidationFields reports several invalid fields at once.
func ValidationFields(fields map[string]string) *Error {
	return &Error{
		Kind:    KindValidation,
		Code:    "validation_failed",
		Message: "request has invalid fields",
		Details: map[string]any{"fields": fields},
	}
}

// BadRequest is a 400 with a specific code (e.g. "invalid_cursor", "otp_expired").
func BadRequest(code, msg string) *Error {
	return &Error{Kind: KindValidation, Code: code, Message: msg}
}

// Conflict reports a state conflict (version mismatch, duplicate, wrong
// status). code is specific, e.g. "version_mismatch", "phone_taken";
// an empty code becomes "conflict".
func Conflict(code string, details map[string]any) *Error {
	if code == "" {
		code = "conflict"
	}
	return &Error{Kind: KindConflict, Code: code, Message: "conflict: " + code, Details: details}
}

// Forbidden: authenticated but not allowed. Code: "forbidden".
func Forbidden(msg string) *Error {
	if msg == "" {
		msg = "you are not allowed to do this"
	}
	return &Error{Kind: KindForbidden, Code: "forbidden", Message: msg}
}

// Unauthorized: missing, invalid or expired credentials. Code: "unauthorized".
func Unauthorized(msg string) *Error {
	if msg == "" {
		msg = "authentication required"
	}
	return &Error{Kind: KindUnauthorized, Code: "unauthorized", Message: msg}
}

// RateLimited: too many attempts. Code: "rate_limited". retryAfter may be 0.
func RateLimited(retryAfter time.Duration) *Error {
	return &Error{Kind: KindRateLimited, Code: "rate_limited", Message: "too many requests, try again later", RetryAfter: retryAfter}
}

// TooLarge is 413 payload_too_large: the request body is over limit bytes.
func TooLarge(limit int64) *Error {
	return &Error{Kind: KindTooLarge, Code: "payload_too_large", Message: "the request body is too large",
		Details: map[string]any{"limit_bytes": limit}}
}

// Unavailable: a dependency is down and the request cannot be served. Code: "unavailable".
func Unavailable(msg string) *Error {
	return &Error{Kind: KindUnavailable, Code: "unavailable", Message: msg}
}

// As returns the *Error in err's chain, if any.
func As(err error) (*Error, bool) {
	var e *Error
	if errors.As(err, &e) {
		return e, true
	}
	return nil, false
}

// Is reports whether err is an *Error of the given kind.
func Is(err error, k Kind) bool {
	e, ok := As(err)
	return ok && e.Kind == k
}

// HTTPStatus maps err to an HTTP status code (500 for non-apperr errors).
func HTTPStatus(err error) int {
	e, ok := As(err)
	if !ok {
		return http.StatusInternalServerError
	}
	switch e.Kind {
	case KindValidation:
		return http.StatusBadRequest
	case KindUnauthorized:
		return http.StatusUnauthorized
	case KindForbidden:
		return http.StatusForbidden
	case KindNotFound:
		return http.StatusNotFound
	case KindConflict:
		return http.StatusConflict
	case KindTooLarge:
		return http.StatusRequestEntityTooLarge
	case KindRateLimited:
		return http.StatusTooManyRequests
	case KindUnavailable:
		return http.StatusServiceUnavailable
	default:
		return http.StatusInternalServerError
	}
}

// Body is the JSON error body: {"error": {...}}.
type Body struct {
	Error BodyError `json:"error"`
}

// BodyError is the inner error object.
type BodyError struct {
	Code    string         `json:"code"`
	Message string         `json:"message"`
	Details map[string]any `json:"details,omitempty"`
}

// ToBody converts err into the response body. Non-apperr errors become a
// generic "internal" error with no detail leaked.
func ToBody(err error) Body {
	e, ok := As(err)
	if !ok {
		return Body{Error: BodyError{Code: "internal", Message: "internal error"}}
	}
	return Body{Error: BodyError{Code: e.Code, Message: e.Message, Details: e.Details}}
}

// RetryAfterHeader returns the Retry-After header value for err, or "".
func RetryAfterHeader(err error) string {
	e, ok := As(err)
	if !ok || e.Kind != KindRateLimited || e.RetryAfter <= 0 {
		return ""
	}
	secs := int((e.RetryAfter + time.Second - 1) / time.Second)
	return strconv.Itoa(secs)
}

// Internalf wraps an unexpected error with context. It is NOT an *Error, so it
// maps to 500; use it to annotate infrastructure failures.
func Internalf(format string, args ...any) error {
	return fmt.Errorf(format, args...)
}
