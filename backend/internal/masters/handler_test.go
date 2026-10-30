package masters

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

type errBody struct {
	Error struct {
		Code    string         `json:"code"`
		Message string         `json:"message"`
		Details map[string]any `json:"details"`
	} `json:"error"`
}

func serve(t *testing.T, router http.Handler, method, path, token, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

// Surface guard, role checks and spec validation: none of these reach the
// database, so the service has none.
func TestHTTPGuardsAndValidation(t *testing.T) {
	svc := NewService(platform.Deps{}, nil, nil)
	m := &Module{svc: svc, handler: &handler{svc: svc}}
	tokens := testutil.Tokens()
	router := testutil.Router(tokens, m.Mount)

	admin := testutil.Token(t, tokens, testutil.HO(auth.RoleAdmin))
	finance := testutil.Token(t, tokens, testutil.HO(auth.RoleFinance))
	fa := testutil.Token(t, tokens, testutil.FA())
	farmer := testutil.Token(t, tokens, testutil.Farmer())
	rule := "/v1/admin/masters/rules/" + ids.New().String()

	cases := []struct {
		name, method, path, token, body string
		status                          int
		code, field                     string
	}{
		{"no token", "GET", "/v1/admin/masters/crops", "", "", 401, "unauthorized", ""},
		{"fa on admin surface", "GET", "/v1/admin/masters/crops", fa, "", 403, "forbidden", ""},
		{"farmer on admin surface", "GET", "/v1/admin/masters/rules", farmer, "", 403, "forbidden", ""},
		{"ho on farmer surface", "GET", "/v1/farmer/crops", admin, "", 403, "forbidden", ""},
		{"finance cannot write", "POST", "/v1/admin/masters/salts", finance, `{"name":"Mancozeb"}`, 403, "forbidden", ""},
		{"admin cannot approve", "POST", rule + "/approve", admin, "", 403, "forbidden", ""},
		{"mrp over cap", "POST", "/v1/admin/masters/skus", admin,
			`{"code":"SH-1","product_name":"P","salt_id":"` + ids.New().String() + `","pack_size":"1 kg","mrp_paise":10000001}`,
			400, "validation_failed", "mrp_paise"},
		{"bad issue type", "POST", "/v1/admin/masters/issues", admin,
			`{"crop_id":"` + ids.New().String() + `","type":"weed","name":"x","name_te":"y"}`, 400, "validation_failed", "type"},
		{"bad crop code", "POST", "/v1/admin/masters/crops", admin, `{"code":"Cotton!","name":"x","name_te":"y"}`,
			400, "validation_failed", "code"},
		{"empty patch", "PATCH", "/v1/admin/masters/salts/" + ids.New().String(), admin, `{}`, 400, "validation_failed", ""},
		{"reject needs note", "POST", rule + "/reject", admin, `{}`, 400, "validation_failed", "note"},
		{"dealers need lat", "GET", "/v1/farmer/dealers?lng=78.3", farmer, "", 400, "validation_failed", "lat"},
		{"radius too big", "GET", "/v1/farmer/dealers?lat=17.4&lng=78.3&radius_km=500", farmer, "", 400, "validation_failed", "radius_km"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rec := serve(t, router, c.method, c.path, c.token, c.body)
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

// End to end over HTTP against the test database.
func TestHTTPFlow(t *testing.T) {
	pool := testutil.NewDB(t)
	m := New(testutil.NewDeps(t, pool), &Ports{})
	tokens := testutil.Tokens()
	router := testutil.Router(tokens, m.Mount)
	agronomy := testutil.Token(t, tokens, testutil.HO(auth.RoleAgronomy))
	farmer := testutil.Token(t, tokens, testutil.Farmer())

	rec := serve(t, router, "POST", "/v1/admin/masters/crops", agronomy,
		`{"code":"chilli","name":"Chilli","name_te":"మిరప","stages":[{"code":"nursery","name":"Nursery","name_te":"నారు","start_day":0,"end_day":30}]}`)
	require.Equal(t, 201, rec.Code, rec.Body.String())
	var crop CropView
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &crop))
	require.Len(t, crop.Stages, 1)

	rec = serve(t, router, "POST", "/v1/admin/masters/crops", agronomy, `{"code":"chilli","name":"Chilli","name_te":"మిరప"}`)
	require.Equal(t, 409, rec.Code, rec.Body.String())

	rec = serve(t, router, "GET", "/v1/farmer/crops", farmer, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var list map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &list))
	items := list["items"].([]any)
	require.Len(t, items, 1)
	first := items[0].(map[string]any)
	assert.Equal(t, "మిరప", first["name_te"])
	assert.Contains(t, first, "duration_days", "nullable fields are always present")
	sc := list["season_codes"].(map[string]any)
	assert.NotEmpty(t, sc["current"])
	assert.Len(t, sc["all_open"], 3)
	assert.Regexp(t, `^\d{4}-\d{2}-\d{2}$`, sc["valid_until"])
	assert.NotContains(t, first, "active")

	rec = serve(t, router, "GET", "/v1/farmer/dealers?lat=17.46&lng=78.36", farmer, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	assert.JSONEq(t, `{"items":[]}`, rec.Body.String())

	rec = serve(t, router, "GET", "/v1/admin/masters/rules/"+ids.New().String(), agronomy, "")
	require.Equal(t, 404, rec.Code, rec.Body.String())

	rec = serve(t, router, "GET", "/v1/admin/masters/version", agronomy, "")
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var v MastersVersion
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &v))
	assert.Equal(t, int64(2), v.Version, "seeded at 1, bumped once by the crop")
}
