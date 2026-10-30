package messaging

import "time"

// ist is India Standard Time (no DST).
var ist = time.FixedZone("IST", 5*60*60+30*60)

// Quiet hours for SMS, push and WhatsApp: 21:00 to 07:00 IST. In-app notices
// are not affected; OTP and payment messages are sent by other modules.
const (
	quietStartHour = 21
	quietEndHour   = 7
)

// sendAfterQuietHours returns when a message due at t may be sent: t itself
// outside quiet hours, otherwise the next 07:00 IST. The result is UTC.
func sendAfterQuietHours(t time.Time) time.Time {
	l := t.In(ist)
	switch h := l.Hour(); {
	case h >= quietStartHour:
		next := l.AddDate(0, 0, 1)
		return time.Date(next.Year(), next.Month(), next.Day(), quietEndHour, 0, 0, 0, ist).UTC()
	case h < quietEndHour:
		return time.Date(l.Year(), l.Month(), l.Day(), quietEndHour, 0, 0, 0, ist).UTC()
	default:
		return t.UTC()
	}
}
