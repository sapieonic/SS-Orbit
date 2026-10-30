package messaging

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Every text this module writes lives in this file, in Telugu and English.
// Notices store both languages; SMS, push and WhatsApp are rendered once, in
// the farmer's language, when the delivery row is created.
//
// Indian A2P SMS must match a DLT-registered template. The SMS wordings and
// their template IDs (placeholders until DLT registration) are in
// platform/sms/templates.go, the one list of every SMS the backend sends;
// this file fills their variables.

// linkMarker in a stored delivery body is replaced at send time with a
// freshly signed link to the notice web page (/web/notices/{id} on
// FARMER_WEB_BASE_URL).
const linkMarker = sms.LinkVar

// Length limits for rendered texts (runes).
const (
	whatsAppBodyMax = 600
	pushBodyMax     = 180
)

// noticeText is a notice's bilingual content.
type noticeText struct {
	TitleTe, BodyTe string
	TitleEn, BodyEn *string
}

// message is one rendered delivery.
type message struct {
	Title      string // push only
	Body       string
	TemplateID string
}

// pick returns English when the farmer prefers it and it exists, else Telugu.
func pick(lang, te string, en *string) string {
	if lang == "en" && en != nil && *en != "" {
		return *en
	}
	return te
}

func byLang(lang, te, en string) string {
	if lang == "en" {
		return en
	}
	return te
}

// truncate shortens s to max runes, adding an ellipsis. It reports whether it cut.
func truncate(s string, max int) (string, bool) {
	r := []rune(strings.TrimSpace(s))
	if len(r) <= max {
		return string(r), false
	}
	return strings.TrimSpace(string(r[:max-1])) + "…", true
}

// renderAdvisory renders an advisory notice for one channel in the farmer's
// language. The advisory text is free text, which DLT cannot register, so the
// SMS is a fixed template: the title (cut to the 30-character DLT variable
// limit) and the link to the notice page with the full text and voice note.
// WhatsApp (stubbed as SMS) carries the text and the link.
func renderAdvisory(channel, class, lang string, n noticeText) message {
	title := pick(lang, n.TitleTe, n.TitleEn)
	body := pick(lang, n.BodyTe, n.BodyEn)
	switch channel {
	case ChannelPush:
		b, _ := truncate(body, pushBodyMax)
		return message{Title: title, Body: b}
	case ChannelWhatsApp:
		tpl := sms.NoticeLink.For(lang)
		return message{Body: tpl.Render(map[string]string{"title": title, "body": body}), TemplateID: tpl.ID}
	default: // sms
		tpl := sms.AdvisoryService.For(lang)
		if class == ClassPromotional {
			tpl = sms.AdvisoryPromo.For(lang)
		}
		return message{Body: tpl.Render(map[string]string{"title": title}), TemplateID: tpl.ID}
	}
}

func displayName(f xmod.FarmerSummary, lang string) string {
	if lang != "en" && f.NameTe != nil && *f.NameTe != "" {
		return *f.NameTe
	}
	if f.Name != nil && *f.Name != "" {
		return *f.Name
	}
	if f.NameTe != nil && *f.NameTe != "" {
		return *f.NameTe
	}
	return ""
}

// welcomeNotice is the inbox notice and SMS sent when a farmer registers.
func welcomeNotice(f xmod.FarmerSummary) (noticeText, message) {
	te := sms.Welcome.Te.Render(map[string]string{"name": displayName(f, "te")})
	en := sms.Welcome.En.Render(map[string]string{"name": displayName(f, "en")})
	n := noticeText{TitleTe: "ఆర్బిట్‌కు స్వాగతం", BodyTe: te, TitleEn: ptr("Welcome to Orbit"), BodyEn: ptr(en)}
	return n, message{Body: byLang(f.Language, te, en), TemplateID: sms.Welcome.For(f.Language).ID}
}

// faAssignedNotice tells a farmer who their new field assistant is.
func faAssignedNotice(fa xmod.FieldAssistant, lang string) (noticeText, message) {
	nameTe := fa.Name
	if fa.NameTe != nil && *fa.NameTe != "" {
		nameTe = *fa.NameTe
	}
	te := sms.FAAssigned.Te.Render(map[string]string{"fa_name": nameTe, "fa_phone": fa.Phone})
	en := sms.FAAssigned.En.Render(map[string]string{"fa_name": fa.Name, "fa_phone": fa.Phone})
	n := noticeText{TitleTe: "మీ కొత్త ఫీల్డ్ అసిస్టెంట్", BodyTe: te, TitleEn: ptr("Your new field assistant"), BodyEn: ptr(en)}
	return n, message{Body: byLang(lang, te, en), TemplateID: sms.FAAssigned.For(lang).ID}
}

var severityTe = map[string]string{"low": "తక్కువ", "moderate": "మధ్యస్థం", "high": "ఎక్కువ"}

// visitAdviceNotice lists what the FA found and advised. Only Shanmukha
// products are ever named (ProductName is nil otherwise; salt only).
func visitAdviceNotice(a xmod.VisitAdvice, lang string) (noticeText, message) {
	date := a.VisitedAt.In(ist).Format("02-01-2006")
	var te, en strings.Builder
	for _, it := range a.Items {
		issueTe := it.IssueNameTe
		if issueTe == "" {
			issueTe = it.IssueName
		}
		remedyTe, remedyEn := it.SaltName, it.SaltName
		if it.SaltNameTe != nil && *it.SaltNameTe != "" {
			remedyTe = *it.SaltNameTe
		}
		if it.ProductName != nil {
			remedyEn = *it.ProductName + " (" + it.SaltName + ")"
			remedyTe = *it.ProductName
			if it.ProductNameTe != nil && *it.ProductNameTe != "" {
				remedyTe = *it.ProductNameTe
			}
			remedyTe += " (" + it.SaltName + ")"
		}
		sevTe := severityTe[it.Severity]
		if sevTe == "" {
			sevTe = it.Severity
		}
		fmt.Fprintf(&te, "• %s (%s): %s", issueTe, sevTe, remedyTe)
		fmt.Fprintf(&en, "• %s (%s): %s", it.IssueName, it.Severity, remedyEn)
		if it.DoseTe != nil && *it.DoseTe != "" {
			fmt.Fprintf(&te, ", %s", *it.DoseTe)
		} else if it.Dose != nil && *it.Dose != "" {
			fmt.Fprintf(&te, ", %s", *it.Dose)
		}
		if it.Dose != nil && *it.Dose != "" {
			fmt.Fprintf(&en, ", %s", *it.Dose)
		}
		te.WriteString("\n")
		en.WriteString("\n")
	}
	bodyTe, bodyEn := strings.TrimSpace(te.String()), strings.TrimSpace(en.String())
	// Two wordings, two DLT templates: problems found (with the advice link)
	// or nothing found.
	tpl := sms.VisitIssues
	if len(a.Items) == 0 {
		bodyTe = "మీ పొలంలో ఎలాంటి సమస్యలు కనిపించలేదు."
		bodyEn = "No problems were found on your farm."
		tpl = sms.VisitNoIssues
	}
	vars := map[string]string{"date": date, "count": strconv.Itoa(len(a.Items))}
	n := noticeText{
		TitleTe: fmt.Sprintf("పొలం సందర్శన సలహా (%s)", date), BodyTe: bodyTe,
		TitleEn: ptr(fmt.Sprintf("Advice from your farm visit (%s)", date)), BodyEn: ptr(bodyEn),
	}
	t := tpl.For(lang)
	return n, message{Body: t.Render(vars), TemplateID: t.ID}
}

// FA alert texts, in English (title/body) and Telugu (title_te/body_te). The
// FA app shows the FA's first language; the push goes out in it too.

// faAlertText is an FA alert in both languages.
type faAlertText struct {
	TitleEn, BodyEn string
	TitleTe, BodyTe string
}

func faAlertNewFarmerText(f xmod.FarmerSummary, v *xmod.Village) faAlertText {
	nameEn, nameTe := displayName(f, "en"), displayName(f, "te")
	if nameEn == "" {
		nameEn = "a farmer"
	}
	if nameTe == "" {
		nameTe = "ఒక రైతు"
	}
	t := faAlertText{
		TitleEn: "New farmer: " + nameEn,
		BodyEn:  "Signed up on the farmer app. Please call and plan a visit. Phone: " + f.Phone,
		TitleTe: "కొత్త రైతు: " + nameTe,
		BodyTe:  "రైతు యాప్‌లో నమోదు చేసుకున్నారు. దయచేసి ఫోన్ చేసి సందర్శన ప్లాన్ చేయండి. ఫోన్: " + f.Phone,
	}
	if v != nil {
		villageTe := v.Name
		if v.NameTe != nil && *v.NameTe != "" {
			villageTe = *v.NameTe
		}
		t.BodyEn = v.Name + ". " + t.BodyEn
		t.BodyTe = villageTe + ". " + t.BodyTe
	}
	return t
}

func faAlertCallbackText(f xmod.FarmerSummary) faAlertText {
	nameEn, nameTe := displayName(f, "en"), displayName(f, "te")
	if nameEn == "" {
		nameEn = "a farmer"
	}
	if nameTe == "" {
		nameTe = "ఒక రైతు"
	}
	return faAlertText{
		TitleEn: "Call back: " + nameEn,
		BodyEn:  "Asked you to call back. Phone: " + f.Phone,
		TitleTe: "తిరిగి ఫోన్ చేయండి: " + nameTe,
		BodyTe:  "మీరు తిరిగి ఫోన్ చేయాలని కోరారు. ఫోన్: " + f.Phone,
	}
}

// faLanguage is the FA's first language ("te" or "en"); Telugu when unknown.
func faLanguage(fa xmod.FieldAssistant) string {
	for _, l := range fa.Languages {
		switch l {
		case "te", "en":
			return l
		}
	}
	return "te"
}

func ptr[T any](v T) *T { return &v }
