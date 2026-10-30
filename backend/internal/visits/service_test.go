package visits

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Unit tests: rules that are decided before the database is touched. The
// service has no pool here, so reaching the database would panic.

func unitService(farmers *fakeFarmers) *Service {
	return NewService(platform.Deps{Clock: clock.NewFake(now)}, &Ports{Farmers: farmers, Masters: &fakeMasters{}})
}

func dispatch(t *testing.T, svc *Service, p auth.Principal, typ string, payload any) commands.Result {
	t.Helper()
	reg := commands.NewRegistry()
	(&Module{svc: svc}).RegisterCommands(reg)
	raw, err := json.Marshal(payload)
	require.NoError(t, err)
	res, err := reg.Dispatch(testutil.Ctx(p), p, commands.Command{ID: ids.New(), Type: typ, Payload: raw})
	require.NoError(t, err)
	return res
}

func TestCommandsRejectBeforeTheDatabase(t *testing.T) {
	fa, farmer := testutil.FA(), ids.New()
	farmers := &fakeFarmers{m: map[uuid.UUID]xmod.FarmerSummary{}}
	farmers.assign(farmer, ids.New()) // someone else's farmer
	svc := unitService(farmers)
	plan := map[string]any{
		"visit_id": ids.New(), "farmer_id": farmer, "plot_id": ids.New(), "season_id": ids.New(),
		"planned_for": "2026-11-01", "planned_slot": "any",
	}
	log := map[string]any{
		"visit_id": ids.New(), "farmer_id": farmer, "plot_id": ids.New(), "season_id": ids.New(),
		"visited_at": now.Format(time.RFC3339), "farmer_present": true,
	}
	cases := []struct {
		name    string
		p       auth.Principal
		typ     string
		payload any
		reason  string
	}{
		{"HO cannot send commands", testutil.HO(auth.RoleAdmin), CmdPlanVisit, plan, "only a field assistant"},
		{"farmer of another FA", fa, CmdPlanVisit, plan, "not assigned to you"},
		{"unknown farmer", fa, CmdPlanVisit, merge(plan, "farmer_id", ids.New()), "farmer not found"},
		{"missing ids", fa, CmdPlanVisit, merge(plan, "plot_id", uuid.Nil), "required"},
		{"log without visited_at", fa, CmdLogVisit, merge(log, "visited_at", nil), "visited_at is required"},
		{"bad severity", fa, CmdLogVisit, merge(log, "issues", []map[string]any{{"issue_visit_id": ids.New(), "issue_id": ids.New(), "severity": "severe"}}), "severity"},
		{"location without lng", fa, CmdLogVisit, merge(log, "location", map[string]any{"lat": 17.4}), "lat and lng"},
		{"next visit reuses the visit id", fa, CmdLogVisit, merge(log, "next_visit", map[string]any{"visit_id": log["visit_id"], "planned_for": "2026-11-01", "planned_slot": "any"}), "new visit ID"},
		{"undecodable payload", fa, CmdCancelVisit, map[string]any{"visit_id": 42}, "invalid payload"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			res := dispatch(t, svc, c.p, c.typ, c.payload)
			require.Equal(t, commands.StatusRejected, res.Status)
			assert.Contains(t, *res.Error, c.reason)
		})
	}
}

func merge(m map[string]any, k string, v any) map[string]any {
	out := map[string]any{}
	for kk, vv := range m {
		out[kk] = vv
	}
	if v == nil {
		delete(out, k)
	} else {
		out[k] = v
	}
	return out
}

func TestCommandResult(t *testing.T) {
	id := ids.New()
	res, err := commandResult(id, nil)
	require.NoError(t, err)
	assert.Equal(t, commands.Applied(id), res)

	res, err = commandResult(id, &pgconn.PgError{Code: "23503", ConstraintName: "visits_season_id_plot_id_farmer_id_fkey"})
	require.NoError(t, err)
	assert.Equal(t, commands.StatusRejected, res.Status)
	assert.Contains(t, *res.Error, "does not belong to this farmer and plot")

	res, err = commandResult(id, &pgconn.PgError{Code: "23503", ConstraintName: "visits_stage_id_fkey"})
	require.NoError(t, err)
	assert.Equal(t, "unknown crop stage", *res.Error)

	res, err = commandResult(id, apperr.Forbidden("nope"))
	require.NoError(t, err)
	assert.Equal(t, commands.StatusRejected, res.Status)

	_, err = commandResult(id, errors.New("connection reset"))
	assert.Error(t, err, "infrastructure errors are retried by sync")
}

func TestAdminAuthorization(t *testing.T) {
	svc := unitService(nil)
	day := now
	cases := []struct {
		name string
		ctx  context.Context
		kind apperr.Kind
	}{
		{"no principal", context.Background(), apperr.KindUnauthorized},
		{"fa", testutil.Ctx(testutil.FA()), apperr.KindForbidden},
		{"finance cannot list", testutil.Ctx(testutil.HO(auth.RoleFinance)), apperr.KindForbidden},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := svc.List(c.ctx, ListFilter{}, nil, nil)
			assert.True(t, apperr.Is(err, c.kind), "list: %v", err)
			_, err = svc.Get(c.ctx, ids.New())
			assert.True(t, apperr.Is(err, c.kind), "get: %v", err)
			_, err = svc.Sample(c.ctx, day, day, nil, nil)
			assert.True(t, apperr.Is(err, c.kind), "sample: %v", err)
		})
	}
	_, err := svc.Counts(testutil.Ctx(testutil.HO(auth.RoleFinance, ids.New())), day, day.AddDate(0, 0, -1), CountsFilter{})
	assert.True(t, apperr.Is(err, apperr.KindValidation), "area-scoped users get counts (validated like everyone)")

	ops := testutil.Ctx(testutil.HO(auth.RoleOps))
	_, err = svc.Counts(ops, day, day.AddDate(0, 0, -1), CountsFilter{})
	assert.True(t, apperr.Is(err, apperr.KindValidation), "to before from")
	_, err = svc.Sample(ops, day, day.AddDate(2, 0, 0), nil, nil)
	assert.True(t, apperr.Is(err, apperr.KindValidation), "range too long")
}

func TestFarmerSurfaceNeedsFarmer(t *testing.T) {
	svc := unitService(nil)
	_, _, err := svc.RequestCallback(testutil.Ctx(testutil.FA()))
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	_, err = svc.MyVisits(testutil.Ctx(testutil.HO(auth.RoleAdmin)), nil, nil)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
}

func TestDayOfIsIST(t *testing.T) {
	// 18:29 UTC on the 30th is 23:59 IST; 18:30 UTC is midnight IST on the 31st.
	assert.Equal(t, "2026-10-30", dayOf(time.Date(2026, 10, 30, 18, 29, 0, 0, time.UTC)).Format(time.DateOnly))
	assert.Equal(t, "2026-10-31", dayOf(time.Date(2026, 10, 30, 18, 30, 0, 0, time.UTC)).Format(time.DateOnly))
}

func TestPointRoundTrip(t *testing.T) {
	g := pointGeoJSON(&Point{Lat: 17.46, Lng: 78.36})
	require.NotNil(t, g)
	p := parsePoint(*g)
	require.NotNil(t, p)
	assert.Equal(t, Point{Lat: 17.46, Lng: 78.36}, *p)
	assert.Nil(t, parsePoint(""))
	assert.Nil(t, pointGeoJSON(nil))
}
