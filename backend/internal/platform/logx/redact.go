package logx

import "regexp"

var (
	// linkTokenRe matches a signed link token in a URL query (?t=... or &t=...).
	linkTokenRe = regexp.MustCompile(`([?&]t=)[^\s&#"']+`)
	// digitRunRe matches runs of 4+ ASCII digits: OTP codes, but also phone
	// numbers and amounts, which are fine to hide in logs too.
	digitRunRe = regexp.MustCompile(`[0-9]{4,}`)
)

// Redact hides the secrets that outgoing SMS and push texts may carry (OTP
// codes, signed web-link tokens) so message bodies can be logged outside dev.
func Redact(s string) string {
	s = linkTokenRe.ReplaceAllString(s, "${1}[redacted]")
	return digitRunRe.ReplaceAllString(s, "****")
}
