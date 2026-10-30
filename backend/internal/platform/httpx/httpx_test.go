package httpx

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
)

var testTokens = auth.NewTokens("httpx-test-secret-httpx-test-secret", "orbit", 15*time.Minute, nil)

func token(t *testing.T, p auth.Principal) string {
	t.Helper()
	tok, _, err := testTokens.IssueAccess(p)
	require.NoError(t, err)
	return tok
}

func call(h http.Handler, method, path, tok string, body io.Reader) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, body)
	if tok != "" {
		req.Header.Set("Authorization", "Bearer "+tok)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func errCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var b apperr.Body
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &b), rec.Body.String())
	return b.Error.Code
}

// okRoutes answers 200 on a few guarded paths and reads the body.
func okRoutes(r chi.Router) {
	h := func(w http.ResponseWriter, r *http.Request) {
		if _, err := io.ReadAll(r.Body); err != nil {
			RequestErrorHandler(w, r, err)
			return
		}
		w.WriteHeader(http.StatusOK)
	}
	for _, p := range []string{"/v1/fa/me/password", "/v1/fa/visits", "/v1/admin/me", "/v1/admin/me/password",
		"/v1/admin/farmers", "/v1/farmer/home", "/v1/fa/sync/commands", "/v1/auth/refresh"} {
		r.Post(p, h)
		r.Get(p, h)
	}
}

func TestPasswordChangeGate(t *testing.T) {
	r := NewRouter(RouterConfig{Tokens: testTokens})
	okRoutes(r)
	fa := token(t, auth.Principal{Kind: auth.KindFA, ID: uuid.New(), DeviceID: uuid.New(), MustChangePassword: true})
	ho := token(t, auth.Principal{Kind: auth.KindHO, ID: uuid.New(), Role: auth.RoleOps, MustChangePassword: true})

	rec := call(r, http.MethodGet, "/v1/fa/visits", fa, nil)
	assert.Equal(t, http.StatusForbidden, rec.Code)
	assert.Equal(t, "password_change_required", errCode(t, rec))
	assert.Equal(t, http.StatusOK, call(r, http.MethodPost, "/v1/fa/me/password", fa, nil).Code)
	assert.Equal(t, http.StatusOK, call(r, http.MethodPost, "/v1/auth/refresh", fa, nil).Code, "refresh/logout stay open")

	assert.Equal(t, http.StatusForbidden, call(r, http.MethodGet, "/v1/admin/farmers", ho, nil).Code)
	assert.Equal(t, http.StatusOK, call(r, http.MethodGet, "/v1/admin/me", ho, nil).Code)
	assert.Equal(t, http.StatusOK, call(r, http.MethodPost, "/v1/admin/me/password", ho, nil).Code)

	normal := token(t, auth.Principal{Kind: auth.KindFA, ID: uuid.New(), DeviceID: uuid.New()})
	assert.Equal(t, http.StatusOK, call(r, http.MethodGet, "/v1/fa/visits", normal, nil).Code)
}

func TestRevocationChecks(t *testing.T) {
	revokedDev := uuid.New()
	var checked []auth.Kind
	r := NewRouter(RouterConfig{
		Tokens: testTokens,
		DeviceRevoked: func(_ context.Context, id uuid.UUID) (bool, error) {
			return id == revokedDev, nil
		},
		CheckPrincipal: func(_ context.Context, p auth.Principal) error {
			checked = append(checked, p.Kind)
			switch p.Role {
			case auth.RoleFinance:
				return &apperr.Error{Kind: apperr.KindUnauthorized, Code: "session_revoked", Message: "signed out"}
			case auth.RoleAgronomy:
				return errors.New("redis and postgres both down")
			}
			return nil
		},
	})
	okRoutes(r)

	farmer := token(t, auth.Principal{Kind: auth.KindFarmer, ID: uuid.New(), DeviceID: revokedDev})
	rec := call(r, http.MethodGet, "/v1/farmer/home", farmer, nil)
	assert.Equal(t, http.StatusUnauthorized, rec.Code, "farmer tokens get the device check too")
	assert.Equal(t, "device_revoked", errCode(t, rec))

	fa := token(t, auth.Principal{Kind: auth.KindFA, ID: uuid.New(), DeviceID: revokedDev})
	assert.Equal(t, http.StatusUnauthorized, call(r, http.MethodGet, "/v1/fa/visits", fa, nil).Code)

	rec = call(r, http.MethodGet, "/v1/admin/farmers", token(t, auth.Principal{Kind: auth.KindHO, ID: uuid.New(), Role: auth.RoleFinance}), nil)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
	assert.Equal(t, "session_revoked", errCode(t, rec))

	rec = call(r, http.MethodGet, "/v1/admin/farmers", token(t, auth.Principal{Kind: auth.KindHO, ID: uuid.New(), Role: auth.RoleAgronomy}), nil)
	assert.Equal(t, http.StatusServiceUnavailable, rec.Code, "fail closed on infrastructure errors")

	assert.Equal(t, http.StatusOK, call(r, http.MethodGet, "/v1/admin/farmers", token(t, auth.Principal{Kind: auth.KindHO, ID: uuid.New(), Role: auth.RoleOps}), nil).Code)
	assert.Contains(t, checked, auth.KindHO)
}

func TestBodyLimit(t *testing.T) {
	r := NewRouter(RouterConfig{Tokens: testTokens, MaxBodyBytes: 1024,
		BodyLimits: map[string]int64{"/v1/fa/sync/commands": 4096, "/v1/admin/imports/*": 4096}})
	okRoutes(r)
	r.Post("/v1/admin/imports/villages", func(w http.ResponseWriter, r *http.Request) {
		if _, err := io.ReadAll(r.Body); err != nil {
			RequestErrorHandler(w, r, err)
			return
		}
		w.WriteHeader(http.StatusOK)
	})
	fa := token(t, auth.Principal{Kind: auth.KindFA, ID: uuid.New(), DeviceID: uuid.New()})
	ho := token(t, auth.Principal{Kind: auth.KindHO, ID: uuid.New(), Role: auth.RoleAdmin})
	big := bytes.Repeat([]byte("x"), 2000)

	rec := call(r, http.MethodPost, "/v1/fa/visits", fa, bytes.NewReader(big))
	assert.Equal(t, http.StatusRequestEntityTooLarge, rec.Code, "declared length over the default cap")
	assert.Equal(t, "payload_too_large", errCode(t, rec))

	// Unknown length (chunked): refused while reading.
	rec = call(r, http.MethodPost, "/v1/fa/visits", fa, io.MultiReader(bytes.NewReader(big)))
	assert.Equal(t, http.StatusRequestEntityTooLarge, rec.Code)

	assert.Equal(t, http.StatusOK, call(r, http.MethodPost, "/v1/fa/visits", fa, bytes.NewReader(big[:1000])).Code)
	assert.Equal(t, http.StatusOK, call(r, http.MethodPost, "/v1/fa/sync/commands", fa, bytes.NewReader(big)).Code, "opted-in route")
	assert.Equal(t, http.StatusOK, call(r, http.MethodPost, "/v1/admin/imports/villages", ho, bytes.NewReader(big)).Code, "prefix opt-in")
	assert.Equal(t, http.StatusRequestEntityTooLarge,
		call(r, http.MethodPost, "/v1/fa/sync/commands", fa, bytes.NewReader(bytes.Repeat([]byte("x"), 5000))).Code)
}

const tinySpec = `openapi: 3.0.3
info: {title: t, version: "1"}
paths:
  /v1/fa/notes:
    post:
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                text: {type: string}
      responses:
        '204': {description: ok}
`

// TestBodyLimitThroughSpecValidator: the kin-openapi validator reads the
// body first; an over-long chunked body must still come back as 413.
func TestBodyLimitThroughSpecValidator(t *testing.T) {
	r := NewRouter(RouterConfig{Tokens: testTokens, MaxBodyBytes: 512})
	MountSpec(r, func() (*openapi3.T, error) { return openapi3.NewLoader().LoadFromData([]byte(tinySpec)) }, func(g chi.Router) {
		g.Post("/v1/fa/notes", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	})
	fa := token(t, auth.Principal{Kind: auth.KindFA, ID: uuid.New(), DeviceID: uuid.New()})
	body := `{"text":"` + strings.Repeat("a", 1000) + `"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/fa/notes", io.MultiReader(strings.NewReader(body)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+fa)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusRequestEntityTooLarge, rec.Code, rec.Body.String())

	req = httptest.NewRequest(http.MethodPost, "/v1/fa/notes", strings.NewReader(`{"text":"hi"}`))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+fa)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusNoContent, rec.Code, rec.Body.String())
}
