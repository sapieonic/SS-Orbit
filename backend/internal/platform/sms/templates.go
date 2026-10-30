package sms

import (
	"regexp"
	"strings"
)

// Every SMS the backend sends is rendered from a template in this file, so the
// whole DLT registration list lives in one place (identity's OTPs and
// messaging's notices both use it).
//
// Indian A2P SMS must match a DLT-registered template: one template, with its
// own 19-digit ID, per distinct wording and per language. The registered text
// must match Text below with each {variable} registered as {#var#}.
//
// ALL IDs BELOW ARE PLACEHOLDERS (prefix 1107000000000000) until DLT
// registration is done; replace them with the real IDs from the DLT portal.
// IsPlaceholder reports whether an ID is still one.

// DLT template IDs, one per wording and language. PLACEHOLDERS.
const (
	DLTAdvisoryServiceTe   = "1107000000000000101" // PLACEHOLDER
	DLTAdvisoryServiceEn   = "1107000000000000102" // PLACEHOLDER
	DLTAdvisoryPromoTe     = "1107000000000000103" // PLACEHOLDER
	DLTAdvisoryPromoEn     = "1107000000000000104" // PLACEHOLDER
	DLTNoticeLinkTe        = "1107000000000000105" // PLACEHOLDER; WhatsApp stub sent as SMS
	DLTNoticeLinkEn        = "1107000000000000106" // PLACEHOLDER
	DLTWelcomeTe           = "1107000000000000107" // PLACEHOLDER
	DLTWelcomeEn           = "1107000000000000108" // PLACEHOLDER
	DLTFAAssignedTe        = "1107000000000000109" // PLACEHOLDER
	DLTFAAssignedEn        = "1107000000000000110" // PLACEHOLDER
	DLTVisitIssuesTe       = "1107000000000000111" // PLACEHOLDER; visit found problems
	DLTVisitIssuesEn       = "1107000000000000112" // PLACEHOLDER
	DLTVisitNoIssuesTe     = "1107000000000000113" // PLACEHOLDER; visit found nothing
	DLTVisitNoIssuesEn     = "1107000000000000114" // PLACEHOLDER
	DLTLoginOTPTe          = "1107000000000000115" // PLACEHOLDER
	DLTLoginOTPEn          = "1107000000000000116" // PLACEHOLDER
	DLTLoginOTPRetrieverTe = "1107000000000000117" // PLACEHOLDER; with the Android app hash
	DLTLoginOTPRetrieverEn = "1107000000000000118" // PLACEHOLDER
	DLTConsentOTPTe        = "1107000000000000119" // PLACEHOLDER
	DLTConsentOTPEn        = "1107000000000000120" // PLACEHOLDER
)

// placeholderPrefix marks the made-up IDs above.
const placeholderPrefix = "1107000000000000"

// IsPlaceholder reports whether id is one of the made-up IDs (not registered).
func IsPlaceholder(id string) bool { return strings.HasPrefix(id, placeholderPrefix) }

// Template is one DLT-registered wording in one language.
type Template struct {
	Key  string // stable name shared by both languages, e.g. "login_otp"
	Lang string // "te" or "en"
	ID   string // DLT template ID
	// Text is the registered wording. {name} marks a variable. {link} is left
	// in place by Render: messaging replaces it with a signed link at send time.
	Text string
	// Max caps variables (runes); a longer value is cut with "…". DLT
	// variables are short (30 characters is the usual limit).
	Max map[string]int
}

// Pair is a template in both languages.
type Pair struct{ Te, En Template }

// For returns the English template for "en" and Telugu otherwise (Telugu first).
func (p Pair) For(lang string) Template {
	if lang == "en" {
		return p.En
	}
	return p.Te
}

// LinkVar is the variable messaging fills with the notice page link at send time.
const LinkVar = "{link}"

// The templates. Lengths: Telugu goes as Unicode SMS (70 characters in one
// part, 67 per part after that), English as GSM-7 (160 / 153).
var (
	// LoginOTP is the farmer sign-in code. Telugu: 2 parts with a 6-digit code.
	LoginOTP = Pair{
		Te: Template{Key: "login_otp", Lang: "te", ID: DLTLoginOTPTe,
			Text: "{code} మీ Orbit Shifting లాగిన్ కోడ్. {minutes} నిమిషాలు చెల్లుతుంది. ఎవరితోనూ పంచుకోవద్దు."},
		En: Template{Key: "login_otp", Lang: "en", ID: DLTLoginOTPEn,
			Text: "{code} is your Orbit Shifting sign-in code. Valid for {minutes} minutes. Do not share it with anyone."},
	}
	// LoginOTPRetriever is LoginOTP in the Android SMS Retriever format: "<#>"
	// first and the app's 11-character hash on the last line, so the farmer
	// app reads the code without a tap. Telugu fits one part (63 characters).
	LoginOTPRetriever = Pair{
		Te: Template{Key: "login_otp_retriever", Lang: "te", ID: DLTLoginOTPRetrieverTe,
			Text: "<#> {code} మీ Orbit లాగిన్ కోడ్. ఎవరికీ చెప్పవద్దు.\n{app_hash}"},
		En: Template{Key: "login_otp_retriever", Lang: "en", ID: DLTLoginOTPRetrieverEn,
			Text: "<#> {code} is your Orbit Shifting sign-in code. Valid for {minutes} minutes. Do not share it.\n{app_hash}"},
	}
	// ConsentOTP is the code a farmer tells the FA to consent at enrolment (FAR-04).
	ConsentOTP = Pair{
		Te: Template{Key: "consent_otp", Lang: "te", ID: DLTConsentOTPTe,
			Text: "{code} మీ Orbit Shifting అంగీకార కోడ్. మీరు ఈ కార్యక్రమంలో చేరడానికి, మీ పొలం వివరాలను షణ్ముఖ అగ్రిటెక్‌తో " +
				"పంచుకోవడానికి అంగీకరిస్తేనే ఈ కోడ్‌ను ఫీల్డ్ అసిస్టెంట్‌కు చెప్పండి. {minutes} నిమిషాలు చెల్లుతుంది."},
		En: Template{Key: "consent_otp", Lang: "en", ID: DLTConsentOTPEn,
			Text: "{code} is your Orbit Shifting consent code. Tell it to the Field Assistant only if you agree to join " +
				"the programme and share your farm details with Shanmukha Agritec. Valid for {minutes} minutes."},
	}
	// AdvisoryService and AdvisoryPromo carry an advisory as a short title and
	// the link to the full text and voice note on the farmer web page. The
	// advisory body is free text, which DLT cannot register, so it is not in
	// the SMS. Promotional (names a product) is a separate DLT category.
	AdvisoryService = Pair{
		Te: Template{Key: "advisory_service", Lang: "te", ID: DLTAdvisoryServiceTe, Max: titleMax,
			Text: "{title}. పూర్తి సలహా వినండి / చదవండి: {link}"},
		En: Template{Key: "advisory_service", Lang: "en", ID: DLTAdvisoryServiceEn, Max: titleMax,
			Text: "{title}. Read or listen to the full advice: {link}"},
	}
	AdvisoryPromo = Pair{
		Te: Template{Key: "advisory_promo", Lang: "te", ID: DLTAdvisoryPromoTe, Max: titleMax,
			Text: "{title}. ఉత్పత్తి సలహా వినండి / చదవండి: {link}"},
		En: Template{Key: "advisory_promo", Lang: "en", ID: DLTAdvisoryPromoEn, Max: titleMax,
			Text: "{title}. Read or listen to the product advice: {link}"},
	}
	// NoticeLink is the WhatsApp message (stubbed as SMS until a WhatsApp BSP
	// is chosen; WhatsApp templates are registered with the BSP, not DLT).
	NoticeLink = Pair{
		Te: Template{Key: "notice_link", Lang: "te", ID: DLTNoticeLinkTe, Max: map[string]int{"body": 600},
			Text: "{title}\n{body}\nవినండి / చదవండి: {link}"},
		En: Template{Key: "notice_link", Lang: "en", ID: DLTNoticeLinkEn, Max: map[string]int{"body": 600},
			Text: "{title}\n{body}\nListen / read: {link}"},
	}
	// Welcome is sent when a farmer registers. {name} may be empty.
	Welcome = Pair{
		Te: Template{Key: "welcome", Lang: "te", ID: DLTWelcomeTe, Max: nameMax,
			Text: "నమస్కారం {name}, ఆర్బిట్‌లో మీ నమోదు పూర్తయింది. పంట సలహాలు యాప్‌లో, SMS ద్వారా అందుతాయి."},
		En: Template{Key: "welcome", Lang: "en", ID: DLTWelcomeEn, Max: nameMax,
			Text: "Hello {name}, you are now registered with Orbit. You will get crop advice in the app and by SMS."},
	}
	// FAAssigned introduces a farmer's new field assistant.
	FAAssigned = Pair{
		Te: Template{Key: "fa_assigned", Lang: "te", ID: DLTFAAssignedTe, Max: map[string]int{"fa_name": 30},
			Text: "మీ కొత్త ఫీల్డ్ అసిస్టెంట్ {fa_name}. ఫోన్: {fa_phone}"},
		En: Template{Key: "fa_assigned", Lang: "en", ID: DLTFAAssignedEn, Max: map[string]int{"fa_name": 30},
			Text: "Your new field assistant is {fa_name}. Phone: {fa_phone}"},
	}
	// VisitIssues and VisitNoIssues follow a logged visit.
	VisitIssues = Pair{
		Te: Template{Key: "visit_issues", Lang: "te", ID: DLTVisitIssuesTe,
			Text: "{date} న మీ పొలం సందర్శనలో {count} సమస్యలు గుర్తించాం. సలహా చూడండి: {link}"},
		En: Template{Key: "visit_issues", Lang: "en", ID: DLTVisitIssuesEn,
			Text: "Your field assistant visited your farm on {date} and found {count} problem(s). See the advice: {link}"},
	}
	VisitNoIssues = Pair{
		Te: Template{Key: "visit_no_issues", Lang: "te", ID: DLTVisitNoIssuesTe,
			Text: "{date} న మీ పొలం సందర్శించాం. ఎలాంటి సమస్యలు కనిపించలేదు."},
		En: Template{Key: "visit_no_issues", Lang: "en", ID: DLTVisitNoIssuesEn,
			Text: "Your field assistant visited your farm on {date}. No problems were found."},
	}
)

var (
	titleMax = map[string]int{"title": 30}
	nameMax  = map[string]int{"name": 30}
)

// All lists every template (both languages), for the DLT export and tests.
func All() []Template {
	var out []Template
	for _, p := range []Pair{LoginOTP, LoginOTPRetriever, ConsentOTP, AdvisoryService, AdvisoryPromo,
		NoticeLink, Welcome, FAAssigned, VisitIssues, VisitNoIssues} {
		out = append(out, p.Te, p.En)
	}
	return out
}

var varRe = regexp.MustCompile(`\{[a-z_]+\}`)

// Vars returns the template's variable names in order, e.g. ["code", "minutes"].
func (t Template) Vars() []string {
	var out []string
	for _, m := range varRe.FindAllString(t.Text, -1) {
		out = append(out, m[1:len(m)-1])
	}
	return out
}

// Render fills the variables in vars. Values are trimmed and cut to Max. An
// empty value also drops the space before it ("Hello {name}," -> "Hello,").
// Variables not in vars (normally {link}) are left as they are.
func (t Template) Render(vars map[string]string) string {
	out := varRe.ReplaceAllStringFunc(t.Text, func(m string) string {
		name := m[1 : len(m)-1]
		v, ok := vars[name]
		if !ok {
			return m
		}
		v = strings.TrimSpace(v)
		if n := t.Max[name]; n > 0 {
			v = cut(v, n)
		}
		if v == "" {
			return emptyMark
		}
		return v
	})
	out = strings.ReplaceAll(out, " "+emptyMark, "")
	return strings.ReplaceAll(out, emptyMark, "")
}

// emptyMark stands in for an empty variable until the space before it is removed.
const emptyMark = "\x00"

// cut shortens s to max runes, ending with an ellipsis when it cuts.
func cut(s string, max int) string {
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return strings.TrimSpace(string(r[:max-1])) + "…"
}
