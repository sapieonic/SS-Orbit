package visits

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
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

// --- fake ports ---

type fakeFarmers struct {
	m       map[uuid.UUID]xmod.FarmerSummary
	aliases map[uuid.UUID]uuid.UUID // phone-minted ID -> canonical farmer
}

// ResolveFarmerForFA follows the farmers module's rule: alias, then the
// farmer must be assigned to the FA.
func (f *fakeFarmers) ResolveFarmerForFA(_ context.Context, faID, farmerID uuid.UUID) (uuid.UUID, error) {
	if id, ok := f.aliases[farmerID]; ok {
		farmerID = id
	}
	s, ok := f.m[farmerID]
	if !ok {
		return uuid.Nil, apperr.NotFound("farmer")
	}
	if !s.AssignedFAID.Valid || s.AssignedFAID.UUID != faID {
		return uuid.Nil, apperr.Forbidden("this farmer is not assigned to you")
	}
	return farmerID, nil
}

func (f *fakeFarmers) GetFarmerSummaries(_ context.Context, list []uuid.UUID) ([]xmod.FarmerSummary, error) {
	var out []xmod.FarmerSummary
	for _, id := range list {
		if s, ok := f.m[id]; ok {
			out = append(out, s)
		}
	}
	return out, nil
}

func (f *fakeFarmers) assign(farmerID, faID uuid.UUID) {
	s := f.m[farmerID]
	s.ID, s.AssignedFAID = farmerID, uuid.NullUUID{UUID: faID, Valid: faID != uuid.Nil}
	f.m[farmerID] = s
}

func (f *fakeFarmers) setVillage(farmerID, villageID uuid.UUID) {
	s := f.m[farmerID]
	s.VillageID = uuid.NullUUID{UUID: villageID, Valid: true}
	f.m[farmerID] = s
}

// fakeMasters knows approved/superseded rules by rule ID.
type fakeMasters struct {
	m     map[uuid.UUID]xmod.Advice
	calls int
}

func (f *fakeMasters) RuleForVisit(_ context.Context, ruleID uuid.UUID) (xmod.Advice, error) {
	f.calls++
	a, ok := f.m[ruleID]
	if !ok {
		return xmod.Advice{}, apperr.NotFound("rule")
	}
	return a, nil
}

// fakeGeo knows the one test village.
type fakeGeo struct{ village xmod.Village }

func (g fakeGeo) GetVillages(_ context.Context, list []uuid.UUID) ([]xmod.Village, error) {
	var out []xmod.Village
	for _, id := range list {
		if id == g.village.ID {
			out = append(out, g.village)
		}
	}
	return out, nil
}

type fakeIdentity struct {
	m map[uuid.UUID]xmod.FieldAssistant
}

func (f *fakeIdentity) GetFieldAssistants(_ context.Context, list []uuid.UUID) ([]xmod.FieldAssistant, error) {
	var out []xmod.FieldAssistant
	for _, id := range list {
		if fa, ok := f.m[id]; ok {
			out = append(out, fa)
		}
	}
	return out, nil
}

type fakeLabels struct{}

func (fakeLabels) IssueLabel(_ context.Context, _ uuid.UUID) (string, string, error) {
	return "Pink bollworm", "గులాబీ రంగు పురుగు", nil
}

func (fakeLabels) StageLabel(_ context.Context, _ uuid.UUID) (string, string, error) {
	return "Flowering", "పూత", nil
}

// --- world: a seeded database with two FAs and two farmers ---

type world struct {
	t       *testing.T
	pool    *pgxpool.Pool
	deps    platform.Deps
	clock   *clock.Fake
	svc     *Service
	mod     *Module
	reg     *commands.Registry
	farmers *fakeFarmers
	masters *fakeMasters

	fa1, fa2            auth.Principal
	farmer1, farmer2    uuid.UUID
	plot1, plot2        uuid.UUID
	season1, season2    uuid.UUID
	stage               uuid.UUID
	issueSKU, issueSalt uuid.UUID // advice with a Shanmukha SKU / salt only
	issueNoRule         uuid.UUID
	ruleSKU, ruleSalt   uuid.UUID
	ruleOld             uuid.UUID // an earlier, superseded version of the issueSKU rule
	salt, sku           uuid.UUID
	district, village   uuid.UUID // both farmers live here
	mandal              uuid.UUID
}

// now is the fake clock's start: 30 Oct 2026, 10:00 IST.
var now = time.Date(2026, 10, 30, 4, 30, 0, 0, time.UTC)

func newWorld(t *testing.T) *world {
	t.Helper()
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	clk := clock.NewFake(now)
	deps.Clock = clk
	w := &world{
		t: t, pool: pool, deps: deps, clock: clk,
		farmers: &fakeFarmers{m: map[uuid.UUID]xmod.FarmerSummary{}},
		fa1:     testutil.FA(), fa2: testutil.FA(),
		farmer1: ids.New(), farmer2: ids.New(), plot1: ids.New(), plot2: ids.New(),
		season1: ids.New(), season2: ids.New(), stage: ids.New(),
		issueSKU: ids.New(), issueSalt: ids.New(), issueNoRule: ids.New(),
		ruleSKU: ids.New(), ruleSalt: ids.New(), ruleOld: ids.New(), salt: ids.New(), sku: ids.New(),
		district: ids.New(), village: ids.New(),
	}
	w.seed()
	product, productTe, doseTe := "Sample 5 SG", "శాంపిల్ 5 SG", "ఎకరానికి 80 గ్రా"
	saltTe := "ఎమామెక్టిన్"
	w.masters = &fakeMasters{m: map[uuid.UUID]xmod.Advice{
		w.ruleSKU: {RuleID: w.ruleSKU, RuleVersion: 2, RuleStatus: "approved", IssueID: w.issueSKU, SaltID: w.salt,
			SaltName: "Emamectin benzoate 5% SG", SaltNameTe: &saltTe, SKUID: &w.sku, ProductName: &product,
			ProductNameTe: &productTe, Dose: "80 g per acre", DoseTe: &doseTe},
		w.ruleOld: {RuleID: w.ruleOld, RuleVersion: 1, RuleStatus: "superseded", IssueID: w.issueSKU, SaltID: w.salt,
			SaltName: "Emamectin benzoate 5% SG", Dose: "70 g per acre"},
		w.ruleSalt: {RuleID: w.ruleSalt, RuleVersion: 1, RuleStatus: "approved", IssueID: w.issueSalt, SaltID: w.salt,
			SaltName: "Emamectin benzoate 5% SG", Dose: "60 g per acre"},
	}}
	w.farmers.assign(w.farmer1, w.fa1.ID)
	w.farmers.assign(w.farmer2, w.fa1.ID)
	w.farmers.setVillage(w.farmer1, w.village)
	w.farmers.setVillage(w.farmer2, w.village)
	ports := &Ports{
		Farmers: w.farmers, Masters: w.masters, Labels: fakeLabels{},
		Geo: fakeGeo{village: xmod.Village{ID: w.village, Name: "Kondapur", MandalID: w.mandal, DistrictID: w.district}},
		Identity: &fakeIdentity{m: map[uuid.UUID]xmod.FieldAssistant{
			w.fa1.ID: {ID: w.fa1.ID, Name: "Suresh K"}, w.fa2.ID: {ID: w.fa2.ID, Name: "Farida S"},
		}},
	}
	w.mod = New(deps, ports)
	w.svc = w.mod.Service()
	w.reg = commands.NewRegistry()
	w.mod.RegisterCommands(w.reg)
	return w
}

func (w *world) exec(sql string, args ...any) {
	w.t.Helper()
	_, err := w.pool.Exec(context.Background(), sql, args...)
	require.NoError(w.t, err, sql)
}

// seed inserts the master, identity and farmer rows the visits tables point
// at. Tests may write other modules' tables for fixtures only.
func (w *world) seed() {
	ho, crop := ids.New(), ids.New()
	w.mandal = ids.New()
	w.exec(`INSERT INTO districts (id, name) VALUES ($1, 'Rangareddy')`, w.district)
	w.exec(`INSERT INTO mandals (id, district_id, name) VALUES ($1, $2, 'Serilingampally')`, w.mandal, w.district)
	w.exec(`INSERT INTO villages (id, mandal_id, name) VALUES ($1, $2, 'Kondapur')`, w.village, w.mandal)
	w.exec(`INSERT INTO ho_users (id, email, name, password_hash, role) VALUES ($1, 'qa@example.com', 'QA', 'x', 'agronomy')`, ho)
	for i, fa := range []uuid.UUID{w.fa1.ID, w.fa2.ID} {
		w.exec(`INSERT INTO field_assistants (id, code, name, phone, password_hash, level)
		        VALUES ($1, $2, 'FA', '+919800000000', 'x', 'village')`, fa, "FA-T-"+string(rune('A'+i)))
	}
	w.exec(`INSERT INTO crops (id, code, name, name_te) VALUES ($1, 'cotton', 'Cotton', 'పత్తి')`, crop)
	w.exec(`INSERT INTO crop_stages (id, crop_id, code, name, name_te, seq, start_day, end_day)
	        VALUES ($1, $2, 'flowering', 'Flowering', 'పూత', 3, 60, 100)`, w.stage, crop)
	for _, is := range []uuid.UUID{w.issueSKU, w.issueSalt, w.issueNoRule} {
		w.exec(`INSERT INTO issues (id, crop_id, type, name, name_te) VALUES ($1, $2, 'pest', $3, 'పురుగు')`, is, crop, "pest-"+is.String())
	}
	w.exec(`INSERT INTO salts (id, name) VALUES ($1, 'Emamectin benzoate 5% SG')`, w.salt)
	w.exec(`INSERT INTO skus (id, code, product_name, salt_id, pack_size, mrp_paise) VALUES ($1, 'SH-EB-250', 'Sample 5 SG', $2, '250 g', 90000)`, w.sku, w.salt)
	w.exec(`INSERT INTO advisory_rules (id, rule_key, version, issue_id, salt_id, sku_id, dose_per_acre, dose_per_acre_te, status, created_by, approved_by, approved_at)
	        VALUES ($1, $2, 2, $3, $4, $5, '80 g per acre', 'x', 'approved', $6, $6, now())`, w.ruleSKU, ids.New(), w.issueSKU, w.salt, w.sku, ho)
	w.exec(`INSERT INTO advisory_rules (id, rule_key, version, issue_id, salt_id, dose_per_acre, dose_per_acre_te, status, created_by, approved_by, approved_at)
	        VALUES ($1, $2, 1, $3, $4, '60 g per acre', 'x', 'approved', $5, $5, now())`, w.ruleSalt, ids.New(), w.issueSalt, w.salt, ho)
	w.exec(`INSERT INTO advisory_rules (id, rule_key, version, issue_id, salt_id, dose_per_acre, dose_per_acre_te, status, created_by, approved_by, approved_at)
	        VALUES ($1, $2, 1, $3, $4, '70 g per acre', 'x', 'superseded', $5, $5, now())`, w.ruleOld, ids.New(), w.issueSKU, w.salt, ho)
	for i, f := range []struct{ farmer, plot, season uuid.UUID }{{w.farmer1, w.plot1, w.season1}, {w.farmer2, w.plot2, w.season2}} {
		w.exec(`INSERT INTO farmers (id, phone, name, source, assigned_fa_id) VALUES ($1, $2, 'Ravi', 'fa', $3)`,
			f.farmer, "+91987654321"+string(rune('0'+i)), w.fa1.ID)
		w.exec(`INSERT INTO plots (id, farmer_id, label, pin, area_acres, area_source)
		        VALUES ($1, $2, 'Plot 1', ST_GeogFromText('POINT(78.36 17.46)'), 2.1, 'typed')`, f.plot, f.farmer)
		w.exec(`INSERT INTO crop_seasons (id, farmer_id, plot_id, season_code, crop_id) VALUES ($1, $2, $3, 'rabi-2026-27', $4)`,
			f.season, f.farmer, f.plot, crop)
	}
}

// send dispatches a sync command as fa through the registry, like the sync module.
func (w *world) send(fa auth.Principal, typ string, payload any) commands.Result {
	w.t.Helper()
	raw, err := json.Marshal(payload)
	require.NoError(w.t, err)
	res, err := w.reg.Dispatch(testutil.Ctx(fa), fa, commands.Command{ID: ids.New(), Type: typ, Payload: raw})
	require.NoError(w.t, err)
	return res
}

func (w *world) count(sql string, args ...any) int {
	w.t.Helper()
	var n int
	require.NoError(w.t, w.pool.QueryRow(context.Background(), sql, args...).Scan(&n), sql)
	return n
}

func (w *world) version(fa uuid.UUID) int {
	return w.count(`SELECT COALESCE((SELECT version FROM territory_versions WHERE fa_id = $1), 0)`, fa)
}

func (w *world) planPayload(visitID uuid.UUID, day string) map[string]any {
	return map[string]any{
		"visit_id": visitID, "farmer_id": w.farmer1, "plot_id": w.plot1, "season_id": w.season1,
		"planned_for": day, "planned_slot": "morning", "purpose": "Check bollworm",
	}
}

func (w *world) logPayload(visitID uuid.UUID) map[string]any {
	return map[string]any{
		"visit_id": visitID, "farmer_id": w.farmer1, "plot_id": w.plot1, "season_id": w.season1,
		"visited_at": now.Add(-time.Hour).Format(time.RFC3339), "location": map[string]any{"lat": 17.46, "lng": 78.36},
		"farmer_present": true, "stage_id": w.stage, "notes": "Bollworm at flowering",
		"issues": []map[string]any{
			{"issue_visit_id": ids.New(), "issue_id": w.issueSKU, "severity": "moderate", "advisory_rule_id": w.ruleSKU},
			{"issue_visit_id": ids.New(), "issue_id": w.issueSalt, "severity": "low", "advisory_rule_id": w.ruleSalt},
		},
		"photos": []map[string]any{{"photo_id": ids.New(), "content_type": "image/jpeg"}},
	}
}

// farmerPrincipal is a farmer app principal for an existing farmer.
func farmerPrincipal(id uuid.UUID) auth.Principal {
	p := testutil.Farmer()
	p.ID = id
	return p
}
