package visits_test

// This external test wires the real farmers and visits modules together the
// way internal/app does, to replay the reviewer's offline batch end to end.
// Only the test imports farmers; the visits package itself never does.

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/farmers"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/visits"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

type oneVillageGeo struct{ v xmod.Village }

func (g oneVillageGeo) GetVillages(_ context.Context, list []uuid.UUID) ([]xmod.Village, error) {
	out := []xmod.Village{}
	for _, id := range list {
		if id == g.v.ID {
			out = append(out, g.v)
		}
	}
	return out, nil
}
func (g oneVillageGeo) FAsCoveringVillage(context.Context, uuid.UUID) ([]xmod.Coverage, error) {
	return nil, nil
}
func (g oneVillageGeo) VillageIDsForFA(context.Context, uuid.UUID) ([]uuid.UUID, error) {
	return []uuid.UUID{g.v.ID}, nil
}
func (g oneVillageGeo) DistrictIDsForFAs(_ context.Context, fas []uuid.UUID) (map[uuid.UUID][]uuid.UUID, error) {
	out := map[uuid.UUID][]uuid.UUID{}
	for _, fa := range fas {
		out[fa] = []uuid.UUID{g.v.DistrictID}
	}
	return out, nil
}

type noIdentity struct{}

func (noIdentity) GetFieldAssistants(context.Context, []uuid.UUID) ([]xmod.FieldAssistant, error) {
	return nil, nil
}

type noStages struct{}

func (noStages) GetStagesForDay(context.Context, uuid.UUID, int) (xmod.Stage, error) {
	return xmod.Stage{}, apperr.NotFound("stage")
}

type noRules struct{}

func (noRules) RuleForVisit(context.Context, uuid.UUID) (xmod.Advice, error) {
	return xmod.Advice{}, apperr.NotFound("rule")
}

// TestMergedEnrolmentBatch: a farmer signs up on their own phone; an FA,
// offline, enrols the same phone and in the same batch saves a plot, starts a
// season, plans a visit and logs one, all under the farmer_id the FA phone
// minted. Every command must apply against the merged farmer.
func TestMergedEnrolmentBatch(t *testing.T) {
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	ctx := context.Background()
	exec := func(sql string, args ...any) {
		t.Helper()
		_, err := pool.Exec(ctx, sql, args...)
		require.NoError(t, err, sql)
	}

	district, mandal, village, crop := ids.New(), ids.New(), ids.New(), ids.New()
	fa := testutil.FA()
	exec(`INSERT INTO districts (id, name) VALUES ($1, 'Rangareddy')`, district)
	exec(`INSERT INTO mandals (id, district_id, name) VALUES ($1, $2, 'Serilingampally')`, mandal, district)
	exec(`INSERT INTO villages (id, mandal_id, name) VALUES ($1, $2, 'Kondapur')`, village, mandal)
	exec(`INSERT INTO field_assistants (id, code, name, phone, password_hash, level)
	      VALUES ($1, 'FA-KDP-001', 'Suresh K', '+919848000001', 'x', 'village')`, fa.ID)
	exec(`INSERT INTO crops (id, code, name, name_te) VALUES ($1, 'cotton', 'Cotton', 'పత్తి')`, crop)

	geo := oneVillageGeo{v: xmod.Village{ID: village, Name: "Kondapur", MandalID: mandal, DistrictID: district}}
	fm := farmers.New(deps, &farmers.Ports{Identity: noIdentity{}, Geo: geo, Masters: noStages{}})
	vm := visits.New(deps, &visits.Ports{Farmers: fm.Service(), Masters: noRules{}, Geo: geo})
	reg := commands.NewRegistry()
	fm.RegisterCommands(reg)
	vm.RegisterCommands(reg)

	// The farmer signs up on their own phone (identity's OTP flow).
	var selfID uuid.UUID
	require.NoError(t, db.WithTx(ctx, pool, func(tx pgx.Tx) error {
		var err error
		selfID, _, err = fm.Service().FindOrCreateByPhone(ctx, tx, "9988776655", farmers.SourceSelf)
		return err
	}))

	proof, err := deps.Tokens.IssueConsentProof(auth.ConsentProof{FAID: fa.ID, Phone: "+919988776655", VerifiedAt: time.Now()}, time.Hour)
	require.NoError(t, err)
	phoneFarmer, plot, season, planned, logged := ids.New(), ids.New(), ids.New(), ids.New(), ids.New()
	batch := []struct {
		typ     string
		payload map[string]any
	}{
		{"EnrolFarmer", map[string]any{"farmer_id": phoneFarmer, "phone": "9988776655", "name": "Lakshmi D", "language": "te",
			"village_id": village, "consent": map[string]any{"purposes": []string{"programme"}, "otp_proof": proof,
				"audio_played": true, "notice_version": "2026-10"}}},
		{"SavePlot", map[string]any{"plot_id": plot, "farmer_id": phoneFarmer, "label": "Plot 1",
			"pin": map[string]any{"lat": 17.46, "lng": 78.36}, "area_acres": 2.1, "area_source": "typed"}},
		{"StartSeason", map[string]any{"season_id": season, "farmer_id": phoneFarmer, "plot_id": plot,
			"season_code": "rabi-2026-27", "crop_id": crop, "sowing_date": "2026-10-01"}},
		{"PlanVisit", map[string]any{"visit_id": planned, "farmer_id": phoneFarmer, "plot_id": plot, "season_id": season,
			"planned_for": "2026-11-05", "planned_slot": "morning"}},
		{"LogVisit", map[string]any{"visit_id": logged, "farmer_id": phoneFarmer, "plot_id": plot, "season_id": season,
			"visited_at": time.Now().Add(-time.Hour).Format(time.RFC3339), "farmer_present": true,
			"photos": []map[string]any{{"photo_id": ids.New(), "content_type": "image/jpeg"}}}},
	}
	for _, c := range batch {
		raw, err := json.Marshal(c.payload)
		require.NoError(t, err)
		res, err := reg.Dispatch(testutil.Ctx(fa), fa, commands.Command{ID: ids.New(), Type: c.typ, Payload: raw})
		require.NoError(t, err, c.typ)
		want := commands.StatusApplied
		if c.typ == "EnrolFarmer" {
			want = commands.StatusMerged
			require.NotNil(t, res.MergedInto)
			assert.Equal(t, selfID, *res.MergedInto)
		}
		require.Equal(t, want, res.Status, "%s: %v", c.typ, res.Error)
	}

	var n int
	require.NoError(t, pool.QueryRow(ctx, `SELECT count(*) FROM visits WHERE farmer_id = $1 AND id = ANY($2) AND district_id = $3`,
		selfID, []uuid.UUID{planned, logged}, district).Scan(&n))
	assert.Equal(t, 2, n, "both visits stored on the canonical farmer, with their district")
}
