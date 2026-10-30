package geo_test

import (
	"encoding/json"
	"io"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// HTTP-level tests through the production middleware: surface guard, roles,
// request validation, status codes and the shared error shape.
func TestHTTP(t *testing.T) {
	w := newWorld(t)
	router := testutil.Router(w.deps.Tokens, w.m.Mount)
	tok := func(p auth.Principal) string { return testutil.Token(t, w.deps.Tokens, p) }
	ops := tok(testutil.HO(auth.RoleOps))
	finance := tok(testutil.HO(auth.RoleFinance))
	farmer := tok(testutil.Farmer())
	fa := tok(testutil.FA())
	suresh := w.fa(t, "Suresh K", "active")
	kiran := w.fa(t, "Kiran M", "active")

	do := func(method, path, token, contentType, body string) (int, map[string]any) {
		t.Helper()
		var r io.Reader
		if body != "" {
			r = strings.NewReader(body)
		}
		req := httptest.NewRequest(method, path, r)
		if contentType != "" {
			req.Header.Set("Content-Type", contentType)
		}
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		var out map[string]any
		_ = json.Unmarshal(rec.Body.Bytes(), &out)
		return rec.Code, out
	}
	const js = "application/json"
	errCodeOf := func(body map[string]any) string {
		e, _ := body["error"].(map[string]any)
		c, _ := e["code"].(string)
		return c
	}

	cases := []struct {
		name, method, path, token, ctype, body string
		status                                 int
		code                                   string
	}{
		{"no token", "GET", "/v1/admin/geo/districts", "", "", "", 401, "unauthorized"},
		{"farmer on admin", "GET", "/v1/admin/geo/districts", farmer, "", "", 403, "forbidden"},
		{"fa on farmer picker", "GET", "/v1/farmer/villages?q=ko", fa, "", "", 403, "forbidden"},
		{"finance reads tree", "GET", "/v1/admin/geo/tree", finance, "", "", 200, ""},
		{"finance cannot write", "POST", "/v1/admin/geo/districts", finance, js, `{"name":"Nalgonda"}`, 403, "forbidden"},
		{"unknown property", "POST", "/v1/admin/geo/districts", ops, js, `{"name":"Nalgonda","pin":"1"}`, 400, "validation_failed"},
		{"bad lgd code", "POST", "/v1/admin/geo/districts", ops, js, `{"name":"Nalgonda","lgd_code":"N1"}`, 400, "validation_failed"},
		{"empty patch", "PATCH", "/v1/admin/geo/villages/" + w.kondapur.String(), ops, js, `{}`, 400, "validation_failed"},
		{"bad uuid", "GET", "/v1/admin/geo/villages/123", ops, "", "", 400, "validation_failed"},
		{"unknown village", "GET", "/v1/admin/geo/villages/" + unknownID.String(), ops, "", "", 404, "not_found"},
		{"bad level", "POST", "/v1/admin/allocations", ops, js,
			`{"fa_id":"` + suresh.String() + `","level":"state","area_id":"` + w.kondapur.String() + `"}`, 400, "validation_failed"},
		{"bad cursor", "GET", "/v1/admin/allocations?cursor=zzz", ops, "", "", 400, "invalid_cursor"},
		{"latitude range", "PATCH", "/v1/admin/geo/villages/" + w.kondapur.String(), ops, js, `{"lat":95,"lng":78}`, 400, "validation_failed"},
		{"farmer limit", "GET", "/v1/farmer/villages?limit=500", farmer, "", "", 400, "validation_failed"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			status, body := do(c.method, c.path, c.token, c.ctype, c.body)
			require.Equal(t, c.status, status, "%v", body)
			if c.code != "" {
				assert.Equal(t, c.code, errCodeOf(body))
			}
		})
	}

	t.Run("create district", func(t *testing.T) {
		status, body := do("POST", "/v1/admin/geo/districts", ops, js, `{"name":"  Nalgonda ","name_te":"నల్గొండ","lgd_code":"528"}`)
		require.Equal(t, 201, status, "%v", body)
		assert.Equal(t, "Nalgonda", body["name"])
		assert.Equal(t, "Telangana", body["state"])
		status, body = do("POST", "/v1/admin/geo/districts", ops, js, `{"name":"Nalgonda"}`)
		require.Equal(t, 409, status)
		assert.Equal(t, "district_exists", errCodeOf(body))
	})

	t.Run("farmer picks a village", func(t *testing.T) {
		status, body := do("GET", "/v1/farmer/villages?q=kond", farmer, "", "")
		require.Equal(t, 200, status, "%v", body)
		items := body["items"].([]any)
		require.Len(t, items, 1)
		v := items[0].(map[string]any)
		assert.Equal(t, "Kondapur", v["name"])
		assert.Equal(t, "కొండాపూర్", v["name_te"])
		assert.Equal(t, "Serilingampally", v["mandal_name"])
		assert.Equal(t, "Rangareddy", v["district_name"])
		assert.Contains(t, v, "lat", "nullable fields are always present")
		assert.Nil(t, v["lat"])

		status, body = do("GET", "/v1/farmer/geo/tree", farmer, "", "")
		require.Equal(t, 200, status)
		assert.Len(t, body["districts"], 3, "includes Nalgonda added above")
	})

	t.Run("allocate, conflict, end, hand over", func(t *testing.T) {
		alloc := `{"fa_id":"` + suresh.String() + `","level":"village","area_id":"` + w.kondapur.String() + `"}`
		status, body := do("POST", "/v1/admin/allocations", ops, js, alloc)
		require.Equal(t, 201, status, "%v", body)
		assert.Equal(t, true, body["is_lead"], "lead by default")
		assert.Equal(t, "Kondapur", body["area_name"])
		assert.Equal(t, "Suresh K", body["fa"].(map[string]any)["name"])
		id := body["id"].(string)

		second := `{"fa_id":"` + kiran.String() + `","level":"village","area_id":"` + w.kondapur.String() + `"}`
		status, body = do("POST", "/v1/admin/allocations", ops, js, second)
		require.Equal(t, 409, status)
		assert.Equal(t, "area_has_lead", errCodeOf(body))
		assert.Equal(t, suresh.String(), body["error"].(map[string]any)["details"].(map[string]any)["fa_id"])

		status, body = do("GET", "/v1/admin/allocations?fa_id="+suresh.String(), finance, "", "")
		require.Equal(t, 200, status)
		assert.Len(t, body["items"], 1)
		assert.Nil(t, body["next_cursor"])

		status, body = do("POST", "/v1/admin/allocations/handover", ops, js,
			`{"from_fa_id":"`+suresh.String()+`","to_fa_id":"`+kiran.String()+`"}`)
		require.Equal(t, 200, status, "%v", body)
		assert.Equal(t, []any{w.kondapur.String()}, body["affected_village_ids"])
		assert.Equal(t, []any{id}, body["ended_allocation_ids"])
		moved := body["allocations"].([]any)[0].(map[string]any)
		assert.Equal(t, kiran.String(), moved["fa_id"])

		status, body = do("POST", "/v1/admin/allocations/"+id+"/end", ops, "", "")
		require.Equal(t, 409, status)
		assert.Equal(t, "allocation_ended", errCodeOf(body))
		status, body = do("POST", "/v1/admin/allocations/"+moved["id"].(string)+"/end", ops, "", "")
		require.Equal(t, 200, status, "%v", body)
		assert.NotNil(t, body["valid_to"])
	})

	t.Run("csv import", func(t *testing.T) {
		csv := "district,mandal,village,name_te\nRangareddy,Serilingampally,Hafeezpet,హఫీజ్‌పేట్\n"
		status, body := do("POST", "/v1/admin/geo/village-imports", ops, "text/csv", csv)
		require.Equal(t, 200, status, "%v", body)
		assert.Equal(t, float64(1), body["created"])

		status, body = do("POST", "/v1/admin/geo/village-imports", ops, "text/csv", "district,mandal,village\nX,Y,Z\n")
		require.Equal(t, 400, status)
		assert.Equal(t, "validation_failed", errCodeOf(body))
		assert.Contains(t, body["error"].(map[string]any)["details"].(map[string]any)["fields"], "row 2")

		status, _ = do("POST", "/v1/admin/geo/village-imports?create_missing=true", finance, "text/csv", csv)
		assert.Equal(t, 403, status)
		status, _ = do("POST", "/v1/admin/geo/village-imports", ops, js, `{"x":1}`)
		assert.Equal(t, 400, status, "only text/csv is accepted")
	})
}
