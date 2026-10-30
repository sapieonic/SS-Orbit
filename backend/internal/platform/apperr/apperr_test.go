package apperr

import (
	"errors"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestHTTPStatus(t *testing.T) {
	cases := []struct {
		err  error
		want int
	}{
		{NotFound("farmer"), http.StatusNotFound},
		{Validation("phone", "invalid"), http.StatusBadRequest},
		{BadRequest("invalid_cursor", "bad cursor"), http.StatusBadRequest},
		{Conflict("version_mismatch", nil), http.StatusConflict},
		{Forbidden(""), http.StatusForbidden},
		{Unauthorized(""), http.StatusUnauthorized},
		{RateLimited(time.Second), http.StatusTooManyRequests},
		{Unavailable("db down"), http.StatusServiceUnavailable},
		{errors.New("boom"), http.StatusInternalServerError},
		{fmt.Errorf("load plot: %w", NotFound("plot")), http.StatusNotFound},
	}
	for _, c := range cases {
		assert.Equal(t, c.want, HTTPStatus(c.err), c.err.Error())
	}
}

func TestToBody(t *testing.T) {
	b := ToBody(Validation("phone", "must be an Indian mobile"))
	assert.Equal(t, "validation_failed", b.Error.Code)
	assert.Equal(t, map[string]string{"phone": "must be an Indian mobile"}, b.Error.Details["fields"])

	b = ToBody(Conflict("", map[string]any{"current_version": 3}))
	assert.Equal(t, "conflict", b.Error.Code)
	assert.Equal(t, 3, b.Error.Details["current_version"])

	b = ToBody(errors.New("pq: secret internal detail"))
	assert.Equal(t, "internal", b.Error.Code)
	assert.NotContains(t, b.Error.Message, "secret")
}

func TestHelpers(t *testing.T) {
	e := NotFound("plot").WithMessage("plot was archived").WithDetail("plot_id", "x")
	assert.Equal(t, "plot was archived", e.Message)
	assert.Equal(t, "x", e.Details["plot_id"])
	assert.True(t, Is(fmt.Errorf("wrap: %w", e), KindNotFound))

	cause := errors.New("cause")
	assert.ErrorIs(t, Forbidden("").Wrap(cause), cause)

	assert.Equal(t, "2", RetryAfterHeader(RateLimited(1500*time.Millisecond)))
	assert.Equal(t, "", RetryAfterHeader(NotFound("x")))
}
