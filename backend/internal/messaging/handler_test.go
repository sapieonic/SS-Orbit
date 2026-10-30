package messaging

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// HTTP tests through the real middleware stack (surface guard, spec
// validation, error shape) on the test database.
func TestHTTP(t *testing.T) {
	e := newEnv(t)
	tokens := testutil.Tokens()
	router := testutil.Router(tokens, e.mod.Mount)

	opsP, _ := e.ho(auth.RoleOps)
	ops := testutil.Token(t, tokens, opsP)
	fa := e.fa("Ravi")
	faP := testutil.FA()
	faP.ID = fa.ID
	faTok := testutil.Token(t, tokens, faP)
	f := e.farmer("Lakshmi", "te", "active", nu(fa.ID), nu(e.village.ID))
	farmerP := testutil.Farmer()
	farmerP.ID = f.ID
	farmerTok := testutil.Token(t, tokens, farmerP)

	do := func(method, path, token, body string) *httptest.ResponseRecorder {
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
		router.ServeHTTP(rec, req)
		return rec
	}
	errCode := func(rec *httptest.ResponseRecorder) (string, map[string]any) {
		t.Helper()
		var b struct {
			Error struct {
				Code    string         `json:"code"`
				Details map[string]any `json:"details"`
			} `json:"error"`
		}
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &b), rec.Body.String())
		fields, _ := b.Error.Details["fields"].(map[string]any)
		return b.Error.Code, fields
	}

	t.Run("advisory create validation and auth", func(t *testing.T) {
		rec := do("POST", "/v1/admin/advisories", ops, `{"body_te":"x","target":{},"channels":["sms"]}`)
		require.Equal(t, 400, rec.Code, rec.Body.String())
		code, fields := errCode(rec)
		assert.Equal(t, "validation_failed", code)
		assert.Contains(t, fields, "title_te")

		rec = do("POST", "/v1/admin/advisories", ops, `{"title_te":"a","body_te":"b","target":{},"channels":["fax"]}`)
		require.Equal(t, 400, rec.Code, rec.Body.String())

		rec = do("POST", "/v1/admin/advisories", faTok, `{"title_te":"a","body_te":"b","target":{},"channels":["sms"]}`)
		require.Equal(t, 403, rec.Code, rec.Body.String())
		rec = do("GET", "/v1/admin/advisories", "", "")
		require.Equal(t, 401, rec.Code)
	})

	var advID string
	t.Run("advisory create, get, submit", func(t *testing.T) {
		rec := do("POST", "/v1/admin/advisories", ops,
			`{"title_te":"హెచ్చరిక","body_te":"వివరం","target":{"village_ids":["`+e.village.ID.String()+`"]},"channels":["sms","push"],"image_content_type":"image/png"}`)
		require.Equal(t, 201, rec.Code, rec.Body.String())
		var created AdvisoryCreated
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &created))
		advID = created.Advisory.Id.String()
		assert.Equal(t, AdvisoryStatus("draft"), created.Advisory.Status)
		assert.Nil(t, created.AudioUpload)
		require.NotNil(t, created.ImageUpload)
		assert.Contains(t, created.ImageUpload.Url, "/dev/files/")

		rec = do("GET", "/v1/admin/advisories/"+advID, ops, "")
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var raw map[string]any
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &raw))
		assert.Contains(t, raw, "stats")
		assert.Contains(t, raw, "approved_by", "nullable fields are always present")

		rec = do("POST", "/v1/admin/advisories/"+advID+"/submit", ops, `{}`)
		require.Equal(t, 400, rec.Code, "image not uploaded yet: %s", rec.Body.String())

		rec = do("POST", "/v1/admin/advisories/"+advID+"/approve", ops, "")
		require.Equal(t, 403, rec.Code, "ops cannot approve")
		rec = do("GET", "/v1/admin/advisories/not-a-uuid", ops, "")
		require.Equal(t, 400, rec.Code)
		rec = do("GET", "/v1/admin/advisories/"+ids.New().String(), ops, "")
		require.Equal(t, 404, rec.Code)
		rec = do("POST", "/v1/admin/advisories/preview", ops, `{"target":{}}`)
		require.Equal(t, 200, rec.Code, rec.Body.String())
		rec = do("GET", "/v1/admin/advisories/"+advID+"/recipients?limit=10", ops, "")
		require.Equal(t, 200, rec.Code, rec.Body.String())
	})

	// A welcome notice for the farmer to read.
	require.NoError(t, e.svc.onWelcome(context.Background(), welcomeEvent(f.ID)))
	var noticeID uuid.UUID
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT id FROM notices WHERE farmer_id = $1`, f.ID).Scan(&noticeID))

	t.Run("farmer inbox", func(t *testing.T) {
		rec := do("GET", "/v1/farmer/notices", farmerTok, "")
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var page NoticePage
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &page))
		require.Len(t, page.Items, 1)
		assert.Equal(t, NoticeSender("system"), page.Items[0].Sender)

		rec = do("GET", "/v1/farmer/notices/unread-count", farmerTok, "")
		require.Equal(t, 200, rec.Code)
		assert.JSONEq(t, `{"unread":1}`, rec.Body.String())

		rec = do("POST", "/v1/farmer/notices/"+noticeID.String()+"/read", farmerTok, "")
		require.Equal(t, 204, rec.Code, rec.Body.String())
		rec = do("POST", "/v1/farmer/notices/"+noticeID.String()+"/listened", farmerTok, "")
		require.Equal(t, 204, rec.Code, rec.Body.String())
		rec = do("GET", "/v1/farmer/notices", ops, "")
		require.Equal(t, 403, rec.Code)
	})

	t.Run("farmer web page", func(t *testing.T) {
		link, _, err := e.deps.Tokens.IssueLink(f.ID, noticePurpose(noticeID), time.Hour)
		require.NoError(t, err)
		rec := do("GET", "/v1/web/notices/"+noticeID.String()+"?t="+link, "", "")
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var n Notice
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &n))
		assert.Equal(t, noticeID, n.Id)

		rec = do("POST", "/v1/web/notices/"+noticeID.String()+"/listened?t="+link, "", "")
		require.Equal(t, 204, rec.Code, rec.Body.String())

		wrong, _, _ := e.deps.Tokens.IssueLink(f.ID, "notice:"+ids.New().String(), time.Hour)
		rec = do("GET", "/v1/web/notices/"+noticeID.String()+"?t="+wrong, "", "")
		require.Equal(t, 403, rec.Code, "link for another notice")

		otherFarmer, _, _ := e.deps.Tokens.IssueLink(ids.New(), noticePurpose(noticeID), time.Hour)
		rec = do("GET", "/v1/web/notices/"+noticeID.String()+"?t="+otherFarmer, "", "")
		require.Equal(t, 404, rec.Code, "someone else's notice")

		rec = do("GET", "/v1/web/notices/"+noticeID.String(), farmerTok, "")
		require.Equal(t, 403, rec.Code, "app token is not a link token")
	})

	t.Run("alerts and hooks", func(t *testing.T) {
		rec := do("POST", "/v1/admin/fa-alerts", ops, `{"fa_id":"`+fa.ID.String()+`","title":"Call Lakshmi"}`)
		require.Equal(t, 201, rec.Code, rec.Body.String())

		rec = do("GET", "/v1/fa/alerts?status=open", faTok, "")
		require.Equal(t, 200, rec.Code, rec.Body.String())
		var page FAAlertPage
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &page))
		require.Len(t, page.Items, 1)
		assert.Equal(t, FAAlertKind("ho_note"), page.Items[0].Kind)

		rec = do("GET", "/v1/admin/alerts?kind=new_farmer", ops, "")
		require.Equal(t, 200, rec.Code, rec.Body.String())
		rec = do("GET", "/v1/admin/alerts?kind=bogus", ops, "")
		require.Equal(t, 400, rec.Code)

		rec = do("POST", "/hooks/sms/acme", "", "")
		require.Equal(t, 204, rec.Code, rec.Body.String())
	})
}
