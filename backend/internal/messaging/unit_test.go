package messaging

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	platformsms "github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Pure rules: no database.

func TestSendAfterQuietHours(t *testing.T) {
	at := func(d, h, m int) time.Time { return time.Date(2026, 10, d, h, m, 0, 0, ist) }
	cases := []struct {
		name string
		in   time.Time
		want time.Time
	}{
		{"daytime unchanged", at(30, 12, 0), at(30, 12, 0)},
		{"just before quiet", at(30, 20, 59), at(30, 20, 59)},
		{"quiet starts 21:00", at(30, 21, 0), at(31, 7, 0)},
		{"late night", at(30, 23, 45), at(31, 7, 0)},
		{"after midnight", at(31, 2, 0), at(31, 7, 0)},
		{"quiet ends 07:00", at(31, 7, 0), at(31, 7, 0)},
		{"month end", at(31, 22, 0), time.Date(2026, 11, 1, 7, 0, 0, 0, ist)},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := sendAfterQuietHours(c.in.UTC())
			assert.True(t, c.want.Equal(got), "got %s want %s", got.In(ist), c.want)
			assert.Equal(t, time.UTC, got.Location())
		})
	}
}

// Advisory SMS is a fixed DLT template: a short title and the page link,
// never the free-text body (DLT cannot register free text).
func TestRenderAdvisory(t *testing.T) {
	n := noticeText{TitleTe: "తెగులు హెచ్చరిక", BodyTe: "పత్తిలో గులాబీ పురుగు", TitleEn: ptr("Pest alert"), BodyEn: ptr("Pink bollworm in cotton")}

	msg := renderAdvisory(ChannelSMS, ClassService, "te", n)
	assert.Equal(t, "తెగులు హెచ్చరిక. పూర్తి సలహా వినండి / చదవండి: "+linkMarker, msg.Body)
	assert.Equal(t, platformsms.DLTAdvisoryServiceTe, msg.TemplateID)

	msg = renderAdvisory(ChannelSMS, ClassPromotional, "en", n)
	assert.Equal(t, "Pest alert. Read or listen to the product advice: "+linkMarker, msg.Body)
	assert.Equal(t, platformsms.DLTAdvisoryPromoEn, msg.TemplateID)
	assert.NotContains(t, msg.Body, "bollworm", "the body is not in the SMS")

	long := n
	long.TitleTe = strings.Repeat("అ", 100)
	msg = renderAdvisory(ChannelSMS, ClassService, "te", long)
	title := strings.SplitN(msg.Body, ". ", 2)[0]
	assert.Len(t, []rune(title), 30, "title cut to the DLT variable limit")

	wa := renderAdvisory(ChannelWhatsApp, ClassService, "te", n)
	assert.Contains(t, wa.Body, linkMarker, "WhatsApp always links to the page")
	assert.Contains(t, wa.Body, "పత్తిలో గులాబీ పురుగు")
	assert.Equal(t, platformsms.DLTNoticeLinkTe, wa.TemplateID)

	p := renderAdvisory(ChannelPush, ClassService, "en", n)
	assert.Equal(t, "Pest alert", p.Title)
	assert.Empty(t, p.TemplateID)

	// English requested but missing: Telugu.
	teOnly := noticeText{TitleTe: "శీర్షిక", BodyTe: "వివరం"}
	assert.Equal(t, "శీర్షిక", renderAdvisory(ChannelPush, ClassService, "en", teOnly).Title)
}

func TestVisitAdviceNotice(t *testing.T) {
	a := xmod.VisitAdvice{VisitedAt: time.Date(2026, 10, 29, 4, 0, 0, 0, time.UTC), Items: []xmod.AdviceItem{
		{IssueName: "Pink bollworm", IssueNameTe: "గులాబీ పురుగు", Severity: "high", SaltName: "Emamectin benzoate",
			ProductName: ptr("Shanmukha EMB"), Dose: ptr("80 g/acre")},
		{IssueName: "Aphids", IssueNameTe: "పేను బంక", Severity: "low", SaltName: "Imidacloprid"}, // salt only
	}}
	n, sms := visitAdviceNotice(a, "en")
	require.NotNil(t, n.BodyEn)
	assert.Contains(t, *n.BodyEn, "Shanmukha EMB (Emamectin benzoate), 80 g/acre")
	assert.Contains(t, *n.BodyEn, "Aphids (low): Imidacloprid")
	assert.Contains(t, n.BodyTe, "గులాబీ పురుగు (ఎక్కువ)")
	assert.Contains(t, n.TitleTe, "29-10-2026")
	assert.Contains(t, sms.Body, "2 problem(s)")
	assert.Contains(t, sms.Body, linkMarker)
	assert.Equal(t, platformsms.DLTVisitIssuesEn, sms.TemplateID)

	n, sms = visitAdviceNotice(xmod.VisitAdvice{VisitedAt: a.VisitedAt}, "te")
	assert.Contains(t, n.BodyTe, "ఎలాంటి సమస్యలు")
	assert.NotContains(t, sms.Body, linkMarker)
	assert.Equal(t, platformsms.DLTVisitNoIssuesTe, sms.TemplateID, "no-problem wording has its own DLT template")
}

// FA alerts carry Telugu text; the push goes out in the FA's first language.
func TestFAAlertTextsAreBilingual(t *testing.T) {
	f := xmod.FarmerSummary{Name: ptr("Ramesh"), NameTe: ptr("రమేష్"), Phone: "+919848012345"}
	v := &xmod.Village{Name: "Kondapur", NameTe: ptr("కొండాపూర్")}
	nf := faAlertNewFarmerText(f, v)
	assert.Equal(t, "New farmer: Ramesh", nf.TitleEn)
	assert.Equal(t, "కొత్త రైతు: రమేష్", nf.TitleTe)
	assert.True(t, strings.HasPrefix(nf.BodyTe, "కొండాపూర్. "))
	assert.True(t, strings.HasPrefix(nf.BodyEn, "Kondapur. "))
	cb := faAlertCallbackText(xmod.FarmerSummary{Phone: "+919848012345"})
	assert.Contains(t, cb.TitleTe, "ఒక రైతు")
	assert.Equal(t, "Call back: a farmer", cb.TitleEn)

	assert.Equal(t, "en", faLanguage(xmod.FieldAssistant{Languages: []string{"en", "te"}}))
	assert.Equal(t, "te", faLanguage(xmod.FieldAssistant{Languages: []string{"hi", "te"}}))
	assert.Equal(t, "te", faLanguage(xmod.FieldAssistant{}), "Telugu when unknown")
}

func TestValidateAdvisoryInput(t *testing.T) {
	base := func() AdvisoryInput {
		return AdvisoryInput{TitleTe: " శీర్షిక ", BodyTe: "వివరం", Channels: []string{"sms", "sms", "push"}}
	}
	in := base()
	class, channels, err := validateAdvisoryInput(&in)
	require.NoError(t, err)
	assert.Equal(t, ClassService, class)
	assert.Equal(t, []string{"sms", "push", "in_app"}, channels, "deduped; in_app always on")
	assert.Equal(t, "శీర్షిక", in.TitleTe)
	assert.Equal(t, "ho", in.Sender)
	assert.NotNil(t, in.Target.VillageIDs, "target lists stored as arrays")

	in = base()
	in.NamesProduct = true
	class, _, err = validateAdvisoryInput(&in)
	require.NoError(t, err)
	assert.Equal(t, ClassPromotional, class, "naming a product makes it promotional")

	in = base()
	in.NamesProduct, in.Class = true, ptr(ClassService)
	_, _, err = validateAdvisoryInput(&in)
	assert.True(t, apperr.Is(err, apperr.KindValidation))

	in = base()
	in.TitleTe, in.Channels = "  ", nil
	_, _, err = validateAdvisoryInput(&in)
	e, ok := apperr.As(err)
	require.True(t, ok)
	fields, _ := e.Details["fields"].(map[string]string)
	assert.Contains(t, fields, "title_te")
	assert.Contains(t, fields, "channels")
}

func TestScopeTarget(t *testing.T) {
	d1, d2 := ids.New(), ids.New()
	v1, v2 := ids.New(), ids.New()
	geo := &fakeGeo{villages: map[uuid.UUID]xmod.Village{v1: {ID: v1, DistrictID: d1}, v2: {ID: v2, DistrictID: d2}}}
	s := NewService(testDepsNoDB(), nil, &Ports{Geo: geo})
	ctx := context.Background()

	scoped := testutil.HO(auth.RoleOps, d1)
	tg := Target{}
	require.NoError(t, s.scopeTarget(ctx, scoped, &tg))
	assert.Equal(t, []uuid.UUID{d1}, tg.DistrictIDs, "empty districts become the user's scope")

	tg = Target{DistrictIDs: []uuid.UUID{d2}}
	assert.True(t, apperr.Is(s.scopeTarget(ctx, scoped, &tg), apperr.KindForbidden))

	tg = Target{VillageIDs: []uuid.UUID{v2}}
	assert.True(t, apperr.Is(s.scopeTarget(ctx, scoped, &tg), apperr.KindForbidden), "village in another district")

	tg = Target{VillageIDs: []uuid.UUID{ids.New()}}
	assert.True(t, apperr.Is(s.scopeTarget(ctx, testutil.HO(auth.RoleAdmin), &tg), apperr.KindValidation), "unknown village")

	tg = Target{VillageIDs: []uuid.UUID{v1, v2}}
	require.NoError(t, s.scopeTarget(ctx, testutil.HO(auth.RoleAdmin), &tg), "unscoped user can target anywhere")
	assert.Empty(t, tg.DistrictIDs)

	assert.True(t, visible(testutil.HO(auth.RoleAdmin), AdvisoryRecord{}))
	assert.False(t, visible(scoped, AdvisoryRecord{}), "scoped users don't see all-district advisories")
	assert.True(t, visible(scoped, AdvisoryRecord{Target: Target{DistrictIDs: []uuid.UUID{d1}}}))
	assert.False(t, visible(scoped, AdvisoryRecord{Target: Target{DistrictIDs: []uuid.UUID{d1, d2}}}))
}

func TestEligible(t *testing.T) {
	assert.True(t, eligible(ClassService, xmod.FarmerSummary{Status: "pending_profile"}))
	assert.False(t, eligible(ClassService, xmod.FarmerSummary{Status: "inactive"}))
	assert.True(t, eligible(ClassPromotional, xmod.FarmerSummary{Status: "active", ProgrammeConsent: true}))
	assert.False(t, eligible(ClassPromotional, xmod.FarmerSummary{Status: "active"}), "no programme consent")
	assert.False(t, eligible(ClassPromotional, xmod.FarmerSummary{Status: "pending_profile", ProgrammeConsent: true}))
	assert.Equal(t, skipNoProgrammeConsent, sendBlocked(ClassPromotional, xmod.FarmerSummary{Status: "active"}))
	assert.Equal(t, skipFarmerInactive, sendBlocked(ClassService, xmod.FarmerSummary{Status: "inactive"}))
}

func TestMentionedTerm(t *testing.T) {
	terms := []string{"", "shanmukha boost", "ఇమిడాక్లోప్రిడ్"}
	term, ok := mentionedTerm(terms, ptr("Spray SHANMUKHA Boost today"))
	assert.True(t, ok)
	assert.Equal(t, "shanmukha boost", term)
	term, ok = mentionedTerm(terms, nil, ptr("పత్తిలో ఇమిడాక్లోప్రిడ్ పిచికారీ చేయండి"))
	assert.True(t, ok, "Telugu term")
	assert.Equal(t, "ఇమిడాక్లోప్రిడ్", term)
	_, ok = mentionedTerm(terms, ptr("Check your field"), nil)
	assert.False(t, ok)
}
