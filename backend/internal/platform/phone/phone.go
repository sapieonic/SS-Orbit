// Package phone normalises Indian mobile numbers to E.164 (+91XXXXXXXXXX).
// Every phone number stored or compared anywhere in the backend goes through
// Normalize first, so self sign-up and FA enrolment merge on the same value.
package phone

import (
	"errors"
	"strings"
)

// ErrInvalid is returned for anything that is not a valid Indian mobile number.
var ErrInvalid = errors.New("phone: not a valid Indian mobile number")

// Normalize accepts common Indian formats ("98480 12345", "098480-12345",
// "+91 98480 12345", "919848012345", "0091 9848012345") and returns
// "+919848012345". Mobile numbers have 10 digits starting with 6-9.
func Normalize(s string) (string, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return "", ErrInvalid
	}
	var b strings.Builder
	plus := false
	for _, r := range s {
		switch {
		case r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == '+' && !plus && b.Len() == 0:
			plus = true // leading + is fine; country code checked below
		case r == ' ' || r == '-' || r == '(' || r == ')' || r == '.':
			// separators
		default:
			return "", ErrInvalid
		}
	}
	d := b.String()
	switch {
	case len(d) == 10:
	case len(d) == 11 && d[0] == '0':
		d = d[1:]
	case len(d) == 12 && strings.HasPrefix(d, "91"):
		d = d[2:]
	case len(d) == 14 && strings.HasPrefix(d, "0091"):
		d = d[4:]
	default:
		return "", ErrInvalid
	}
	if d[0] < '6' || d[0] > '9' {
		return "", ErrInvalid
	}
	return "+91" + d, nil
}

// Mask hides all but the last four digits, for logs and HO list views:
// "+919848012345" -> "+91******2345".
func Mask(e164 string) string {
	if len(e164) < 7 {
		return "****"
	}
	return e164[:3] + strings.Repeat("*", len(e164)-7) + e164[len(e164)-4:]
}
