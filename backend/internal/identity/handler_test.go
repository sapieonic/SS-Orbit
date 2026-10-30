package identity

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

type errBody struct {
	Error struct {
		Code    string         `json:"code"`
		Message string         `json:"message"`
		Details map[string]any `json:"details"`
	} `json:"error"`
}

func do(t *testing.T, h http.Handler, method, path, token string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var r *http.Request
	if body != nil {
		b, err := json.Marshal(body)
		require.NoError(t, err)
		r = httptest.NewRequest(method, path, bytes.NewReader(b))
		r.Header.Set("Content-Type", "application/json")
	} else {
		r = httptest.NewRequest(method, path, nil)
	}
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, r)
	return rec
}

// HTTP tests without a database: routing, surface guard, spec validation and
// the checks the service makes before touching the database.
func TestHTTPGuardsAndValidation(t *testing.T) {
	tokens := testutil.Tokens()
	m := New(platform.Deps{Config: config.ForTest(), Clock: clock.System(), Tokens: tokens}, &Ports{})
	router := testutil.Router(tokens, m.Mount)

	fa := testutil.Token(t, tokens, testutil.FA())
	farmer := testutil.Token(t, tokens, testutil.Farmer())
	agronomy := testutil.Token(t, tokens, testutil.HO(auth.RoleAgronomy))
	ops := testutil.Token(t, tokens, testutil.HO(auth.RoleOps))
	device := map[string]any{"device_key": "install-1234"}

	cases := []struct {
		name, method, path, token string
		body                      any
		status                    int
		code, field               string
	}{
		{"otp phone too short", "POST", "/v1/auth/otp/request", "", map[string]any{"phone": "12345"}, 400, "validation_failed", "phone"},
		{"otp phone not mobile", "POST", "/v1/auth/otp/request", "", map[string]any{"phone": "0123456789"}, 400, "validation_failed", "phone"},
		{"otp bad language", "POST", "/v1/auth/otp/request", "", map[string]any{"phone": "9848012345", "language": "fr"}, 400, "validation_failed", "language"},
		{"verify bad code", "POST", "/v1/auth/otp/verify", "", map[string]any{"phone": "9848012345", "code": "12ab56", "device": device}, 400, "validation_failed", "code"},
		{"verify no device", "POST", "/v1/auth/otp/verify", "", map[string]any{"phone": "9848012345", "code": "123456"}, 400, "validation_failed", "device"},
		{"fa login bad device key", "POST", "/v1/auth/fa/login", "", map[string]any{"code": "FA-KDP-014", "password": "x", "device": map[string]any{"device_key": "a b"}}, 400, "validation_failed", "device.device_key"},
		{"refresh too short", "POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": "x"}, 400, "validation_failed", "refresh_token"},
		{"admin no token", "GET", "/v1/admin/field-assistants", "", nil, 401, "unauthorized", ""},
		{"admin fa token", "GET", "/v1/admin/field-assistants", fa, nil, 403, "forbidden", ""},
		{"admin agronomy", "GET", "/v1/admin/field-assistants", agronomy, nil, 403, "forbidden", ""},
		{"ho users need admin", "GET", "/v1/admin/ho-users", ops, nil, 403, "forbidden", ""},
		{"create fa missing name", "POST", "/v1/admin/field-assistants", ops, map[string]any{"phone": "9848012345", "level": "village", "area_code": "KDP"}, 400, "validation_failed", "name"},
		{"create fa bad code", "POST", "/v1/admin/field-assistants", ops, map[string]any{"name": "S", "phone": "9848012345", "level": "village", "code": "KDP-14"}, 400, "validation_failed", "code"},
		{"devices bad kind", "GET", "/v1/admin/devices?subject_kind=ho&subject_id=" + testutil.FA().ID.String(), ops, nil, 400, "validation_failed", "subject_kind"},
		{"fa heartbeat with farmer token", "PUT", "/v1/fa/devices/me", farmer, map[string]any{}, 403, "forbidden", ""},
		{"farmer heartbeat with fa token", "PUT", "/v1/farmer/devices/me", fa, map[string]any{}, 403, "forbidden", ""},
		{"fa password change too short", "POST", "/v1/fa/me/password", fa, map[string]any{"current_password": "a", "new_password": "short"}, 400, "validation_failed", "new_password"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rec := do(t, router, c.method, c.path, c.token, c.body)
			require.Equal(t, c.status, rec.Code, rec.Body.String())
			var body errBody
			require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body), rec.Body.String())
			assert.Equal(t, c.code, body.Error.Code, rec.Body.String())
			if c.field != "" {
				fields, _ := body.Error.Details["fields"].(map[string]any)
				assert.Contains(t, fields, c.field, rec.Body.String())
			}
		})
	}
}

// End-to-end over HTTP against the test database.
func TestHTTPFarmerFlow(t *testing.T) {
	e := newEnv(t)
	tokens := testutil.Tokens()
	m := &Module{svc: e.svc, handler: &handler{svc: e.svc}}
	router := testutil.Router(tokens, m.Mount)

	rec := do(t, router, "POST", "/v1/auth/otp/request", "", map[string]any{"phone": "98480 12345"})
	require.Equal(t, 200, rec.Code, rec.Body.String())
	assert.JSONEq(t, `{"phone_masked":"+91******2345","expires_in_seconds":300,"resend_after_seconds":30}`, rec.Body.String())
	rec = do(t, router, "POST", "/v1/auth/otp/request", "", map[string]any{"phone": "98480 12345"})
	require.Equal(t, 429, rec.Code)
	assert.Equal(t, "30", rec.Header().Get("Retry-After"))

	rec = do(t, router, "POST", "/v1/auth/otp/verify", "", map[string]any{"phone": "9848012345", "code": e.sms.lastCode(t),
		"device": map[string]any{"device_key": "install-http-1", "app_version": "1.0.0"}})
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var sess FarmerSession
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &sess))
	assert.True(t, sess.IsNew)
	require.NotNil(t, sess.FarmerStatus)
	assert.Equal(t, FarmerSessionFarmerStatusPendingProfile, *sess.FarmerStatus)
	assert.Equal(t, Bearer, sess.Tokens.TokenType)

	rec = do(t, router, "PUT", "/v1/farmer/devices/me", sess.Tokens.AccessToken, map[string]any{"push_token": "fcm-1"})
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var st DeviceStatus
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &st))
	assert.False(t, st.Wipe)
	assert.Equal(t, sess.DeviceId, st.DeviceId)

	rec = do(t, router, "POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": sess.Tokens.RefreshToken})
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var pair TokenPair
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &pair))

	rec = do(t, router, "POST", "/v1/auth/logout", pair.AccessToken, nil)
	require.Equal(t, 204, rec.Code, rec.Body.String())
	rec = do(t, router, "POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": pair.RefreshToken})
	require.Equal(t, 401, rec.Code)

	// FA login failures are generic.
	rec = do(t, router, "POST", "/v1/auth/fa/login", "", map[string]any{"code": "FA-KDP-014", "password": "nope",
		"device": map[string]any{"device_key": "fa-install-1"}})
	require.Equal(t, 401, rec.Code)
	var body errBody
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body))
	assert.Equal(t, "unauthorized", body.Error.Code)
	assert.Equal(t, "invalid login ID or password", body.Error.Message)
}

func jsonUnmarshal(b []byte, v any) error { return json.Unmarshal(b, v) }
