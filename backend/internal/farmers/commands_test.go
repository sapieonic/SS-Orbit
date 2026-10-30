package farmers

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

func TestEnrolFarmer(t *testing.T) {
	f := newFixture(t)
	fa := faPrincipal(f.fa1)
	ctx := testutil.Ctx(fa)

	t.Run("new farmer", func(t *testing.T) {
		in := f.enrolPayload(f.fa1, "98480 12345", "Raju P", f.village)
		c := cmd("EnrolFarmer")
		res, err := f.svc.EnrolFarmer(ctx, fa, c, in)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(in.FarmerID), res)

		got := f.farmer(in.FarmerID)
		assert.Equal(t, "+919848012345", got.Phone)
		assert.Equal(t, StatusActive, got.Status)
		assert.Equal(t, SourceFA, got.Source)
		assert.Equal(t, f.fa1, got.AssignedFaID.UUID, "assigned to the enrolling FA")
		assert.Equal(t, f.district, got.DistrictID.UUID, "district copied from geo")
		assert.Equal(t, 2, f.count(`SELECT count(*) FROM consents WHERE farmer_id = $1 AND method = 'fa_otp' AND captured_by_fa_id = $2
			AND created_at = $3`, got.ID, f.fa1, f.verifiedAt()), "timed when the OTP was verified")
		require.Len(t, f.events("farmer.registered"), 1)
		assert.Equal(t, "fa", f.events("farmer.registered")[0]["source"])
		assert.Equal(t, 1, f.territoryVersion(f.fa1))

		// Replay of the same command: same answer, nothing written twice.
		res, err = f.svc.EnrolFarmer(ctx, fa, c, in)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(in.FarmerID), res)
		assert.Equal(t, 2, f.count(`SELECT count(*) FROM consents WHERE farmer_id = $1`, got.ID))
		assert.Len(t, f.events("farmer.registered"), 1)
	})

	t.Run("merges into a self sign-up and resolves the alias later", func(t *testing.T) {
		selfID := f.selfSignUp("+91 99887 76655")
		in := f.enrolPayload(f.fa1, "9988776655", "Lakshmi D", f.village2)
		res, err := f.svc.EnrolFarmer(ctx, fa, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.StatusMerged, res.Status)
		assert.Equal(t, in.FarmerID, res.EntityID)
		require.NotNil(t, res.MergedInto)
		assert.Equal(t, selfID, *res.MergedInto)

		got := f.farmer(selfID)
		assert.Equal(t, StatusActive, got.Status, "pending self sign-up completed by the FA")
		assert.Equal(t, "Lakshmi D", *got.Name)
		assert.Equal(t, f.village2, got.VillageID.UUID)
		assert.Equal(t, f.fa1, got.AssignedFaID.UUID)
		assert.Equal(t, 0, f.count(`SELECT count(*) FROM farmers WHERE id = $1`, in.FarmerID), "no duplicate farmer")

		// The phone's next command still uses its own farmer_id.
		plot := SavePlotPayload{PlotID: ids.New(), FarmerID: in.FarmerID, Label: "Plot 1",
			Pin: &Point{Lat: 17.46, Lng: 78.36}, AreaAcres: 2.1, AreaSource: AreaTyped}
		res, err = f.svc.SavePlot(ctx, fa, cmd("SavePlot"), plot)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(plot.PlotID), res)
		assert.Equal(t, 1, f.count(`SELECT count(*) FROM plots WHERE id = $1 AND farmer_id = $2`, plot.PlotID, selfID))
	})

	t.Run("rejections", func(t *testing.T) {
		in := f.enrolPayload(f.fa1, "9000000001", "No Consent", f.village)
		in.Consent.Purposes = []string{"soil_partner"}
		res, err := f.svc.EnrolFarmer(ctx, fa, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "programme consent is required")

		in = f.enrolPayload(f.fa1, "12345", "Bad Phone", f.village)
		res, err = f.svc.EnrolFarmer(ctx, fa, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "phone")

		in = f.enrolPayload(f.fa1, "9000000002", "Nowhere", ids.New())
		res, err = f.svc.EnrolFarmer(ctx, fa, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "unknown village")
	})

	t.Run("dispatch through the registry", func(t *testing.T) {
		reg := commands.NewRegistry()
		(&Module{svc: f.svc}).RegisterCommands(reg)
		assert.Equal(t, []string{"EnrolFarmer", "RecordConsent", "SavePlot", "StartSeason", "UpdateFarmer"}, reg.Types())
		payload, _ := json.Marshal(f.enrolPayload(f.fa1, "9000000003", "Via Registry", f.village))
		res, err := reg.Dispatch(ctx, fa, commands.Command{ID: ids.New(), Type: "EnrolFarmer", Payload: payload})
		require.NoError(t, err)
		assert.Equal(t, commands.StatusApplied, res.Status)
	})
}

func TestSavePlot(t *testing.T) {
	f := newFixture(t)
	fa := faPrincipal(f.fa1)
	ctx := testutil.Ctx(fa)
	_, farmerID := f.enrol(f.fa1, "9848012345", "Ravi K", f.village)

	plotID := ids.New()
	boundary := SavePlotPayload{PlotID: plotID, FarmerID: farmerID, Label: "Plot 1",
		BoundaryGeoJSON: json.RawMessage(squareAcre), AreaAcres: 5, AreaSource: AreaBoundary}
	res, err := f.svc.SavePlot(ctx, fa, cmd("SavePlot"), boundary)
	require.NoError(t, err)
	require.Equal(t, commands.Applied(plotID), res)

	got, err := loadPlot(ctx, f.svc.q, plotID)
	require.NoError(t, err)
	assert.InDelta(t, 1.0, got.AreaAcres, 0.02, "area computed by PostGIS, the FA's 5 acres ignored")
	assert.NotEmpty(t, got.BoundaryGeojson)
	assert.Equal(t, f.village, got.VillageID.UUID)
	assert.EqualValues(t, 1, got.Version)

	t.Run("typed area keeps the FA's figure", func(t *testing.T) {
		in := SavePlotPayload{PlotID: ids.New(), FarmerID: farmerID, Label: "Plot 2",
			BoundaryGeoJSON: json.RawMessage(`"` + jsonEscape(squareAcre) + `"`), AreaAcres: 1.75, AreaSource: AreaTyped}
		res, err := f.svc.SavePlot(ctx, fa, cmd("SavePlot"), in)
		require.NoError(t, err)
		require.Equal(t, commands.StatusApplied, res.Status, "%v", res.Error)
		p, err := loadPlot(ctx, f.svc.q, in.PlotID)
		require.NoError(t, err)
		assert.InDelta(t, 1.75, p.AreaAcres, 0.0001)
	})

	t.Run("version check", func(t *testing.T) {
		v1 := int32(1)
		edit := SavePlotPayload{PlotID: plotID, FarmerID: farmerID, Label: "Plot 1", Pin: &Point{Lat: 17.46, Lng: 78.36},
			AreaAcres: 2.0, AreaSource: AreaTyped, ExpectedVersion: &v1}
		c := cmd("SavePlot")
		res, err := f.svc.SavePlot(ctx, fa, c, edit)
		require.NoError(t, err)
		require.Equal(t, commands.Applied(plotID), res)

		// Same command again: recognised as a replay, not a conflict.
		res, err = f.svc.SavePlot(ctx, fa, c, edit)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(plotID), res)

		// Another FA edit made against version 1 now conflicts on the area.
		stale := edit
		stale.AreaAcres = 1.75
		res, err = f.svc.SavePlot(ctx, fa, cmd("SavePlot"), stale)
		require.NoError(t, err)
		require.Equal(t, commands.StatusConflict, res.Status)
		assert.Equal(t, "area_acres", res.Conflict.Field)
		assert.Equal(t, 1.75, res.Conflict.Yours)
		assert.Equal(t, 2.0, res.Conflict.Theirs)
	})

	t.Run("rejections", func(t *testing.T) {
		bad := []SavePlotPayload{
			{PlotID: ids.New(), FarmerID: farmerID, Label: "x", AreaAcres: 1, AreaSource: AreaTyped},                                                                             // no pin, no boundary
			{PlotID: ids.New(), FarmerID: farmerID, Label: "x", Pin: &Point{Lat: 17, Lng: 78}, AreaAcres: 1, AreaSource: AreaBoundary},                                           // boundary source without boundary
			{PlotID: ids.New(), FarmerID: farmerID, Label: "x", BoundaryGeoJSON: json.RawMessage(`{"type":"Point","coordinates":[78,17]}`), AreaAcres: 1, AreaSource: AreaTyped}, // not a polygon
			{PlotID: ids.New(), FarmerID: farmerID, Label: "x", BoundaryGeoJSON: json.RawMessage(`{"type":"Polygon"}`), AreaAcres: 1, AreaSource: AreaTyped},                     // broken GeoJSON
			{PlotID: ids.New(), FarmerID: farmerID, Label: "x", Pin: &Point{Lat: 17, Lng: 78}, AreaAcres: 0, AreaSource: AreaTyped},                                              // zero area
		}
		for i, in := range bad {
			res, err := f.svc.SavePlot(ctx, fa, cmd("SavePlot"), in)
			require.NoError(t, err, i)
			assert.Equal(t, commands.StatusRejected, res.Status, "case %d", i)
		}
	})

	t.Run("an FA the farmer is not assigned to is rejected", func(t *testing.T) {
		other := faPrincipal(f.fa2)
		in := SavePlotPayload{PlotID: ids.New(), FarmerID: farmerID, Label: "Plot 9", Pin: &Point{Lat: 17.46, Lng: 78.36},
			AreaAcres: 1, AreaSource: AreaTyped}
		res, err := f.svc.SavePlot(testutil.Ctx(other), other, cmd("SavePlot"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.StatusRejected, res.Status)
		assert.Contains(t, *res.Error, "not assigned to you")
	})
}

func TestStartSeasonAndUpdateFarmer(t *testing.T) {
	f := newFixture(t)
	fa := faPrincipal(f.fa1)
	ctx := testutil.Ctx(fa)
	_, farmerID := f.enrol(f.fa1, "9848012345", "Ravi K", f.village)
	plotID := ids.New()
	res, err := f.svc.SavePlot(ctx, fa, cmd("SavePlot"), SavePlotPayload{PlotID: plotID, FarmerID: farmerID, Label: "Plot 1",
		Pin: &Point{Lat: 17.46, Lng: 78.36}, AreaAcres: 2, AreaSource: AreaTyped})
	require.NoError(t, err)
	require.Equal(t, commands.StatusApplied, res.Status)

	sowing := "2026-06-12"
	start := StartSeasonPayload{SeasonID: ids.New(), FarmerID: farmerID, PlotID: plotID, SeasonCode: "kharif-2026",
		CropID: f.cotton, SowingDate: &sowing, PreviousCropID: &f.paddy}
	c := cmd("StartSeason")
	res, err = f.svc.StartSeason(ctx, fa, c, start)
	require.NoError(t, err)
	assert.Equal(t, commands.Applied(start.SeasonID), res)
	res, err = f.svc.StartSeason(ctx, fa, c, start)
	require.NoError(t, err)
	assert.Equal(t, commands.Applied(start.SeasonID), res, "replay")

	second := start
	second.SeasonID, second.CropID = ids.New(), f.paddy
	res, err = f.svc.StartSeason(ctx, fa, cmd("StartSeason"), second)
	require.NoError(t, err)
	require.Equal(t, commands.StatusConflict, res.Status, "one active season per plot")
	assert.Equal(t, "active_season", res.Conflict.Field)

	badCrop := start
	badCrop.SeasonID, badCrop.PlotID = ids.New(), plotID
	f.exec(`UPDATE crop_seasons SET status = 'harvested' WHERE id = $1`, start.SeasonID)
	badCrop.CropID = ids.New()
	res, err = f.svc.StartSeason(ctx, fa, cmd("StartSeason"), badCrop)
	require.NoError(t, err)
	assert.Equal(t, commands.StatusRejected, res.Status)
	assert.Equal(t, "crop_id: unknown crop", *res.Error)

	// An unknown previous crop is reported on previous_crop_id, not crop_id.
	badPrevious := start
	badPrevious.SeasonID, badPrevious.PreviousCropID = ids.New(), ptr(ids.New())
	res, err = f.svc.StartSeason(ctx, fa, cmd("StartSeason"), badPrevious)
	require.NoError(t, err)
	assert.Equal(t, commands.StatusRejected, res.Status)
	assert.Equal(t, "previous_crop_id: unknown crop", *res.Error)

	// UpdateFarmer: applied at the right version, conflict per field when stale.
	cur := f.farmer(farmerID)
	name := "Ravi Kumar K"
	res, err = f.svc.UpdateFarmer(ctx, fa, cmd("UpdateFarmer"), UpdateFarmerPayload{FarmerID: farmerID, ExpectedVersion: cur.Version,
		Fields: UpdateFarmerFields{Name: &name}})
	require.NoError(t, err)
	require.Equal(t, commands.Applied(farmerID), res)
	assert.Equal(t, name, *f.farmer(farmerID).Name)

	stale := "Ravi"
	lang := "te"
	res, err = f.svc.UpdateFarmer(ctx, fa, cmd("UpdateFarmer"), UpdateFarmerPayload{FarmerID: farmerID, ExpectedVersion: cur.Version,
		Fields: UpdateFarmerFields{Language: &lang, Name: &stale}})
	require.NoError(t, err)
	require.Equal(t, commands.StatusConflict, res.Status)
	assert.Equal(t, "name", res.Conflict.Field)
	assert.Equal(t, "Ravi", res.Conflict.Yours)

	res, err = f.svc.UpdateFarmer(ctx, fa, cmd("UpdateFarmer"), UpdateFarmerPayload{FarmerID: farmerID, ExpectedVersion: cur.Version,
		Fields: UpdateFarmerFields{Name: &name}})
	require.NoError(t, err)
	assert.Equal(t, commands.StatusApplied, res.Status, "stale version but same values: nothing to resolve")
}

func jsonEscape(s string) string {
	b, _ := json.Marshal(s)
	return string(b[1 : len(b)-1])
}
