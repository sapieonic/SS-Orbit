package farmers

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// ist is India Standard Time. Days after sowing count calendar days in India,
// not UTC, so a farmer's "day 1" starts at local midnight.
var ist = time.FixedZone("IST", 5*3600+30*60)

// daysAfterSowing returns the calendar days from sowing to now in IST (the
// sowing day is day 0). Negative when the sowing date is in the future.
func daysAfterSowing(sowing, now time.Time) int {
	t := now.In(ist)
	today := time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	sown := time.Date(sowing.Year(), sowing.Month(), sowing.Day(), 0, 0, 0, 0, time.UTC)
	return int(today.Sub(sown).Hours() / 24)
}

// stageCache memoises masters stage lookups per (crop, day) for one request:
// targeting asks for the same few crops and days over and over.
type stageCache struct {
	masters MastersPort
	m       map[stageKey]*xmod.Stage
}

type stageKey struct {
	crop uuid.UUID
	day  int
}

func newStageCache(m MastersPort) *stageCache {
	return &stageCache{masters: m, m: map[stageKey]*xmod.Stage{}}
}

// get returns the stage for the crop on that day, or nil when masters has
// none (before sowing, past the last stage, or no stages for the crop).
func (c *stageCache) get(ctx context.Context, cropID uuid.UUID, day int) (*xmod.Stage, error) {
	if day < 0 || c.masters == nil {
		return nil, nil
	}
	k := stageKey{cropID, day}
	if st, ok := c.m[k]; ok {
		return st, nil
	}
	st, err := c.masters.GetStagesForDay(ctx, cropID, day)
	var out *xmod.Stage
	switch {
	case err == nil:
		out = &st
	case apperr.Is(err, apperr.KindNotFound):
		out = nil
	default:
		return nil, err
	}
	c.m[k] = out
	return out, nil
}
