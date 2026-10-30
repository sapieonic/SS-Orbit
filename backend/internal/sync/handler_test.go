package sync

import (
	"bytes"
	"encoding/json"
	"fmt"
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

type errBody struct {
	Error struct {
		Code    string         `json:"code"`
		Message string         `json:"message"`
		Details map[string]any `json:"details"`
	} `json:"error"`
}

func do(t *testing.T, h http.Handler, method, path, token, body string, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestHTTPCommands(t *testing.T) {
	e := newEnv(t, nil)
	registerFakeHandlers(e, newCounter(), ids.New())
	router := testutil.Router(e.deps.Tokens, e.m.Mount)
	fa := testutil.Token(t, e.deps.Tokens, e.fa)
	ho := testutil.Token(t, e.deps.Tokens, testutil.HO(auth.RoleAdmin))

	applyID, unknownID, entity := ids.New(), ids.New(), ids.New()
	body := fmt.Sprintf(`{"commands":[
		{"id":%q,"type":"Apply","payload":{"entity_id":%q},"client_created_at":"2026-10-29T11:02:00+05:30"},
		{"id":%q,"type":"Nope","payload":{}}]}`, applyID, entity, unknownID)
	rec := do(t, router, http.MethodPost, "/v1/fa/sync/commands", fa, body, nil)
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())

	var raw map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &raw))
	assert.Nil(t, raw["retry_from"])
	assert.EqualValues(t, 1, raw["territory_version"])
	assert.EqualValues(t, 7, raw["masters_version"])
	results := raw["results"].([]any)
	require.Len(t, results, 2)
	r0, r1 := results[0].(map[string]any), results[1].(map[string]any)
	assert.Equal(t, applyID.String(), r0["id"])
	assert.Equal(t, "applied", r0["status"])
	assert.Equal(t, entity.String(), r0["entity_id"])
	assert.Equal(t, "rejected", r1["status"])
	assert.Nil(t, r1["entity_id"], "uuid.Nil is sent as null")
	assert.Contains(t, r1["error"], "unknown command type")

	tooMany := make([]string, MaxBatch+1)
	for i := range tooMany {
		tooMany[i] = fmt.Sprintf(`{"id":%q,"type":"Apply","payload":{}}`, ids.New())
	}
	cases := []struct {
		name, token, body string
		status            int
		code              string
	}{
		{"ho token on fa surface", ho, body, 403, "forbidden"},
		{"no token", "", body, 401, "unauthorized"},
		{"empty batch", fa, `{"commands":[]}`, 400, "validation_failed"},
		{"too many", fa, `{"commands":[` + strings.Join(tooMany, ",") + `]}`, 400, "validation_failed"},
		{"bad id", fa, `{"commands":[{"id":"x","type":"Apply","payload":{}}]}`, 400, "validation_failed"},
		{"payload not an object", fa, fmt.Sprintf(`{"commands":[{"id":%q,"type":"Apply","payload":[1]}]}`, ids.New()), 400, "validation_failed"},
		{"missing payload", fa, fmt.Sprintf(`{"commands":[{"id":%q,"type":"Apply"}]}`, ids.New()), 400, "validation_failed"},
		{"bad type", fa, fmt.Sprintf(`{"commands":[{"id":%q,"type":"drop table","payload":{}}]}`, ids.New()), 400, "validation_failed"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rec := do(t, router, http.MethodPost, "/v1/fa/sync/commands", c.token, c.body, nil)
			require.Equal(t, c.status, rec.Code, rec.Body.String())
			var b errBody
			require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &b))
			assert.Equal(t, c.code, b.Error.Code)
		})
	}
	assert.Equal(t, 2, e.countCommands(t), "rejected requests store nothing")
}

func TestHTTPSnapshotAndStatus(t *testing.T) {
	e := newEnv(t, nil)
	calls := newCounter()
	registerFakeSnapshot(e, calls)
	router := testutil.Router(e.deps.Tokens, e.m.Mount)
	fa := testutil.Token(t, e.deps.Tokens, e.fa)

	rec := do(t, router, http.MethodGet, "/v1/fa/sync/snapshot", fa, "", map[string]string{"Accept-Encoding": "gzip, deflate"})
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, "gzip", rec.Header().Get("Content-Encoding"))
	assert.Equal(t, `"t0-m7"`, rec.Header().Get("ETag"))
	assert.Contains(t, rec.Header().Get("Content-Type"), "application/json")
	assert.Equal(t, "private, no-cache", rec.Header().Get("Cache-Control"))
	snap := decodeEnvelope(t, rec.Body.Bytes())
	assert.Contains(t, snap.Sections, "farmers")

	rec = do(t, router, http.MethodGet, "/v1/fa/sync/snapshot", fa, "", map[string]string{"Accept-Encoding": "gzip", "If-None-Match": `"t0-m7"`})
	require.Equal(t, http.StatusNotModified, rec.Code, rec.Body.String())
	assert.Equal(t, `"t0-m7"`, rec.Header().Get("ETag"))
	assert.Empty(t, rec.Body.Bytes())
	assert.Equal(t, 1, calls.get("build"))

	// A client without gzip (curl) gets plain JSON.
	for _, ae := range []string{"", "identity", "gzip;q=0"} {
		rec = do(t, router, http.MethodGet, "/v1/fa/sync/snapshot", fa, "", map[string]string{"Accept-Encoding": ae})
		require.Equal(t, http.StatusOK, rec.Code)
		assert.Empty(t, rec.Header().Get("Content-Encoding"), ae)
		var plain Snapshot
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &plain), ae)
		assert.Equal(t, int64(7), plain.MastersVersion)
	}

	e.bump(t)
	rec = do(t, router, http.MethodGet, "/v1/fa/sync/status", fa, "", nil)
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	var st SyncStatus
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &st))
	assert.Equal(t, SyncStatus{TerritoryVersion: 1, MastersVersion: 7, Etag: `"t1-m7"`}, st)

	ho := testutil.Token(t, e.deps.Tokens, testutil.HO(auth.RoleAdmin))
	rec = do(t, router, http.MethodGet, "/v1/fa/sync/snapshot", ho, "", nil)
	assert.Equal(t, http.StatusForbidden, rec.Code)
}

func TestHTTPAdminListCommands(t *testing.T) {
	e := newEnv(t, nil)
	registerFakeHandlers(e, newCounter(), ids.New())
	other := e.newFA(t)
	batch := cmds(t, "Apply", "Conflict", "Invalid", "Conflict")
	_, err := e.svc.SubmitBatch(e.ctx(), batch)
	require.NoError(t, err)
	_, err = e.svc.SubmitBatch(testutil.Ctx(other), cmds(t, "Conflict"))
	require.NoError(t, err)

	router := testutil.Router(e.deps.Tokens, e.m.Mount)
	ops := testutil.Token(t, e.deps.Tokens, testutil.HO(auth.RoleOps))

	page := func(path string) StoredCommandPage {
		t.Helper()
		rec := do(t, router, http.MethodGet, path, ops, "", nil)
		require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
		var p StoredCommandPage
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &p))
		return p
	}

	all := page("/v1/admin/sync/commands")
	assert.Len(t, all.Items, 5)
	assert.Nil(t, all.NextCursor)

	conflicts := page("/v1/admin/sync/commands?status=conflict&fa_id=" + e.fa.ID.String())
	require.Len(t, conflicts.Items, 2)
	for _, c := range conflicts.Items {
		assert.Equal(t, CommandStatus("conflict"), c.Status)
		assert.Equal(t, e.fa.ID, c.FaId)
		require.NotNil(t, c.Result.Conflict)
		assert.Equal(t, "area_acres", c.Result.Conflict.Field)
		assert.Contains(t, c.Payload, "entity_id")
		require.NotNil(t, c.DeviceId)
	}
	assert.Len(t, page("/v1/admin/sync/commands?type=Invalid").Items, 1)

	// Keyset pagination walks every row once.
	seen := map[string]bool{}
	path := "/v1/admin/sync/commands?limit=2"
	for {
		p := page(path)
		for _, c := range p.Items {
			assert.False(t, seen[c.Id.String()], "duplicate across pages")
			seen[c.Id.String()] = true
		}
		if p.NextCursor == nil {
			break
		}
		path = "/v1/admin/sync/commands?limit=2&cursor=" + *p.NextCursor
	}
	assert.Len(t, seen, 5)

	cases := []struct {
		name, path, token string
		status            int
		code              string
	}{
		{"agronomy", "/v1/admin/sync/commands", testutil.Token(t, e.deps.Tokens, testutil.HO(auth.RoleAgronomy)), 403, "forbidden"},
		{"area scoped ops", "/v1/admin/sync/commands", testutil.Token(t, e.deps.Tokens, testutil.HO(auth.RoleOps, ids.New())), 403, "forbidden"},
		{"fa token", "/v1/admin/sync/commands", testutil.Token(t, e.deps.Tokens, e.fa), 403, "forbidden"},
		{"bad status", "/v1/admin/sync/commands?status=pending", ops, 400, "validation_failed"},
		{"bad fa_id", "/v1/admin/sync/commands?fa_id=1", ops, 400, "validation_failed"},
		{"to before from", "/v1/admin/sync/commands?from=2026-10-30T00:00:00Z&to=2026-10-29T00:00:00Z", ops, 400, "validation_failed"},
		{"bad cursor", "/v1/admin/sync/commands?cursor=zzz", ops, 400, "invalid_cursor"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rec := do(t, router, http.MethodGet, c.path, c.token, "", nil)
			require.Equal(t, c.status, rec.Code, rec.Body.String())
			var b errBody
			require.NoError(t, json.NewDecoder(bytes.NewReader(rec.Body.Bytes())).Decode(&b))
			assert.Equal(t, c.code, b.Error.Code)
		})
	}
}
