package farmers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// HTTP tests: routing, surface guard, request validation, roles and the JSON
// shapes, against orbit_test with fake ports.
func TestHTTP(t *testing.T) {
	f := newFixture(t)
	m := &Module{svc: f.svc, handler: &handler{svc: f.svc}}
	tokens := f.deps.Tokens
	router := testutil.Router(tokens, m.Mount)

	_, enrolled := f.enrol(f.fa1, "9848011111", "Anil R", f.village)
	selfID := f.selfSignUp("9848022222")
	farmerTok := testutil.Token(t, tokens, auth.Principal{Kind: auth.KindFarmer, ID: selfID, DeviceID: ids.New(), SessionID: ids.New()})
	ops := testutil.Token(t, tokens, testutil.HO(auth.RoleOps))
	agronomy := testutil.Token(t, tokens, testutil.HO(auth.RoleAgronomy))
	fa := testutil.Token(t, tokens, testutil.FA())

	do := func(method, path, token, body string) *httptest.ResponseRecorder {
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
		router.ServeHTTP(rec, req)
		return rec
	}
	errCode := func(rec *httptest.ResponseRecorder) string {
		var body struct {
			Error struct {
				Code string `json:"code"`
			} `json:"error"`
		}
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body), rec.Body.String())
		return body.Error.Code
	}

	cases := []struct {
		name, method, path, token, body string
		status                          int
		code                            string
	}{
		{"no token", "GET", "/v1/farmer/me", "", "", 401, "unauthorized"},
		{"FA token on farmer surface", "GET", "/v1/farmer/me", fa, "", 403, "forbidden"},
		{"farmer token on admin surface", "GET", "/v1/admin/farmers", farmerTok, "", 403, "forbidden"},
		{"pending farmer cannot add plots", "POST", "/v1/farmer/me/plots", farmerTok, `{"pin":{"lat":17.4,"lng":78.3},"area_acres":1}`, 409, "profile_incomplete"},
		{"bad language", "POST", "/v1/farmer/me/complete-profile", farmerTok, `{"name":"Ravi","language":"hi","village_id":"` + f.village.String() + `"}`, 400, "validation_failed"},
		{"unknown field", "PATCH", "/v1/farmer/me", farmerTok, `{"aadhaar":"1234"}`, 400, "validation_failed"},
		{"zero area", "POST", "/v1/farmer/me/plots", farmerTok, `{"pin":{"lat":17.4,"lng":78.3},"area_acres":0}`, 400, "validation_failed"},
		{"agronomy cannot edit", "PATCH", "/v1/admin/farmers/" + enrolled.String(), agronomy, `{"expected_version":1,"plan":"premium"}`, 403, "forbidden"},
		{"agronomy can read", "GET", "/v1/admin/farmers/" + enrolled.String(), agronomy, "", 200, ""},
		{"unknown farmer", "GET", "/v1/admin/farmers/" + ids.New().String(), ops, "", 404, "not_found"},
		{"bad filter", "GET", "/v1/admin/farmers?status=gone", ops, "", 400, "validation_failed"},
		{"bad cursor", "GET", "/v1/admin/farmers?cursor=zzz", ops, "", 400, "invalid_cursor"},
		{"reassign needs a selection", "POST", "/v1/admin/farmer-reassignments", ops, `{"to_fa_id":"` + f.fa2.String() + `"}`, 400, "validation_failed"},
		{"rollover bad code", "POST", "/v1/admin/season-rollovers", ops, `{"season_code":"Kharif 2026"}`, 400, "validation_failed"},
		{"stats route is not a farmer ID", "GET", "/v1/admin/farmers/stats", agronomy, "", 200, ""},
		{"stats for FA token", "GET", "/v1/admin/farmers/stats", fa, "", 403, "forbidden"},
		{"phone lookup", "GET", "/v1/fa/farmers/lookup?phone=9848099999", fa, "", 200, ""},
		{"phone lookup needs a phone", "GET", "/v1/fa/farmers/lookup", fa, "", 400, "validation_failed"},
		{"phone lookup is FA only", "GET", "/v1/fa/farmers/lookup?phone=9848099999", ops, "", 403, "forbidden"},
		{"look for FAs", "GET", "/v1/farmer/fas?level=village", farmerTok, "", 200, ""},
		{"look for FAs bad level", "GET", "/v1/farmer/fas?level=state", farmerTok, "", 400, "validation_failed"},
		{"pending farmer can record consent", "POST", "/v1/farmer/me/consents", farmerTok, `{"purpose":"programme","granted":true,"notice_version":"2026-10","audio_played":true}`, 200, ""},
		{"FA photo upload for an offline farmer ID", "POST", "/v1/fa/farmers/" + ids.New().String() + "/photo/upload-url", fa, `{"content_type":"image/jpeg","bytes":204800}`, 200, ""},
		{"FA photo upload bad type", "POST", "/v1/fa/farmers/" + ids.New().String() + "/photo/upload-url", fa, `{"content_type":"image/gif","bytes":204800}`, 400, "validation_failed"},
		{"FA photo upload too big", "POST", "/v1/fa/farmers/" + ids.New().String() + "/photo/upload-url", fa, `{"content_type":"image/png","bytes":6000000}`, 400, "validation_failed"},
		{"FA photo upload of another FA's farmer", "POST", "/v1/fa/farmers/" + enrolled.String() + "/photo/upload-url", fa, `{"content_type":"image/jpeg","bytes":1000}`, 403, "forbidden"},
		{"pending farmer photo upload", "POST", "/v1/farmer/me/photo/upload-url", farmerTok, `{"content_type":"image/jpeg","bytes":1000}`, 409, "profile_incomplete"},
		{"plan change needs admin", "PATCH", "/v1/admin/farmers/" + enrolled.String(), ops, `{"expected_version":1,"plan":"premium","reason":"x"}`, 403, "forbidden"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rec := do(c.method, c.path, c.token, c.body)
			require.Equal(t, c.status, rec.Code, rec.Body.String())
			if c.code != "" {
				assert.Equal(t, c.code, errCode(rec))
			}
		})
	}

	t.Run("self sign-up flow", func(t *testing.T) {
		rec := do("POST", "/v1/farmer/me/complete-profile", farmerTok,
			`{"name":"Ravi K","name_te":"రవి","language":"te","village_id":"`+f.village.String()+`"}`)
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var farmer Farmer
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &farmer))
		assert.Equal(t, FarmerStatus("active"), farmer.Status)

		rec = do("POST", "/v1/farmer/me/plots", farmerTok, `{"pin":{"lat":17.46,"lng":78.36},"area_acres":2.1}`)
		require.Equal(t, 201, rec.Code, rec.Body.String())
		var plot Plot
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &plot))

		rec = do("POST", "/v1/farmer/me/plots/"+plot.Id.String()+"/seasons", farmerTok,
			`{"season_code":"rabi-2026-27","crop_id":"`+f.cotton.String()+`","sowing_date":"2026-10-20"}`)
		require.Equal(t, 201, rec.Code, rec.Body.String())

		rec = do("GET", "/v1/farmer/me", farmerTok, "")
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var raw map[string]any
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &raw))
		assert.Contains(t, raw, "next_visit", "nullable fields are always present")
		assert.Nil(t, raw["next_visit"])
		plots := raw["plots"].([]any)
		require.Len(t, plots, 1)
		hp := plots[0].(map[string]any)
		assert.EqualValues(t, 10, hp["days_after_sowing"])
		assert.Equal(t, "seedling", hp["current_stage"].(map[string]any)["code"])
		assert.Equal(t, "2026-10-20", hp["active_season"].(map[string]any)["sowing_date"])
		assert.Equal(t, "Suresh K", raw["fa"].(map[string]any)["name"])

		rec = do("POST", "/v1/farmer/me/consents", farmerTok, `{"purpose":"soil_partner","granted":true,"notice_version":"2026-10"}`)
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var cs CurrentConsentList
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &cs))
		require.Len(t, cs.Items, 4)
		assert.True(t, *cs.Items[1].Granted)
	})

	t.Run("admin list masks phones", func(t *testing.T) {
		rec := do("GET", "/v1/admin/farmers?limit=1", ops, "")
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var page AdminFarmerPage
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &page))
		require.Len(t, page.Items, 1)
		assert.NotNil(t, page.NextCursor)
		assert.Equal(t, "+91******2222", page.Items[0].PhoneMasked)
		assert.NotContains(t, rec.Body.String(), "9848022222")
	})

	t.Run("admin 360 and update", func(t *testing.T) {
		rec := do("GET", "/v1/admin/farmers/"+enrolled.String(), ops, "")
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var v Farmer360
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &v))
		assert.Equal(t, "+919848011111", v.Farmer.Phone)
		assert.Len(t, v.ConsentHistory, 2)

		rec = do("PATCH", "/v1/admin/farmers/"+enrolled.String(), ops, `{"expected_version":99,"plan":"premium"}`)
		require.Equal(t, 409, rec.Code, rec.Body.String())
		assert.Equal(t, "version_mismatch", errCode(rec))

		rec = do("POST", "/v1/admin/farmers/"+enrolled.String()+"/deactivate", ops, "")
		require.Equal(t, 200, rec.Code, rec.Body.String())

		rec = do("POST", "/v1/admin/farmer-reassignments", ops, `{"to_fa_id":"`+f.fa2.String()+`","village_ids":["`+f.village.String()+`"]}`)
		require.Equal(t, 400, rec.Code, "from_fa_id is required by village: %s", rec.Body.String())
		rec = do("POST", "/v1/admin/farmer-reassignments", ops, `{"to_fa_id":"`+f.fa2.String()+`","from_fa_id":"`+f.fa1.String()+`","village_ids":["`+f.village.String()+`"]}`)
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var res ReassignResult
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &res))
		assert.Equal(t, 1, res.Moved, "the self sign-up in Kondapur; the deactivated farmer is skipped")
	})
}
