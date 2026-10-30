package httpx

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	middleware "github.com/oapi-codegen/nethttp-middleware"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
)

func init() {
	// Validate "format: uuid" (kin-openapi does not by default). Messages stay
	// short because validationError uses SchemaError.Reason, not Error().
	openapi3.DefineStringFormatCallback("uuid", func(s string) error {
		if len(s) != 36 {
			return errors.New("must be a UUID")
		}
		if _, err := uuid.Parse(s); err != nil {
			return errors.New("must be a UUID")
		}
		return nil
	})
}

// MountSpec mounts a module's routes behind kin-openapi request validation for
// that module's spec. loadSpec is the generated GetSwagger; routes registers
// the generated handler on the router it is given (a chi group carrying the
// validator). It panics if the spec cannot be loaded: that is a build bug.
func MountSpec(r chi.Router, loadSpec func() (*openapi3.T, error), routes func(r chi.Router)) {
	spec, err := loadSpec()
	if err != nil {
		panic(fmt.Sprintf("httpx: load spec: %v", err))
	}
	r.Group(func(g chi.Router) {
		g.Use(Validator(spec))
		routes(g)
	})
}

// Validator returns request-validation middleware for spec. Authentication is
// not validated here (the surface guard owns it), servers are ignored, and
// failures are written in the shared error shape.
func Validator(spec *openapi3.T) func(http.Handler) http.Handler {
	return middleware.OapiRequestValidatorWithOptions(spec, &middleware.Options{
		Options: openapi3filter.Options{
			AuthenticationFunc: openapi3filter.NoopAuthenticationFunc,
		},
		DoNotValidateServers:  true,
		SilenceServersWarning: true,
		ErrorHandlerWithOpts: func(_ context.Context, err error, w http.ResponseWriter, r *http.Request, opts middleware.ErrorHandlerOpts) {
			WriteError(w, r, validationError(err, opts.StatusCode))
		},
	})
}

// validationError converts kin-openapi errors to apperr.
func validationError(err error, status int) error {
	if tl, ok := tooLarge(err); ok {
		return tl
	}
	if status == http.StatusNotFound {
		return apperr.NotFound("route")
	}
	var reqErr *openapi3filter.RequestError
	if errors.As(err, &reqErr) {
		field, reason := "body", reqErr.Reason
		if reqErr.Parameter != nil {
			field = reqErr.Parameter.Name
		}
		var schemaErr *openapi3.SchemaError
		if errors.As(reqErr.Err, &schemaErr) {
			if ptr := schemaErr.JSONPointer(); len(ptr) > 0 && reqErr.Parameter == nil {
				field = strings.Join(ptr, ".")
			}
			reason = schemaErr.Reason
		} else if reason == "" && reqErr.Err != nil {
			reason = reqErr.Err.Error()
		}
		if reason == "" {
			reason = "is invalid"
		}
		return apperr.Validation(field, reason)
	}
	var secErr *openapi3filter.SecurityRequirementsError
	if errors.As(err, &secErr) {
		return apperr.Unauthorized("")
	}
	if status >= 500 {
		return fmt.Errorf("request validation: %w", err)
	}
	return apperr.BadRequest("invalid_request", err.Error())
}
