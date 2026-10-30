package masters_test

import (
	"context"
	"fmt"
	"os"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/masters"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/cache"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// fixture is a masters module on the test database with HO users that exist
// in ho_users (advisory_rules.created_by/approved_by reference them).
type fixture struct {
	pool      *pgxpool.Pool
	svc       *masters.Service
	admin     context.Context
	agronomyA context.Context
	agronomyB context.Context
}

func newFixture(t *testing.T) fixture {
	t.Helper()
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	m := masters.New(deps, &masters.Ports{})
	return fixture{
		pool:      pool,
		svc:       m.Service(),
		admin:     hoUser(t, pool, auth.RoleAdmin),
		agronomyA: hoUser(t, pool, auth.RoleAgronomy),
		agronomyB: hoUser(t, pool, auth.RoleAgronomy),
	}
}

func hoUser(t *testing.T, pool *pgxpool.Pool, role auth.Role) context.Context {
	t.Helper()
	p := testutil.HO(role)
	_, err := pool.Exec(context.Background(),
		`INSERT INTO ho_users (id, email, name, password_hash, role) VALUES ($1, $2, $3, 'x', $4)`,
		p.ID, p.ID.String()+"@test.local", string(role), string(role))
	require.NoError(t, err)
	return testutil.Ctx(p)
}

func (f fixture) version(t *testing.T) int64 {
	t.Helper()
	v, err := f.svc.CurrentVersion(context.Background())
	require.NoError(t, err)
	return v
}

func (f fixture) count(t *testing.T, sql string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, f.pool.QueryRow(context.Background(), sql, args...).Scan(&n))
	return n
}

// cotton creates a crop with three stages, a salt, a SKU and an issue.
type catalog struct {
	crop  masters.Crop
	salt  masters.Salt
	sku   masters.SKU
	issue masters.Issue
}

func (f fixture) seedCatalog(t *testing.T) catalog {
	t.Helper()
	days := int32(160)
	crop, err := f.svc.CreateCrop(f.admin, masters.CropInput{
		Code: "cotton", Name: "Cotton", NameTe: "పత్తి", DurationDays: &days,
		Stages: []masters.StageInput{
			{Code: "seedling", Name: "Seedling", NameTe: "మొలక", StartDay: 0, EndDay: 25},
			{Code: "square", Name: "Square", NameTe: "మొగ్గ", StartDay: 26, EndDay: 60},
			{Code: "boll", Name: "Boll", NameTe: "కాయ", StartDay: 61, EndDay: 160},
		},
	})
	require.NoError(t, err)
	salt, err := f.svc.CreateSalt(f.admin, "Emamectin benzoate 5% SG", ptr("ఎమామెక్టిన్"))
	require.NoError(t, err)
	sku, err := f.svc.CreateSKU(f.admin, masters.SKUInput{
		Code: "SH-EB-250", ProductName: "Sample 5 SG", SaltID: salt.ID, PackSize: "250 g", MRPPaise: 180000,
	})
	require.NoError(t, err)
	issue, err := f.svc.CreateIssue(f.admin, masters.IssueInput{CropID: crop.ID, Type: "pest", Name: "Pink bollworm", NameTe: "గులాబీ పురుగు"})
	require.NoError(t, err)
	return catalog{crop: crop, salt: salt, sku: sku, issue: issue}
}

func TestCatalogStagesAndSnapshot(t *testing.T) {
	f := newFixture(t)
	v0 := f.version(t)
	c := f.seedCatalog(t)

	// Every catalog write bumped the version and published masters.published.
	assert.Equal(t, v0+4, f.version(t))
	assert.Equal(t, 4, f.count(t, `SELECT count(*) FROM river_job WHERE args->>'name' = 'masters.published'`))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM audit_log WHERE action = 'masters.sku_created' AND entity_id = $1`, c.sku.ID))
	assert.True(t, c.sku.CashbackEligible, "cashback eligible by default")

	// Duplicates are 409.
	_, err := f.svc.CreateSalt(f.agronomyA, "Emamectin benzoate 5% SG", nil)
	assert.True(t, apperr.Is(err, apperr.KindConflict), err)

	// Stage for day.
	for day, want := range map[int]string{-3: "seedling", 30: "square", 61: "boll", 500: "boll"} {
		st, err := f.svc.GetStagesForDay(context.Background(), c.crop.ID, day)
		require.NoError(t, err)
		assert.Equal(t, want, st.Code, "day %d", day)
	}
	_, err = f.svc.GetStagesForDay(context.Background(), uuid.New(), 10)
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	// Replacing the calendar keeps ids by code and deactivates dropped stages.
	squareID := c.crop.Stages[1].ID
	crop, err := f.svc.ReplaceStages(f.agronomyA, c.crop.ID, []masters.StageInput{
		{Code: "square", Name: "Squaring", NameTe: "మొగ్గ", StartDay: 0, EndDay: 70},
		{Code: "boll", Name: "Boll", NameTe: "కాయ", StartDay: 71, EndDay: 160},
	})
	require.NoError(t, err)
	require.Len(t, crop.Stages, 3)
	assert.Equal(t, squareID, crop.Stages[0].ID)
	assert.Equal(t, int32(1), crop.Stages[0].Seq)
	assert.Equal(t, "Squaring", crop.Stages[0].Name)
	assert.False(t, crop.Stages[2].Active, "seedling is kept but inactive")
	assert.Equal(t, "seedling", crop.Stages[2].Code)
	st, err := f.svc.GetStagesForDay(context.Background(), c.crop.ID, 5)
	require.NoError(t, err)
	assert.Equal(t, "square", st.Code)

	// A salt used by an active SKU cannot be deactivated.
	_, err = f.svc.UpdateSalt(f.admin, c.salt.ID, masters.SaltPatch{Active: ptr(false)})
	assert.True(t, apperr.Is(err, apperr.KindConflict), err)

	// Snapshot and farmer crops show only what is active.
	_, err = f.svc.CreateCrop(f.admin, masters.CropInput{Code: "paddy", Name: "Paddy", NameTe: "వరి"})
	require.NoError(t, err)
	_, err = f.svc.UpdateCrop(f.admin, crop.ID, masters.CropPatch{Active: ptr(false)})
	require.NoError(t, err)

	snapAny, err := f.svc.SnapshotSection(context.Background(), territory.Scope{FAID: uuid.New()})
	require.NoError(t, err)
	snap := snapAny.(masters.Snapshot)
	assert.Equal(t, f.version(t), snap.Version)
	require.Len(t, snap.Crops, 1)
	assert.Equal(t, "paddy", snap.Crops[0].Code)
	assert.Empty(t, snap.Issues, "issues of an inactive crop are hidden")
	assert.Len(t, snap.Salts, 1)
	assert.Len(t, snap.SKUs, 1)
	assert.Equal(t, int64(180000), snap.SKUs[0].MRPPaise)

	fc, err := f.svc.FarmerCrops(context.Background())
	require.NoError(t, err)
	assert.Equal(t, snap.Version, fc.Version)
	require.Len(t, fc.Crops, 1)
	assert.Equal(t, "వరి", fc.Crops[0].NameTe)
	assert.NotEmpty(t, fc.SeasonCodes.Current, "season codes come with the crops")
	assert.Equal(t, snap.SeasonCodes, fc.SeasonCodes, "and with the FA snapshot")
	assert.Len(t, snap.SeasonCodes.AllOpen, 3)

	// Admin list includes inactive crops with every stage.
	page, err := f.svc.ListCrops(testutil.Ctx(testutil.HO(auth.RoleFinance)), nil, nil, nil)
	require.NoError(t, err)
	assert.Len(t, page.Items, 2)
}

func TestRuleWorkflow(t *testing.T) {
	f := newFixture(t)
	c := f.seedCatalog(t)
	ctx := context.Background()

	// Admin drafts v1 with the Shanmukha product.
	v1, err := f.svc.CreateRuleDraft(f.admin, masters.RuleInput{
		IssueID: c.issue.ID, SaltID: c.salt.ID, SKUID: &c.sku.ID, Dose: "80 g per acre", DoseTe: "ఎకరానికి 80 గ్రా",
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), v1.Version)
	assert.Equal(t, "draft", v1.Status)
	assert.Equal(t, "Sample 5 SG", *v1.ProductName)
	_, err = f.svc.RuleForVisit(ctx, v1.ID)
	assert.True(t, apperr.Is(err, apperr.KindNotFound), "a draft is never advice")

	// A second rule for the same issue and salt is refused; so is a second open draft.
	_, err = f.svc.CreateRuleDraft(f.agronomyA, masters.RuleInput{IssueID: c.issue.ID, SaltID: c.salt.ID, Dose: "x", DoseTe: "y"})
	requireCode(t, err, "rule_exists")
	_, err = f.svc.CreateRuleDraft(f.agronomyA, masters.RuleInput{RuleKey: &v1.RuleKey, IssueID: c.issue.ID, SaltID: c.salt.ID, Dose: "x", DoseTe: "y"})
	requireCode(t, err, "draft_exists")

	// Only the author edits; approval needs a submitted draft.
	_, err = f.svc.UpdateRuleDraft(f.agronomyA, v1.ID, masters.RuleDraft{SaltID: c.salt.ID, Dose: "x", DoseTe: "y"})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	v1, err = f.svc.UpdateRuleDraft(f.admin, v1.ID, masters.RuleDraft{SaltID: c.salt.ID, SKUID: &c.sku.ID, Dose: "100 g per acre", DoseTe: "ఎకరానికి 100 గ్రా"})
	require.NoError(t, err)
	_, err = f.svc.ApproveRule(f.agronomyA, v1.ID, nil)
	requireCode(t, err, "not_submitted")
	_, err = f.svc.SubmitRule(f.admin, v1.ID)
	require.NoError(t, err)
	_, err = f.svc.UpdateRuleDraft(f.admin, v1.ID, masters.RuleDraft{SaltID: c.salt.ID, Dose: "x", DoseTe: "y"})
	requireCode(t, err, "already_submitted")

	// Admin cannot approve agronomy content.
	_, err = f.svc.ApproveRule(f.admin, v1.ID, nil)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))

	before := f.version(t)
	v1, err = f.svc.ApproveRule(f.agronomyA, v1.ID, ptr("ok"))
	require.NoError(t, err)
	assert.Equal(t, "approved", v1.Status)
	assert.Equal(t, before+1, f.version(t), "approval publishes")

	advice, err := f.svc.RuleForVisit(ctx, v1.ID)
	require.NoError(t, err)
	assert.Equal(t, v1.ID, advice.RuleID)
	assert.Equal(t, "approved", advice.RuleStatus)
	assert.Equal(t, c.issue.ID, advice.IssueID)
	assert.Equal(t, "100 g per acre", advice.Dose)
	assert.Equal(t, c.sku.ID, *advice.SKUID)

	// The SKU is now named by a live rule: it can't be deactivated.
	_, err = f.svc.UpdateSKU(f.admin, c.sku.ID, masters.SKUPatch{Active: ptr(false)})
	requireCode(t, err, "in_use")

	// Agronomy A drafts v2 (salt only); A can't approve their own draft, B can.
	v2, err := f.svc.CreateRuleDraft(f.agronomyA, masters.RuleInput{
		RuleKey: &v1.RuleKey, IssueID: c.issue.ID, SaltID: c.salt.ID, Dose: "2 kg per acre", DoseTe: "ఎకరానికి 2 కిలోలు",
		ChangeNote: ptr("product out of stock"),
	})
	require.NoError(t, err)
	assert.Equal(t, int32(2), v2.Version)
	_, err = f.svc.SubmitRule(f.agronomyA, v2.ID)
	require.NoError(t, err)
	_, err = f.svc.ApproveRule(f.agronomyA, v2.ID, nil)
	require.True(t, apperr.Is(err, apperr.KindForbidden), err)
	assert.Contains(t, err.Error(), "own draft")

	v2, err = f.svc.ApproveRule(f.agronomyB, v2.ID, nil)
	require.NoError(t, err)
	history, err := f.svc.ListRules(f.admin, masters.RuleFilter{RuleKey: &v1.RuleKey}, nil, nil)
	require.NoError(t, err)
	require.Len(t, history.Items, 2)
	assert.Equal(t, "superseded", history.Items[0].Status)
	assert.Equal(t, "approved", history.Items[1].Status)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM advisory_rules WHERE rule_key = $1 AND status = 'approved'`, v1.RuleKey))

	advice, err = f.svc.RuleForVisit(ctx, v2.ID)
	require.NoError(t, err)
	assert.Equal(t, v2.ID, advice.RuleID)
	assert.Nil(t, advice.SKUID, "salt only")
	assert.Equal(t, "ఎకరానికి 2 కిలోలు", *advice.DoseTe)
	// The FA's snapshot may still have v1: it stays valid advice, as superseded.
	advice, err = f.svc.RuleForVisit(ctx, v1.ID)
	require.NoError(t, err)
	assert.Equal(t, "superseded", advice.RuleStatus)
	assert.Equal(t, c.sku.ID, *advice.SKUID)

	// Approved versions are immutable.
	_, err = f.svc.SubmitRule(f.admin, v1.ID)
	requireCode(t, err, "not_draft")

	// Rejecting a draft keeps the live version.
	v3, err := f.svc.CreateRuleDraft(f.admin, masters.RuleInput{RuleKey: &v1.RuleKey, IssueID: c.issue.ID, SaltID: c.salt.ID, Dose: "3 kg", DoseTe: "3 కిలోలు"})
	require.NoError(t, err)
	v3, err = f.svc.RejectRule(f.agronomyB, v3.ID, "dose too high")
	require.NoError(t, err)
	assert.Equal(t, "rejected", v3.Status)
	assert.Equal(t, "dose too high", *v3.ReviewNote)
	_, err = f.svc.RuleForVisit(ctx, v3.ID)
	assert.True(t, apperr.Is(err, apperr.KindNotFound), "rejected versions are never advice")
	_, err = f.svc.RuleForVisit(ctx, uuid.New())
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	snap, err := f.svc.Snapshot(ctx)
	require.NoError(t, err)
	require.Len(t, snap.Rules, 1)
	assert.Equal(t, v2.ID, snap.Rules[0].ID)

	// FA-09: a second salt for the same issue is its own rule, live alongside.
	salt2, err := f.svc.CreateSalt(f.admin, "Chlorantraniliprole 18.5% SC", nil)
	require.NoError(t, err)
	other, err := f.svc.CreateRuleDraft(f.agronomyA, masters.RuleInput{IssueID: c.issue.ID, SaltID: salt2.ID, Dose: "60 ml", DoseTe: "60 మి.లీ"})
	require.NoError(t, err)
	assert.NotEqual(t, v1.RuleKey, other.RuleKey)
	_, err = f.svc.SubmitRule(f.agronomyA, other.ID)
	require.NoError(t, err)
	other, err = f.svc.ApproveRule(f.agronomyB, other.ID, nil)
	require.NoError(t, err)
	snap, err = f.svc.Snapshot(ctx)
	require.NoError(t, err)
	require.Len(t, snap.Rules, 2, "every live rule of the issue, one per salt")
	assert.ElementsMatch(t, []uuid.UUID{v2.ID, other.ID}, []uuid.UUID{snap.Rules[0].ID, snap.Rules[1].ID})

	// A new version of the salt-2 rule that switches to salt 1 collides with
	// the live salt-1 rule at approval.
	clash, err := f.svc.CreateRuleDraft(f.agronomyA, masters.RuleInput{RuleKey: &other.RuleKey, IssueID: c.issue.ID, SaltID: c.salt.ID, Dose: "1 kg", DoseTe: "1 కిలో"})
	require.NoError(t, err)
	_, err = f.svc.SubmitRule(f.agronomyA, clash.ID)
	require.NoError(t, err)
	_, err = f.svc.ApproveRule(f.agronomyB, clash.ID, nil)
	requireCode(t, err, "issue_has_live_rule")

	assert.Equal(t, 3, f.count(t, `SELECT count(*) FROM audit_log WHERE action = 'masters.rule_approved'`))
	assert.Equal(t, 1, f.count(t,
		`SELECT count(*) FROM audit_log WHERE action = 'masters.rule_approved' AND entity_id = $1 AND before->>'id' = $2`,
		v2.ID, v1.ID.String()), "approval audit carries the superseded version as before")
}

func TestDealers(t *testing.T) {
	f := newFixture(t)
	c := f.seedCatalog(t)
	ops := testutil.Ctx(testutil.HO(auth.RoleOps))
	ctx := context.Background()
	v := f.version(t)

	// Kondapur ~ (17.4615, 78.3647); Narsingi ~3.4 km away; Shamshabad ~25 km.
	near, err := f.svc.CreateDealer(ops, masters.DealerInput{
		Name: "Sri Sai Agro Traders", NameTe: ptr("శ్రీ సాయి అగ్రో"), Phone: ptr("98480 30011"),
		Location: &masters.LatLng{Lat: 17.4630, Lng: 78.3660}, Status: ptr("active"), SKUIDs: []uuid.UUID{c.sku.ID, c.sku.ID},
	})
	require.NoError(t, err)
	assert.Equal(t, "+919848030011", *near.Phone)
	assert.Equal(t, []uuid.UUID{c.sku.ID}, near.SKUIDs)
	assert.Equal(t, "ho", near.Source)

	farther, err := f.svc.CreateDealer(ops, masters.DealerInput{
		Name: "Raitu Mitra Traders", Location: &masters.LatLng{Lat: 17.4320, Lng: 78.3600}, Status: ptr("active"),
	})
	require.NoError(t, err)
	unverified, err := f.svc.CreateDealer(ops, masters.DealerInput{Name: "Kisan Agro", Location: &masters.LatLng{Lat: 17.4620, Lng: 78.3650}})
	require.NoError(t, err)
	assert.Equal(t, "to_verify", unverified.Status)
	assert.Equal(t, v, f.version(t), "dealers are not in the FA snapshot")

	got, err := f.svc.NearbyDealers(ctx, masters.NearbyQuery{Lat: 17.4615, Lng: 78.3647})
	require.NoError(t, err)
	require.Len(t, got, 2, "to_verify dealers are hidden")
	assert.Equal(t, near.ID, got[0].ID)
	assert.Equal(t, farther.ID, got[1].ID)
	assert.Less(t, got[0].DistanceM, 500.0)
	assert.InDelta(t, 3300, got[1].DistanceM, 500)

	got, err = f.svc.NearbyDealers(ctx, masters.NearbyQuery{Lat: 17.4615, Lng: 78.3647, SKUID: &c.sku.ID})
	require.NoError(t, err)
	require.Len(t, got, 1)
	got, err = f.svc.NearbyDealers(ctx, masters.NearbyQuery{Lat: 17.4615, Lng: 78.3647, RadiusKM: ptr(1.0)})
	require.NoError(t, err)
	require.Len(t, got, 1)

	// Verifying the shop activates it; stocked SKUs are replaced; deactivating hides it.
	unverified, err = f.svc.UpdateDealer(ops, unverified.ID, masters.DealerPatch{Status: ptr("active"), SKUIDs: &[]uuid.UUID{c.sku.ID}})
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{c.sku.ID}, unverified.SKUIDs)
	_, err = f.svc.UpdateDealer(ops, near.ID, masters.DealerPatch{Status: ptr("inactive"), SKUIDs: &[]uuid.UUID{}})
	require.NoError(t, err)
	got, err = f.svc.NearbyDealers(ctx, masters.NearbyQuery{Lat: 17.4615, Lng: 78.3647, SKUID: &c.sku.ID})
	require.NoError(t, err)
	require.Len(t, got, 1)
	assert.Equal(t, unverified.ID, got[0].ID)

	// A dealer without a pin cannot be activated; unknown SKUs are refused.
	pinless, err := f.svc.CreateDealer(ops, masters.DealerInput{Name: "No Pin"})
	require.NoError(t, err)
	_, err = f.svc.UpdateDealer(ops, pinless.ID, masters.DealerPatch{Status: ptr("active")})
	requireCode(t, err, "validation_failed")
	_, err = f.svc.UpdateDealer(ops, pinless.ID, masters.DealerPatch{SKUIDs: &[]uuid.UUID{uuid.New()}})
	requireCode(t, err, "validation_failed")

	page, err := f.svc.ListDealers(f.admin, masters.DealerFilter{Status: ptr("active")}, nil, nil)
	require.NoError(t, err)
	assert.Len(t, page.Items, 2)
	// 4 creates + 2 successful updates; refused updates roll back.
	assert.Equal(t, 6, f.count(t, `SELECT count(*) FROM audit_log WHERE action LIKE 'masters.dealer_%'`))
}

func requireCode(t *testing.T, err error, code string) {
	t.Helper()
	e, ok := apperr.As(err)
	require.True(t, ok, "want apperr %s, got %v", code, err)
	assert.Equal(t, code, e.Code, err)
}

func ptr[T any](v T) *T { return &v }

// TestAdviceCache runs only with TEST_REDIS_URL (e.g. redis://localhost:6379/15):
// product terms are cached per masters version and the masters.published subscriber
// drops the previous version's entries.
func TestAdviceCache(t *testing.T) {
	url := os.Getenv("TEST_REDIS_URL")
	if url == "" {
		t.Skip("TEST_REDIS_URL not set; skipping Redis cache test")
	}
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	rdb, err := cache.Open(url)
	require.NoError(t, err)
	t.Cleanup(func() { _ = rdb.Close() })
	deps.Cache = cache.New(rdb, nil)
	m := masters.New(deps, &masters.Ports{})
	f := fixture{pool: pool, svc: m.Service(), admin: hoUser(t, pool, auth.RoleAdmin),
		agronomyA: hoUser(t, pool, auth.RoleAgronomy), agronomyB: hoUser(t, pool, auth.RoleAgronomy)}
	c := f.seedCatalog(t)
	ctx := context.Background()

	r, err := f.svc.CreateRuleDraft(f.admin, masters.RuleInput{IssueID: c.issue.ID, SaltID: c.salt.ID, Dose: "1 kg", DoseTe: "1 కిలో"})
	require.NoError(t, err)
	_, err = f.svc.SubmitRule(f.admin, r.ID)
	require.NoError(t, err)
	_, err = f.svc.ApproveRule(f.agronomyA, r.ID, nil)
	require.NoError(t, err)
	v := f.version(t)
	key := fmt.Sprintf("masters:v%d:product_terms", v)
	t.Cleanup(func() { rdb.Del(context.Background(), key, fmt.Sprintf("masters:v%d:product_terms", v+1)) })

	_, err = f.svc.ProductTerms(ctx)
	require.NoError(t, err)
	n, err := rdb.Exists(ctx, key).Result()
	require.NoError(t, err)
	assert.Equal(t, int64(1), n, "product terms cached under the current version")

	// A publish moves readers to a new key at once; the subscriber clears the old one.
	_, err = f.svc.UpdateIssue(f.admin, c.issue.ID, masters.IssuePatch{NameTe: ptr("గులాబీ రంగు పురుగు")})
	require.NoError(t, err)
	require.NoError(t, masters.OnPublishedForTest(m)(ctx, events.MastersPublished{Kind: "all", Version: v + 1}))
	n, err = rdb.Exists(ctx, key).Result()
	require.NoError(t, err)
	assert.Equal(t, int64(0), n)
}
