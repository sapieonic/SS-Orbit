package masters

import (
	"fmt"
	"time"
)

// Season codes (crop_seasons.season_code), one rule for the whole backend.
// Telangana / AP calendar, by IST date:
//
//	summer-YYYY     1 Apr - 31 May  (summer-2027)
//	kharif-YYYY     1 Jun - 31 Oct  (kharif-2026)
//	rabi-YYYY-YY    1 Nov - 31 Mar  (rabi-2026-27; YYYY is the November's year)
//
// This matches the wireframes ("Rabi 2026-27", premium "valid till 31 Mar
// 2027") and the pattern the farmers module accepts
// (^[a-z]+-[0-9]{4}(-[0-9]{2})?$).

// ist is India Standard Time; a fixed zone so the rule does not depend on the
// container having tzdata.
var ist = time.FixedZone("IST", 5*3600+1800)

// SeasonCodeSet is the season codes the apps offer when a season is started.
// AllOpen is previous, current and next, oldest first: a crop sown last season
// is often still standing (kharif cotton is picked into January), and farmers
// plan the next one early. ValidUntil is the last IST day of Current, so an
// app holding an old snapshot knows when to recompute.
type SeasonCodeSet struct {
	Current    string   `json:"current"`
	Next       string   `json:"next"`
	AllOpen    []string `json:"all_open"`
	ValidUntil string   `json:"valid_until"` // YYYY-MM-DD
}

// season is one season of the calendar: kind and the calendar year it starts in.
type season struct {
	kind string // summer | kharif | rabi
	year int
}

func (s season) code() string {
	if s.kind == "rabi" {
		return fmt.Sprintf("rabi-%d-%02d", s.year, (s.year+1)%100)
	}
	return fmt.Sprintf("%s-%d", s.kind, s.year)
}

// last is the season's last day.
func (s season) last() time.Time {
	switch s.kind {
	case "summer":
		return time.Date(s.year, time.May, 31, 0, 0, 0, 0, time.UTC)
	case "kharif":
		return time.Date(s.year, time.October, 31, 0, 0, 0, 0, time.UTC)
	default:
		return time.Date(s.year+1, time.March, 31, 0, 0, 0, 0, time.UTC)
	}
}

func (s season) next() season {
	switch s.kind {
	case "summer":
		return season{"kharif", s.year}
	case "kharif":
		return season{"rabi", s.year}
	default:
		return season{"summer", s.year + 1}
	}
}

func (s season) prev() season {
	switch s.kind {
	case "summer":
		return season{"rabi", s.year - 1}
	case "kharif":
		return season{"summer", s.year}
	default:
		return season{"kharif", s.year}
	}
}

// seasonOn is the season containing the IST date of t.
func seasonOn(t time.Time) season {
	d := t.In(ist)
	switch m := d.Month(); {
	case m >= time.April && m <= time.May:
		return season{"summer", d.Year()}
	case m >= time.June && m <= time.October:
		return season{"kharif", d.Year()}
	case m >= time.November:
		return season{"rabi", d.Year()}
	default: // January - March belong to the rabi that started last November
		return season{"rabi", d.Year() - 1}
	}
}

// SeasonCodesAt returns the season codes for the moment t (IST calendar).
func SeasonCodesAt(t time.Time) SeasonCodeSet {
	cur := seasonOn(t)
	return SeasonCodeSet{
		Current:    cur.code(),
		Next:       cur.next().code(),
		AllOpen:    []string{cur.prev().code(), cur.code(), cur.next().code()},
		ValidUntil: cur.last().Format(time.DateOnly),
	}
}
