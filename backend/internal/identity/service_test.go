package identity

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// Unit tests for rules that are decided before any database access. The
// service has no pool here, so reaching the database would panic.
func noDBService() *Service {
	return NewService(platform.Deps{Config: config.ForTest(), Clock: clock.System(), Tokens: testutil.Tokens()}, nil, nil)
}

func TestAdminAuthorization(t *testing.T) {
	svc := noDBService()
	id := ids.New()
	manageFAs := map[string]func(ctx context.Context) error{
		"list fas":      func(ctx context.Context) error { _, err := svc.ListFAs(ctx, FAFilter{}, nil, nil); return err },
		"get fa":        func(ctx context.Context) error { _, err := svc.GetFA(ctx, id); return err },
		"create fa":     func(ctx context.Context) error { _, _, err := svc.CreateFA(ctx, FACreate{}); return err },
		"update fa":     func(ctx context.Context) error { _, err := svc.UpdateFA(ctx, id, FAPatch{}); return err },
		"fa status":     func(ctx context.Context) error { _, err := svc.SetFAStatus(ctx, id, FAActive); return err },
		"fa reset":      func(ctx context.Context) error { _, err := svc.ResetFAPassword(ctx, id); return err },
		"fa sign out":   func(ctx context.Context) error { return svc.SignOutFA(ctx, id) },
		"list devices":  func(ctx context.Context) error { _, err := svc.ListDevices(ctx, SubjectFA, id, nil, nil); return err },
		"revoke device": func(ctx context.Context) error { _, err := svc.RevokeDevice(ctx, id, "lost"); return err },
	}
	manageHO := map[string]func(ctx context.Context) error{
		"list ho":   func(ctx context.Context) error { _, err := svc.ListHOAccounts(ctx, HOFilter{}, nil, nil); return err },
		"get ho":    func(ctx context.Context) error { _, err := svc.GetHOAccount(ctx, id); return err },
		"create ho": func(ctx context.Context) error { _, _, err := svc.CreateHOAccount(ctx, NewHOAccount{}); return err },
		"update ho": func(ctx context.Context) error { _, err := svc.UpdateHOAccount(ctx, id, HOAccountPatch{}); return err },
		"ho status": func(ctx context.Context) error { _, err := svc.SetHOAccountStatus(ctx, id, HODisabled); return err },
		"ho reset":  func(ctx context.Context) error { _, err := svc.ResetHOPassword(ctx, id); return err },
		"ho totp":   func(ctx context.Context) error { return svc.ResetHOTOTP(ctx, id) },
	}
	refused := []struct {
		name string
		ctx  context.Context
		kind apperr.Kind
	}{
		{"no principal", context.Background(), apperr.KindUnauthorized},
		{"fa", testutil.Ctx(testutil.FA()), apperr.KindForbidden},
		{"farmer", testutil.Ctx(testutil.Farmer()), apperr.KindForbidden},
		{"agronomy", testutil.Ctx(testutil.HO(auth.RoleAgronomy)), apperr.KindForbidden},
		{"finance", testutil.Ctx(testutil.HO(auth.RoleFinance)), apperr.KindForbidden},
	}
	for _, c := range refused {
		for name, fn := range manageFAs {
			assert.True(t, apperr.Is(fn(c.ctx), c.kind), "%s / %s", c.name, name)
		}
		for name, fn := range manageHO {
			assert.True(t, apperr.Is(fn(c.ctx), c.kind), "%s / %s", c.name, name)
		}
	}
	// Ops manages FAs but not HO users.
	ops := testutil.Ctx(testutil.HO(auth.RoleOps))
	for name, fn := range manageHO {
		assert.True(t, apperr.Is(fn(ops), apperr.KindForbidden), "ops / %s", name)
	}
	_, _, err := svc.CreateFA(ops, FACreate{})
	assert.True(t, apperr.Is(err, apperr.KindValidation), "ops passes the role check: %v", err)
}

func TestSelfProtection(t *testing.T) {
	svc := noDBService()
	admin := testutil.HO(auth.RoleAdmin)
	ctx := testutil.Ctx(admin)

	_, err := svc.SetHOAccountStatus(ctx, admin.ID, HODisabled)
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "own status")
	_, err = svc.ResetHOPassword(ctx, admin.ID)
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "own password reset")
	assert.True(t, apperr.Is(svc.ResetHOTOTP(ctx, admin.ID), apperr.KindForbidden), "own totp reset")
}

func TestHeartbeatNeedsMatchingTokenKind(t *testing.T) {
	svc := noDBService()
	_, err := svc.Heartbeat(testutil.Ctx(testutil.FA()), auth.KindFarmer, DeviceHeartbeat{})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	_, err = svc.Heartbeat(testutil.Ctx(auth.Principal{Kind: auth.KindFA, ID: ids.New()}), auth.KindFA, DeviceHeartbeat{})
	assert.True(t, apperr.Is(err, apperr.KindNotFound), "token without a device")
}

func TestValidateFACreate(t *testing.T) {
	s := func(v string) *string { return &v }
	ok := FACreate{AreaCode: s("KDP"), Name: " Suresh K ", Phone: "98480 12345", Level: "village"}
	p, err := validateFACreate(ok)
	require.NoError(t, err)
	assert.Equal(t, "Suresh K", p.Name)
	assert.Equal(t, "+919848012345", p.Phone)
	assert.Equal(t, []string{"te"}, p.Languages, "Telugu by default")
	assert.Empty(t, p.Code, "generated later from the area code")

	withCode := ok
	withCode.AreaCode, withCode.Code = nil, s("fa-kdp-014")
	p, err = validateFACreate(withCode)
	require.NoError(t, err)
	assert.Equal(t, "FA-KDP-014", p.Code, "codes are upper-cased")

	cases := map[string]struct {
		in    func(FACreate) FACreate
		field string
	}{
		"both codes":   {func(c FACreate) FACreate { c.Code = s("FA-KDP-001"); return c }, "code"},
		"no code":      {func(c FACreate) FACreate { c.AreaCode = nil; return c }, "code"},
		"bad code":     {func(c FACreate) FACreate { c.AreaCode, c.Code = nil, s("KDP-1"); return c }, "code"},
		"bad area":     {func(c FACreate) FACreate { c.AreaCode = s("K"); return c }, "area_code"},
		"blank name":   {func(c FACreate) FACreate { c.Name = "  "; return c }, "name"},
		"bad phone":    {func(c FACreate) FACreate { c.Phone = "12345"; return c }, "phone"},
		"bad level":    {func(c FACreate) FACreate { c.Level = "state"; return c }, "level"},
		"bad language": {func(c FACreate) FACreate { c.Languages = []string{"telugu"}; return c }, "languages"},
	}
	for name, c := range cases {
		_, err := validateFACreate(c.in(ok))
		e, isApp := apperr.As(err)
		require.True(t, isApp, name)
		assert.Contains(t, e.Details["fields"], c.field, name)
	}
}

func TestPasswordRules(t *testing.T) {
	assert.Error(t, validateNewPassword("short1", "old", "FA-KDP-014"))
	assert.Error(t, validateNewPassword("onlyletters", "old", "FA-KDP-014"))
	assert.Error(t, validateNewPassword("12345678", "old", "FA-KDP-014"))
	assert.Error(t, validateNewPassword("same-pass-1", "same-pass-1", "FA-KDP-014"))
	assert.Error(t, validateNewPassword("my-fa-kdp-014-x", "old", "FA-KDP-014"), "contains the login ID")
	assert.NoError(t, validateNewPassword("kondapur-2026", "old", "FA-KDP-014"))

	for range 50 {
		p := newTempPassword()
		assert.Len(t, p, 10)
		assert.Empty(t, checkPasswordRules(p))
		for _, r := range p {
			assert.True(t, strings.ContainsRune(tempPasswordAlphabet, r))
		}
	}
}

func TestOTPHashIsKeyedPerChallenge(t *testing.T) {
	svc := noDBService()
	a, b := ids.New(), ids.New()
	assert.Equal(t, svc.otpHash(a, "123456"), svc.otpHash(a, "123456"))
	assert.NotEqual(t, svc.otpHash(a, "123456"), svc.otpHash(b, "123456"), "same code, different challenge")
	assert.NotEqual(t, svc.otpHash(a, "123456"), svc.otpHash(a, "123457"))
}

func TestOTPSMSIsTeluguByDefault(t *testing.T) {
	te, id := otpSMS("123456", "te", 5*time.Minute, "")
	assert.Contains(t, te, "123456")
	assert.Contains(t, te, "లాగిన్")
	assert.Equal(t, sms.DLTLoginOTPTe, id)
	en, id := otpSMS("123456", "en", 5*time.Minute, "")
	assert.Contains(t, en, "sign-in code")
	assert.Equal(t, sms.DLTLoginOTPEn, id, "each language has its own DLT template")
	assert.NotContains(t, en, "<#>")
}

// With OTP_SMS_APP_HASH set the SMS follows the Android SMS Retriever format.
func TestOTPSMSWithAppHash(t *testing.T) {
	for _, lang := range []string{"te", "en"} {
		body, id := otpSMS("482913", lang, 5*time.Minute, "FA+9qCX9VSu")
		assert.True(t, strings.HasPrefix(body, "<#> 482913"), body)
		assert.True(t, strings.HasSuffix(body, "\nFA+9qCX9VSu"), body)
		assert.Equal(t, sms.LoginOTPRetriever.For(lang).ID, id)
	}
	te, _ := otpSMS("482913", "te", 5*time.Minute, "FA+9qCX9VSu")
	assert.LessOrEqual(t, len([]rune(te)), 70, "Telugu fits one Unicode SMS")
}
