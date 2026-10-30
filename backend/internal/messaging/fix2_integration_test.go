package messaging

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// Drafts and rejected advisories can be edited; the product check and
// maker-checker (author and last editor cannot approve) still apply.
func TestUpdateAdvisory(t *testing.T) {
	e := newEnv(t)
	_, author := e.ho(auth.RoleAgronomy)
	editorP, editor := e.ho(auth.RoleAgronomy)
	_, checker := e.ho(auth.RoleAgronomy)
	_, finance := e.ho(auth.RoleFinance)

	created, err := e.svc.CreateAdvisory(author, advisoryInput(ChannelSMS))
	require.NoError(t, err)
	id := created.Advisory.ID

	_, err = e.svc.UpdateAdvisory(finance, id, AdvisoryPatch{TitleTe: ptr("x")})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	_, err = e.svc.UpdateAdvisory(author, ids.New(), AdvisoryPatch{TitleTe: ptr("x")})
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	// A product name in the new text needs names_product.
	_, err = e.svc.UpdateAdvisory(editor, id, AdvisoryPatch{BodyTe: ptr("Shanmukha Boost వాడండి")})
	assert.True(t, apperr.Is(err, apperr.KindValidation), "%v", err)

	out, err := e.svc.UpdateAdvisory(editor, id, AdvisoryPatch{
		BodyTe: ptr("Shanmukha Boost వాడండి"), NamesProduct: ptr(true), TitleEn: ptr(""), BodyEn: ptr(""),
		AudioContentType: ptr("audio/mpeg"),
	})
	require.NoError(t, err)
	a := out.Advisory
	assert.Equal(t, ClassPromotional, a.Class, "class derived again from names_product")
	assert.Nil(t, a.TitleEn, `"" removes the English title`)
	assert.Equal(t, "తెగులు హెచ్చరిక", a.TitleTe, "absent fields unchanged")
	require.NotNil(t, a.UpdatedBy)
	assert.Equal(t, editorP.ID, *a.UpdatedBy)
	require.NotNil(t, out.AudioUpload)
	require.NotNil(t, a.AudioKey)
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM audit_log WHERE action = 'messaging.advisory_updated' AND entity_id = $1`, id))

	out, err = e.svc.UpdateAdvisory(editor, id, AdvisoryPatch{RemoveAudio: true})
	require.NoError(t, err)
	assert.Nil(t, out.Advisory.AudioKey)

	_, err = e.svc.SubmitAdvisory(author, id, nil)
	require.NoError(t, err)
	_, err = e.svc.UpdateAdvisory(author, id, AdvisoryPatch{TitleTe: ptr("x")})
	assert.True(t, apperr.Is(err, apperr.KindConflict), "pending approval is not editable")

	// Rejected: a draft again, editable, then resubmitted.
	a, err = e.svc.RejectAdvisory(checker, id, "Add the dose")
	require.NoError(t, err)
	assert.Equal(t, StatusDraft, a.Status)
	out, err = e.svc.UpdateAdvisory(editor, id, AdvisoryPatch{BodyTe: ptr("Shanmukha Boost 2 ml/లీటర్ వాడండి")})
	require.NoError(t, err)
	assert.Equal(t, "Add the dose", *out.Advisory.ReviewNote, "the note stays until resubmitted")
	_, err = e.svc.SubmitAdvisory(author, id, nil)
	require.NoError(t, err)

	_, err = e.svc.ApproveAdvisory(editor, id)
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "the last editor cannot approve")
	_, err = e.svc.ApproveAdvisory(author, id)
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "the author cannot approve")
	a, err = e.svc.ApproveAdvisory(checker, id)
	require.NoError(t, err)
	assert.Equal(t, StatusScheduled, a.Status)
}

// The recipients list names each farmer with a masked phone, and SMS links
// use FARMER_WEB_BASE_URL.
func TestRecipientsNamesAndFarmerWebLinks(t *testing.T) {
	e := newEnv(t)
	e.svc.deps.Config.FarmerWebBaseURL = "https://f.orbit.example/"
	_, ops := e.ho(auth.RoleOps)
	f := e.farmer("Lakshmi", "te", "active", uuid.NullUUID{}, nu(e.village.ID))
	e.farmers.targeted = []uuid.UUID{f.ID}

	created, err := e.svc.CreateAdvisory(ops, advisoryInput(ChannelSMS))
	require.NoError(t, err)
	_, err = e.svc.SubmitAdvisory(ops, created.Advisory.ID, nil)
	require.NoError(t, err)
	require.NoError(t, e.svc.RunAdvisoryFanout(context.Background(), created.Advisory.ID))
	e.sendAll()

	require.Len(t, e.sms.sent, 1)
	assert.True(t, strings.HasPrefix(e.sms.sent[0].Body, "తెగులు హెచ్చరిక. "), e.sms.sent[0].Body)
	assert.Contains(t, e.sms.sent[0].Body, "https://f.orbit.example/web/notices/")
	assert.NotContains(t, e.sms.sent[0].Body, "పత్తిలో", "advisory text is on the page, not in the SMS")

	page, err := e.svc.ListRecipients(ops, created.Advisory.ID, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	r := page.Items[0]
	require.NotNil(t, r.FarmerName)
	assert.Equal(t, "Lakshmi", *r.FarmerName)
	require.NotNil(t, r.PhoneMasked)
	assert.Equal(t, "+91******"+f.Phone[len(f.Phone)-4:], *r.PhoneMasked)
}

// FA alerts store Telugu text and push in the FA's first language.
func TestFAAlertsInTelugu(t *testing.T) {
	e := newEnv(t)
	_, ops := e.ho(auth.RoleOps)
	teFA, enFA := e.fa("Ravi"), e.fa("John")
	teFA.Languages, enFA.Languages = []string{"te", "en"}, []string{"en"}
	e.identity.fas[teFA.ID], e.identity.fas[enFA.ID] = teFA, enFA
	e.identity.tokens[teFA.ID], e.identity.tokens[enFA.ID] = []string{"te-tok"}, []string{"en-tok"}

	for _, fa := range []uuid.UUID{teFA.ID, enFA.ID} {
		a, err := e.svc.CreateHONote(ops, HONote{FAID: fa, Title: "Meeting at 10", TitleTe: ptr("10 గంటలకు సమావేశం"),
			Body: ptr("Bring the register"), BodyTe: ptr("రిజిస్టర్ తీసుకురండి")})
		require.NoError(t, err)
		require.NotNil(t, a.TitleTe)
		require.NoError(t, e.svc.PushFAAlert(context.Background(), a.ID))
	}
	require.Len(t, e.push.sent, 2)
	byToken := map[string]string{}
	for _, m := range e.push.sent {
		byToken[m.Token] = m.Title + "|" + m.Body
	}
	assert.Equal(t, "10 గంటలకు సమావేశం|రిజిస్టర్ తీసుకురండి", byToken["te-tok"])
	assert.Equal(t, "Meeting at 10|Bring the register", byToken["en-tok"])

	faP := testutil.FA()
	faP.ID = teFA.ID
	page, err := e.svc.ListFAAlerts(testutil.Ctx(faP), nil, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	assert.Equal(t, "10 గంటలకు సమావేశం", *page.Items[0].TitleTe)
}
