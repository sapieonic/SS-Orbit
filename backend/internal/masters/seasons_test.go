package masters

import (
	"regexp"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestSeasonCodesAt(t *testing.T) {
	istAt := func(y int, m time.Month, d, h, min int) time.Time {
		return time.Date(y, m, d, h, min, 0, 0, ist).UTC()
	}
	cases := []struct {
		name      string
		at        time.Time
		want      SeasonCodeSet
		wantUntil string
	}{
		{"mid kharif", istAt(2026, time.October, 30, 12, 0), SeasonCodeSet{
			Current: "kharif-2026", Next: "rabi-2026-27", AllOpen: []string{"summer-2026", "kharif-2026", "rabi-2026-27"}, ValidUntil: "2026-10-31"}, ""},
		{"rabi starts 1 Nov IST (still 31 Oct UTC)", istAt(2026, time.November, 1, 0, 10), SeasonCodeSet{
			Current: "rabi-2026-27", Next: "summer-2027", AllOpen: []string{"kharif-2026", "rabi-2026-27", "summer-2027"}, ValidUntil: "2027-03-31"}, ""},
		{"January is last November's rabi", istAt(2027, time.January, 15, 9, 0), SeasonCodeSet{
			Current: "rabi-2026-27", Next: "summer-2027", AllOpen: []string{"kharif-2026", "rabi-2026-27", "summer-2027"}, ValidUntil: "2027-03-31"}, ""},
		{"last minute of rabi", istAt(2027, time.March, 31, 23, 59), SeasonCodeSet{
			Current: "rabi-2026-27", Next: "summer-2027", AllOpen: []string{"kharif-2026", "rabi-2026-27", "summer-2027"}, ValidUntil: "2027-03-31"}, ""},
		{"summer", istAt(2027, time.April, 1, 0, 0), SeasonCodeSet{
			Current: "summer-2027", Next: "kharif-2027", AllOpen: []string{"rabi-2026-27", "summer-2027", "kharif-2027"}, ValidUntil: "2027-05-31"}, ""},
		{"kharif starts 1 Jun", istAt(2027, time.June, 1, 6, 0), SeasonCodeSet{
			Current: "kharif-2027", Next: "rabi-2027-28", AllOpen: []string{"summer-2027", "kharif-2027", "rabi-2027-28"}, ValidUntil: "2027-10-31"}, ""},
		{"century rollover", istAt(2099, time.December, 1, 0, 0), SeasonCodeSet{
			Current: "rabi-2099-00", Next: "summer-2100", AllOpen: []string{"kharif-2099", "rabi-2099-00", "summer-2100"}, ValidUntil: "2100-03-31"}, ""},
	}
	// Every code fits the farmers module's season_code pattern.
	pattern := regexp.MustCompile(`^[a-z]+-[0-9]{4}(-[0-9]{2})?$`)
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := SeasonCodesAt(c.at)
			assert.Equal(t, c.want, got)
			for _, code := range got.AllOpen {
				assert.Regexp(t, pattern, code)
			}
		})
	}
}
