package visits

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

type errBody struct {
	Error struct {
		Code    string         `json:"code"`
		Details map[string]any `json:"details"`
	} `json:"error"`
}

func do(t *testing.T, h http.Handler, method, path, token, body string) *httptest.ResponseRecorder {
	t.Helper()
	var req *http.Request
	if body != "" {
		req = httptest.NewRequest(method, path, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
	} else {
		req = httptest.NewRequest(method, path, nil)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

// Routing, surface guard, roles and request validation; no database needed.
func TestHTTPValidation(t *testing.T) {
	svc := unitService(nil)
	m := &Module{svc: svc, handler: &handler{svc: svc}}
	tokens := testutil.Tokens()
	router := testutil.Router(tokens, m.Mount)
	fa := testutil.Token(t, tokens, testutil.FA())
	farmer := testutil.Token(t, tokens, testutil.Farmer())
	ops := testutil.Token(t, tokens, testutil.HO(auth.RoleOps))
	finance := testutil.Token(t, tokens, testutil.HO(auth.RoleFinance))
	visit, photo := ids.New().String(), ids.New().String()
	upload := "/v1/fa/visits/" + visit + "/photos/" + photo + "/upload-url"

	cases := []struct {
		name, method, path, token, body string
		status                          int
		code, field                     string
	}{
		{"no token", "GET", "/v1/admin/visits", "", "", 401, "unauthorized", ""},
		{"farmer token on admin", "GET", "/v1/admin/visits", farmer, "", 403, "forbidden", ""},
		{"fa token on farmer", "GET", "/v1/farmer/visits", fa, "", 403, "forbidden", ""},
		{"finance cannot list", "GET", "/v1/admin/visits", finance, "", 403, "forbidden", ""},
		{"bad status", "GET", "/v1/admin/visits?status=lost", ops, "", 400, "validation_failed", "status"},
		{"bad date", "GET", "/v1/admin/visits?from=30-10-2026", ops, "", 400, "validation_failed", "from"},
		{"bad visit id", "GET", "/v1/admin/visits/123", ops, "", 400, "validation_failed", "visit_id"},
		{"sample needs from", "GET", "/v1/admin/visits/sample?to=2026-10-30", ops, "", 400, "validation_failed", "from"},
		{"sample too big", "GET", "/v1/admin/visits/sample?from=2026-10-01&to=2026-10-30&size=1000", ops, "", 400, "validation_failed", "size"},
		{"counts range backwards", "GET", "/v1/admin/visits/counts?from=2026-10-30&to=2026-10-01", ops, "", 400, "validation_failed", "to"},
		{"photo type", "POST", upload, fa, `{"content_type":"image/gif","bytes":10}`, 400, "validation_failed", ""},
		{"photo too big", "POST", upload, fa, `{"content_type":"image/jpeg","bytes":20000000}`, 400, "validation_failed", ""},
		{"photo body missing", "POST", upload, fa, "", 400, "", ""},
		{"bad cursor", "GET", "/v1/farmer/visits?cursor=zzz", farmer, "", 400, "invalid_cursor", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rec := do(t, router, c.method, c.path, c.token, c.body)
			require.Equal(t, c.status, rec.Code, rec.Body.String())
			var body errBody
			require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body), rec.Body.String())
			if c.code != "" {
				assert.Equal(t, c.code, body.Error.Code, rec.Body.String())
			}
			if c.field != "" {
				fields, _ := body.Error.Details["fields"].(map[string]any)
				assert.Contains(t, fields, c.field, rec.Body.String())
			}
		})
	}
}

// End-to-end over HTTP against the database.
func TestHTTPWithDatabase(t *testing.T) {
	w := newWorld(t)
	tokens := w.deps.Tokens
	router := testutil.Router(tokens, w.mod.Mount)
	farmer := testutil.Token(t, tokens, farmerPrincipal(w.farmer1))
	ops := testutil.Token(t, tokens, testutil.HO(auth.RoleOps))
	fa := testutil.Token(t, tokens, w.fa1)

	visit := ids.New()
	p := w.logPayload(visit)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdLogVisit, p).Status)
	photo := p["photos"].([]map[string]any)[0]["photo_id"]

	rec := do(t, router, "GET", "/v1/farmer/visits/next", farmer, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	assert.JSONEq(t, `{"next_visit":null}`, rec.Body.String())

	rec = do(t, router, "POST", "/v1/farmer/callbacks", farmer, "")
	require.Equal(t, 201, rec.Code, rec.Body.String())
	rec = do(t, router, "POST", "/v1/farmer/callbacks", farmer, "")
	require.Equal(t, 200, rec.Code, "already open")
	var cb Callback
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &cb))
	rec = do(t, router, "POST", "/v1/farmer/callbacks/"+cb.Id.String()+"/cancel", farmer, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	rec = do(t, router, "GET", "/v1/farmer/callbacks/current", farmer, "")
	assert.JSONEq(t, `{"callback":null}`, rec.Body.String())

	rec = do(t, router, "GET", "/v1/farmer/visits", farmer, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var page FarmerVisitPage
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &page))
	require.Len(t, page.Items, 1)
	assert.Equal(t, "Suresh K", page.Items[0].Fa.Name)
	assert.Len(t, page.Items[0].Issues, 2)

	rec = do(t, router, "POST", "/v1/fa/visits/"+visit.String()+"/photos/"+fmt.Sprint(photo)+"/upload-url",
		fa, `{"content_type":"image/jpeg","bytes":1024}`)
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var up PhotoUpload
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &up))
	assert.Equal(t, "PUT", up.Method)

	rec = do(t, router, "GET", "/v1/admin/visits/overdue", ops, "")
	require.Equal(t, 200, rec.Code, "static path wins over {visit_id}: %s", rec.Body.String())
	rec = do(t, router, "GET", "/v1/admin/visits/"+visit.String(), ops, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var detail VisitDetail
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &detail))
	assert.Equal(t, visit, detail.Visit.Id)
	require.Len(t, detail.Photos, 1)
	assert.Nil(t, detail.Photos[0].Url, "not uploaded yet")
	rec = do(t, router, "GET", "/v1/admin/visits/"+ids.New().String(), ops, "")
	assert.Equal(t, 404, rec.Code)
	rec = do(t, router, "GET", "/v1/admin/visits/counts?from=2026-10-01&to=2026-10-31", ops, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	assert.Contains(t, rec.Body.String(), `"done":1`)
	assert.Contains(t, rec.Body.String(), `"days":null`)
	rec = do(t, router, "GET", "/v1/admin/visits/counts?from=2026-10-01&to=2026-10-31&group_by=day&district_id="+w.district.String(), ops, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var vc VisitCounts
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &vc))
	require.NotNil(t, vc.Days)
	assert.Len(t, *vc.Days, 31)
	rec = do(t, router, "GET", "/v1/admin/visits/counts?from=2026-10-01&to=2026-10-31&group_by=week", ops, "")
	assert.Equal(t, 400, rec.Code)
	rec = do(t, router, "GET", "/v1/admin/visits?limit=1&farmer_id="+w.farmer1.String(), ops, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var vp map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &vp))
	item := vp["items"].([]any)[0].(map[string]any)
	assert.Contains(t, item, "planned_for", "nullable fields are always present")
	for _, k := range []string{"farmer_name", "farmer_name_te", "farmer_phone_masked", "village_id", "village_name", "village_name_te"} {
		assert.Contains(t, item, k)
	}
	assert.Equal(t, map[string]any{"lat": 17.46, "lng": 78.36}, item["location"])
}
