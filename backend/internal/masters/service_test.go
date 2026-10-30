package masters

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/masters/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// Unit tests for the rules that need no database. The write paths and the
// approval workflow are covered against Postgres in integration_test.go.

func TestPickStage(t *testing.T) {
	stages := []store.CropStage{
		{Code: "seedling", Seq: 1, StartDay: 0, EndDay: 20},
		{Code: "square", Seq: 2, StartDay: 21, EndDay: 50},
		{Code: "flowering", Seq: 3, StartDay: 60, EndDay: 90}, // gap 51..59
		{Code: "boll", Seq: 4, StartDay: 91, EndDay: 140},
	}
	cases := []struct {
		day  int
		want string
	}{
		{-5, "seedling"}, // before the first stage
		{0, "seedling"},
		{20, "seedling"},
		{21, "square"},
		{55, "square"}, // in a gap: the stage that started last
		{60, "flowering"},
		{140, "boll"},
		{400, "boll"}, // after the last stage
	}
	for _, c := range cases {
		assert.Equal(t, c.want, pickStage(stages, c.day).Code, "day %d", c.day)
	}
	assert.Equal(t, "only", pickStage([]store.CropStage{{Code: "only", StartDay: 10, EndDay: 20}}, 0).Code)
}

func TestCleanStages(t *testing.T) {
	ok := []StageInput{
		{Code: "a", Name: " A ", NameTe: "ఎ", StartDay: 0, EndDay: 10},
		{Code: "b", Name: "B", NameTe: "బి", StartDay: 11, EndDay: 30},
	}
	errs := map[string]string{}
	out := cleanStages(ok, errs)
	assert.Empty(t, errs)
	assert.Equal(t, "A", out[0].Name, "names are trimmed")

	errs = map[string]string{}
	cleanStages([]StageInput{
		{Code: "a", Name: "A", NameTe: " ", StartDay: 5, EndDay: 1},
		{Code: "a", Name: "B", NameTe: "బి", StartDay: 1, EndDay: 9},
	}, errs)
	assert.Equal(t, map[string]string{
		"stages[0].name_te":   "must not be blank",
		"stages[0].end_day":   "must not be before start_day",
		"stages[1].code":      "duplicate stage code",
		"stages[1].start_day": "must be after the previous stage's end_day",
	}, errs)
}

func TestCheckMRP(t *testing.T) {
	for _, c := range []struct {
		mrp int64
		ok  bool
	}{{1, true}, {360000, true}, {MaxMRPPaise, true}, {0, false}, {-1, false}, {MaxMRPPaise + 1, false}} {
		errs := map[string]string{}
		checkMRP(c.mrp, errs)
		assert.Equal(t, c.ok, len(errs) == 0, "mrp %d", c.mrp)
	}
}

// Role checks run before any database access, so a service without a
// database is enough to exercise them.
func TestAuthorization(t *testing.T) {
	svc := NewService(platform.Deps{}, nil, nil)
	id := ids.New()
	ctxFor := func(p auth.Principal) context.Context { return testutil.Ctx(p) }

	writes := map[string]func(ctx context.Context) error{
		"create crop":  func(ctx context.Context) error { _, err := svc.CreateCrop(ctx, CropInput{}); return err },
		"create salt":  func(ctx context.Context) error { _, err := svc.CreateSalt(ctx, "x", nil); return err },
		"update sku":   func(ctx context.Context) error { _, err := svc.UpdateSKU(ctx, id, SKUPatch{}); return err },
		"create issue": func(ctx context.Context) error { _, err := svc.CreateIssue(ctx, IssueInput{}); return err },
		"draft rule":   func(ctx context.Context) error { _, err := svc.CreateRuleDraft(ctx, RuleInput{}); return err },
	}
	for name, fn := range writes {
		for _, p := range []auth.Principal{testutil.HO(auth.RoleFinance), testutil.HO(auth.RoleOps), testutil.FA(), testutil.Farmer()} {
			err := fn(ctxFor(p))
			assert.True(t, apperr.Is(err, apperr.KindForbidden), "%s as %s/%s: %v", name, p.Kind, p.Role, err)
		}
		assert.True(t, apperr.Is(fn(context.Background()), apperr.KindUnauthorized), name)
	}

	// Dealers: ops may write too, finance may not.
	_, err := svc.CreateDealer(ctxFor(testutil.HO(auth.RoleFinance)), DealerInput{Name: "x"})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))

	// Approval and rejection are Agronomy only; admin gets the wireframe's message.
	for _, role := range []auth.Role{auth.RoleAdmin, auth.RoleFinance, auth.RoleOps} {
		_, err := svc.ApproveRule(ctxFor(testutil.HO(role)), id, nil)
		require.True(t, apperr.Is(err, apperr.KindForbidden), role)
		assert.Contains(t, err.Error(), "only Agronomy")
		_, err = svc.RejectRule(ctxFor(testutil.HO(role)), id, "no")
		assert.True(t, apperr.Is(err, apperr.KindForbidden), role)
	}
	_, err = svc.ApproveRule(ctxFor(testutil.FA()), id, nil)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))

	// Reads: every HO role, nobody else.
	_, err = svc.ListRules(ctxFor(testutil.FA()), RuleFilter{}, nil, nil)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
}

func TestValidationBeforeDatabase(t *testing.T) {
	svc := NewService(platform.Deps{}, nil, nil)
	ctx := testutil.Ctx(testutil.HO(auth.RoleAdmin))

	_, err := svc.CreateSKU(ctx, SKUInput{Code: "SH-1", ProductName: "P", PackSize: "1 kg", MRPPaise: MaxMRPPaise + 1})
	requireField(t, err, "mrp_paise")

	_, err = svc.CreateRuleDraft(ctx, RuleInput{Dose: " ", DoseTe: "x"})
	requireField(t, err, "dose_per_acre")

	_, err = svc.CreateDealer(ctx, DealerInput{Name: "Shop", Status: ptr(dealerActive)})
	requireField(t, err, "location")

	_, err = svc.CreateDealer(ctx, DealerInput{Name: "Shop", Phone: ptr("12345")})
	requireField(t, err, "phone")

	_, err = svc.ReplaceStages(ctx, ids.New(), nil)
	requireField(t, err, "stages")
}

func TestCacheKey(t *testing.T) {
	assert.Equal(t, "masters:v7:snapshot", cacheKey(7, cacheSnapshot))
}

func requireField(t *testing.T, err error, field string) {
	t.Helper()
	e, ok := apperr.As(err)
	require.True(t, ok, "want apperr, got %v", err)
	require.Equal(t, apperr.KindValidation, e.Kind, err)
	fields, _ := e.Details["fields"].(map[string]string)
	assert.Contains(t, fields, field, err)
}

func ptr[T any](v T) *T { return &v }
