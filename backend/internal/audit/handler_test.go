package audit

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// HTTP-level tests: routing, surface guard, role check, request validation
// and the error shape, with a fake store (no database).
func TestHTTP(t *testing.T) {
	fq := &fakeQueries{rows: sampleRows(3)}
	svc := NewService(fq, nil)
	m := &Module{svc: svc, handler: &handler{svc: svc}}
	tokens := testutil.Tokens()
	router := testutil.Router(tokens, m.Mount)

	admin := testutil.Token(t, tokens, testutil.HO(auth.RoleAdmin))
	agronomy := testutil.Token(t, tokens, testutil.HO(auth.RoleAgronomy))
	fa := testutil.Token(t, tokens, testutil.FA())

	type errBody struct {
		Error struct {
			Code    string         `json:"code"`
			Message string         `json:"message"`
			Details map[string]any `json:"details"`
		} `json:"error"`
	}

	cases := []struct {
		name   string
		path   string
		token  string
		status int
		code   string // expected error code, "" for success
		field  string // expected details.fields key
	}{
		{"no token", "/v1/admin/audit", "", 401, "unauthorized", ""},
		{"garbage token", "/v1/admin/audit", "nope", 401, "unauthorized", ""},
		{"fa token on admin surface", "/v1/admin/audit", fa, 403, "forbidden", ""},
		{"agronomy role", "/v1/admin/audit", agronomy, 403, "forbidden", ""},
		{"admin ok", "/v1/admin/audit?action=farmers.&limit=2", admin, 200, "", ""},
		{"bad uuid filter", "/v1/admin/audit?entity_id=xyz", admin, 400, "validation_failed", "entity_id"},
		{"limit too big", "/v1/admin/audit?limit=1000", admin, 400, "validation_failed", "limit"},
		{"bad time", "/v1/admin/audit?from=yesterday", admin, 400, "validation_failed", "from"},
		{"bad cursor", "/v1/admin/audit?cursor=zzz", admin, 400, "invalid_cursor", ""},
		{"chain ok", "/v1/admin/audit/chain/farmer/" + ids.New().String(), admin, 200, "", ""},
		{"chain bad uuid", "/v1/admin/audit/chain/farmer/123", admin, 400, "validation_failed", "entity_id"},
		{"chain bad type", "/v1/admin/audit/chain/Farmer!/" + ids.New().String(), admin, 400, "validation_failed", "entity_type"},
		{"unknown route", "/v1/admin/audit/nope/x/y/z", admin, 404, "not_found", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, c.path, nil)
			if c.token != "" {
				req.Header.Set("Authorization", "Bearer "+c.token)
			}
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)

			require.Equal(t, c.status, rec.Code, rec.Body.String())
			assert.Contains(t, rec.Header().Get("Content-Type"), "application/json")
			assert.NotEmpty(t, rec.Header().Get("X-Request-ID"))
			if c.code == "" {
				var page AuditEventPage
				require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &page))
				assert.NotEmpty(t, page.Items)
				return
			}
			var body errBody
			require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body), rec.Body.String())
			assert.Equal(t, c.code, body.Error.Code, rec.Body.String())
			assert.NotEmpty(t, body.Error.Message)
			if c.field != "" {
				fields, _ := body.Error.Details["fields"].(map[string]any)
				assert.Contains(t, fields, c.field, rec.Body.String())
			}
		})
	}

	t.Run("pagination over http", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v1/admin/audit?limit=2", nil)
		req.Header.Set("Authorization", "Bearer "+admin)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		require.Equal(t, 200, rec.Code)
		var raw map[string]any
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &raw))
		assert.Len(t, raw["items"], 2)
		assert.NotNil(t, raw["next_cursor"])
		item := raw["items"].([]any)[0].(map[string]any)
		assert.Contains(t, item, "farmer_id", "nullable fields are always present")
		assert.Nil(t, item["farmer_id"])
	})
}
