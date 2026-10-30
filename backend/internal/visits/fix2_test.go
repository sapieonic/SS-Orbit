package visits

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// Regression tests for the second gap-fix round: farmer names on HO visit
// screens, and the overview counts (district filter, daily series).

func TestAdminVisitsCarryFarmerAndVillage(t *testing.T) {
	w := newWorld(t)
	s := w.farmers.m[w.farmer1]
	name, nameTe := "Anil R", "అనిల్"
	s.Name, s.NameTe, s.Phone = &name, &nameTe, "+919848011111"
	w.farmers.m[w.farmer1] = s
	logged := ids.New()
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdLogVisit, w.logPayload(logged)).Status)

	ops := testutil.Ctx(testutil.HO(auth.RoleOps))
	page, err := w.svc.List(ops, ListFilter{}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	f := page.Items[0].Farmer
	require.NotNil(t, f)
	assert.Equal(t, "Anil R", *f.Name)
	assert.Equal(t, "అనిల్", *f.NameTe)
	assert.Equal(t, "+91******1111", f.PhoneMasked)
	assert.Equal(t, w.village, *f.VillageID)
	assert.Equal(t, "Kondapur", *f.VillageName)

	d, err := w.svc.Get(ops, logged)
	require.NoError(t, err)
	require.NotNil(t, d.Visit.Farmer)
	assert.Equal(t, "Anil R", *d.Visit.Farmer.Name)

	// The JSON has the fields, and never the full phone number.
	raw, err := json.Marshal(toVisitDTO(d.Visit))
	require.NoError(t, err)
	var m map[string]any
	require.NoError(t, json.Unmarshal(raw, &m))
	assert.Equal(t, "Anil R", m["farmer_name"])
	assert.Equal(t, "Kondapur", m["village_name"])
	assert.NotContains(t, string(raw), "9848011111")

	// A farmers lookup failure leaves the names out, the list still loads.
	w.svc.ports.Farmers = nil
	page, err = w.svc.List(ops, ListFilter{}, nil, nil)
	require.NoError(t, err)
	assert.Nil(t, page.Items[0].Farmer)
}

func TestVisitCountsDistrictAndDailySeries(t *testing.T) {
	w := newWorld(t)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdPlanVisit, w.planPayload(ids.New(), "2026-10-28")).Status)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdPlanVisit, w.planPayload(ids.New(), "2026-10-31")).Status)
	require.Equal(t, commands.StatusApplied, w.send(w.fa1, CmdLogVisit, w.logPayload(ids.New())).Status) // 30 Oct

	from, to := time.Date(2026, 10, 27, 0, 0, 0, 0, time.UTC), time.Date(2026, 11, 2, 0, 0, 0, 0, time.UTC)
	finance := testutil.Ctx(testutil.HO(auth.RoleFinance))

	c, err := w.svc.Counts(finance, from, to, CountsFilter{})
	require.NoError(t, err)
	assert.Nil(t, c.Days, "no series unless asked")

	c, err = w.svc.Counts(finance, from, to, CountsFilter{ByDay: true})
	require.NoError(t, err)
	require.Len(t, c.Days, 7, "every day of the range, zero-filled")
	day := func(d int) DayCounts { return c.Days[d-27] }
	assert.Equal(t, time.Date(2026, 10, 27, 0, 0, 0, 0, time.UTC), c.Days[0].Date)
	assert.Equal(t, DayCounts{Date: day(28).Date, Planned: 1, Missed: 1}, day(28), "planned in the past, not logged")
	assert.Equal(t, DayCounts{Date: day(30).Date, Done: 1}, day(30))
	assert.Equal(t, DayCounts{Date: day(31).Date, Planned: 1}, day(31))
	assert.Equal(t, DayCounts{Date: day(29).Date}, day(29))
	total := DayCounts{}
	for _, d := range c.Days {
		total.Planned += d.Planned
		total.Done += d.Done
		total.Missed += d.Missed
	}
	require.Len(t, c.Items, 1)
	assert.Equal(t, c.Items[0].Planned, total.Planned, "the series adds up to the per-FA numbers")
	assert.Equal(t, c.Items[0].Done, total.Done)
	assert.Equal(t, c.Items[0].Missed, total.Missed)

	// District filter.
	c, err = w.svc.Counts(finance, from, to, CountsFilter{DistrictID: &w.district, ByDay: true})
	require.NoError(t, err)
	assert.Len(t, c.Items, 1)
	other := ids.New()
	c, err = w.svc.Counts(finance, from, to, CountsFilter{DistrictID: &other, ByDay: true})
	require.NoError(t, err)
	assert.Empty(t, c.Items)
	assert.Len(t, c.Days, 7)
	assert.Equal(t, DayCounts{Date: c.Days[3].Date}, c.Days[3])
	_, err = w.svc.Counts(testutil.Ctx(testutil.HO(auth.RoleFinance, other)), from, to, CountsFilter{DistrictID: &w.district})
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "scoped users only ask for their districts")
}
