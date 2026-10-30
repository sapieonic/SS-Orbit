package identity

import (
	"context"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

var district1 = ids.New()

func TestFarmerOTPSignIn(t *testing.T) {
	e := newEnv(t)
	ctx := anonCtx()
	const phone = "98480 12345"

	sent, err := e.svc.RequestOTP(ctx, phone, "te")
	require.NoError(t, err)
	assert.Equal(t, "+91******2345", sent.PhoneMasked)
	assert.Equal(t, 30*time.Second, sent.ResendAfter)
	code := e.sms.lastCode(t)
	assert.Equal(t, "+919848012345", e.sms.msgs[0].To)
	assert.Contains(t, e.sms.msgs[0].Body, "లాగిన్", "Telugu SMS")
	assert.Equal(t, 0, e.count(t, `SELECT count(*) FROM otp_challenges WHERE position($1::bytea in code_hash) > 0`, []byte(code)),
		"the code is never stored in clear")

	// Resend within 30 s is refused.
	_, err = e.svc.RequestOTP(ctx, phone, "te")
	assert.True(t, apperr.Is(err, apperr.KindRateLimited), "%v", err)

	// Wrong code counts an attempt, and the count survives the error.
	wrong := "000000"
	if code == wrong {
		wrong = "111111"
	}
	_, err = e.svc.VerifyOTP(ctx, phone, wrong, AppDevice{Key: "install-aaaa"})
	require.Equal(t, "otp_invalid", appCode(err))
	ae, _ := apperr.As(err)
	assert.Equal(t, 4, ae.Details["attempts_left"])

	// Right code signs in and creates the farmer.
	out, err := e.svc.VerifyOTP(ctx, "+91 98480-12345", code, AppDevice{Key: "install-aaaa", AppVersion: sp("1.0.0")})
	require.NoError(t, err)
	assert.True(t, out.IsNew)
	require.NotNil(t, out.FarmerStatus)
	assert.Equal(t, "pending_profile", *out.FarmerStatus)
	p, err := testutil.Tokens().Verify(out.Tokens.Access)
	require.NoError(t, err)
	assert.Equal(t, auth.KindFarmer, p.Kind)
	assert.Equal(t, out.FarmerID, p.ID)
	assert.Equal(t, out.DeviceID, p.DeviceID)
	assert.NotEqual(t, p.SessionID.String(), "00000000-0000-0000-0000-000000000000")
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.farmer_login_issued' AND farmer_id = $1 AND actor_id = $1`, out.FarmerID))

	// The code is single use.
	_, err = e.svc.VerifyOTP(ctx, phone, code, AppDevice{Key: "install-aaaa"})
	assert.Equal(t, "otp_expired", appCode(err))

	// Second sign-in finds the same farmer and the same device.
	e.clock.Advance(31 * time.Second)
	again := e.farmerLogin(t, phone, "install-aaaa")
	assert.False(t, again.IsNew)
	assert.Equal(t, out.FarmerID, again.FarmerID)
	assert.Equal(t, out.DeviceID, again.DeviceID)
}

func TestOTPExpiryAndAttemptLimit(t *testing.T) {
	e := newEnv(t)
	ctx := anonCtx()
	const phone = "9000000001"

	_, err := e.svc.RequestOTP(ctx, phone, "en")
	require.NoError(t, err)
	assert.Contains(t, e.sms.msgs[0].Body, "sign-in code")
	code := e.sms.lastCode(t)
	e.clock.Advance(5*time.Minute + time.Second)
	_, err = e.svc.VerifyOTP(ctx, phone, code, AppDevice{Key: "install-bbbb"})
	assert.Equal(t, "otp_expired", appCode(err), "expired after OTP_TTL")

	_, err = e.svc.RequestOTP(ctx, phone, "te")
	require.NoError(t, err)
	code = e.sms.lastCode(t)
	wrong := "000000"
	if code == wrong {
		wrong = "111111"
	}
	for i := range otpMaxAttempts {
		_, err = e.svc.VerifyOTP(ctx, phone, wrong, AppDevice{Key: "install-bbbb"})
		assert.Equal(t, "otp_invalid", appCode(err), "attempt %d", i+1)
	}
	_, err = e.svc.VerifyOTP(ctx, phone, code, AppDevice{Key: "install-bbbb"})
	assert.Equal(t, "otp_expired", appCode(err), "locked after too many wrong codes, even with the right one")
}

func TestRefreshRotationAndReuse(t *testing.T) {
	e := newEnv(t)
	login := e.farmerLogin(t, "9000000002", "install-cccc")
	ctx := anonCtx()

	next, err := e.svc.Refresh(ctx, login.Tokens.Refresh)
	require.NoError(t, err)
	assert.NotEqual(t, login.Tokens.Refresh, next.Refresh)
	p, err := testutil.Tokens().Verify(next.Access)
	require.NoError(t, err)
	assert.Equal(t, login.DeviceID, p.DeviceID)

	// Replaying the rotated token after the grace window revokes the whole family.
	e.clock.Advance(refreshGrace + time.Second)
	_, err = e.svc.Refresh(ctx, login.Tokens.Refresh)
	assert.Equal(t, "refresh_reused", appCode(err))
	_, err = e.svc.Refresh(ctx, next.Refresh)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized), "the newest token died with its family")
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.refresh_reuse_detected'`))

	_, err = e.svc.Refresh(ctx, "not-a-real-refresh-token-at-all")
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))

	// Expiry.
	login2 := e.farmerLogin(t, "9000000003", "install-dddd")
	e.clock.Advance(91 * 24 * time.Hour)
	_, err = e.svc.Refresh(ctx, login2.Tokens.Refresh)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))
}

// TestRefreshRetryGetsSameSuccessor: on 2G the refresh response is lost and the
// app retries with the old token. Inside the grace window it gets the same
// successor, no third session is minted, and the family stays alive.
func TestRefreshRetryGetsSameSuccessor(t *testing.T) {
	e := newEnv(t)
	login := e.farmerLogin(t, "9000000012", "install-retry")
	ctx := anonCtx()

	first, err := e.svc.Refresh(ctx, login.Tokens.Refresh) // response "lost"
	require.NoError(t, err)
	e.clock.Advance(45 * time.Second)
	retry, err := e.svc.Refresh(ctx, login.Tokens.Refresh)
	require.NoError(t, err)
	assert.Equal(t, first.Refresh, retry.Refresh, "same successor")
	assert.Equal(t, first.RefreshExpiresAt, retry.RefreshExpiresAt)
	p1, err := testutil.Tokens().Verify(first.Access)
	require.NoError(t, err)
	p2, err := testutil.Tokens().Verify(retry.Access)
	require.NoError(t, err)
	assert.Equal(t, p1.SessionID, p2.SessionID)
	assert.Equal(t, 2, e.count(t, `SELECT count(*) FROM sessions WHERE subject_id = $1`, login.FarmerID), "no third session")
	assert.Equal(t, 0, e.count(t, `SELECT count(*) FROM sessions WHERE subject_id = $1 AND revoked_at IS NOT NULL`, login.FarmerID))

	// The successor works normally afterwards.
	third, err := e.svc.Refresh(ctx, retry.Refresh)
	require.NoError(t, err)
	assert.NotEqual(t, retry.Refresh, third.Refresh)

	// Once the successor has been used, the old token is plain reuse even
	// inside the window.
	_, err = e.svc.Refresh(ctx, login.Tokens.Refresh)
	assert.Equal(t, "refresh_reused", appCode(err))
	_, err = e.svc.Refresh(ctx, third.Refresh)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized), "family revoked")
}

// TestParallelRefreshes: two requests that both got a 401 refresh with the
// same token at once. Both succeed with the same successor.
func TestParallelRefreshes(t *testing.T) {
	e := newEnv(t)
	login := e.farmerLogin(t, "9000000013", "install-parallel")

	const n = 4
	results := make([]Tokens, n)
	errs := make([]error, n)
	var wg sync.WaitGroup
	for i := range n {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results[i], errs[i] = e.svc.Refresh(anonCtx(), login.Tokens.Refresh)
		}()
	}
	wg.Wait()
	for i := range n {
		require.NoError(t, errs[i], "request %d", i)
		assert.Equal(t, results[0].Refresh, results[i].Refresh, "request %d got the same successor", i)
	}
	assert.Equal(t, 2, e.count(t, `SELECT count(*) FROM sessions WHERE subject_id = $1`, login.FarmerID))
	_, err := e.svc.Refresh(anonCtx(), results[0].Refresh)
	require.NoError(t, err, "family still alive")
}

func TestLogout(t *testing.T) {
	e := newEnv(t)
	login := e.farmerLogin(t, "9000000004", "install-eeee")
	p, err := testutil.Tokens().Verify(login.Tokens.Access)
	require.NoError(t, err)

	require.NoError(t, e.svc.Logout(testutil.Ctx(p), nil))
	_, err = e.svc.Refresh(anonCtx(), login.Tokens.Refresh)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))
	require.NoError(t, e.svc.Logout(testutil.Ctx(p), nil), "logout is idempotent")

	// Logout with only the refresh token.
	login2 := e.farmerLogin(t, "9000000005", "install-ffff")
	require.NoError(t, e.svc.Logout(anonCtx(), &login2.Tokens.Refresh))
	_, err = e.svc.Refresh(anonCtx(), login2.Tokens.Refresh)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))
	assert.Equal(t, 2, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.logged_out'`))
}

func TestFALoginAndPasswordChange(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	actx := testutil.Ctx(admin)

	fa, temp, err := e.svc.CreateFA(actx, FACreate{Code: sp("FA-KDP-014"), Name: "Suresh K", Phone: "9848012345", Level: "village"})
	require.NoError(t, err)
	ctx := anonCtx()

	// Wrong password, unknown ID: same generic error.
	_, err = e.svc.FALogin(ctx, "FA-KDP-014", "wrong-pass-1", AppDevice{Key: "fa-phone-1"})
	assert.Equal(t, errBadFALogin, err)
	_, err = e.svc.FALogin(ctx, "FA-NOPE-001", "wrong-pass-1", AppDevice{Key: "fa-phone-1"})
	assert.Equal(t, errBadFALogin, err)
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.login_failed' AND entity_id = $1`, fa.ID))

	// Temp password works (login ID is case-insensitive) and must be changed.
	in, err := e.svc.FALogin(ctx, "fa-kdp-014", temp, AppDevice{Key: "fa-phone-1", PushToken: sp("push-1")})
	require.NoError(t, err)
	assert.True(t, in.FA.MustChangePassword)
	assert.Equal(t, OfflineRules{PinLength: 4, OfflineGraceDays: 7, PinMaxAttempts: 5}, in.OfflineRules)
	p, err := testutil.Tokens().Verify(in.Tokens.Access)
	require.NoError(t, err)
	assert.Equal(t, auth.KindFA, p.Kind)
	assert.Equal(t, in.DeviceID, p.DeviceID)

	// A second device session, to check the change signs out the others.
	other, err := e.svc.FALogin(ctx, "FA-KDP-014", temp, AppDevice{Key: "fa-phone-2"})
	require.NoError(t, err)

	fctx := testutil.Ctx(p)
	err = e.svc.ChangeFAPassword(fctx, "wrong", "Kondapur-2026")
	assert.True(t, apperr.Is(err, apperr.KindValidation))
	err = e.svc.ChangeFAPassword(fctx, temp, "short")
	assert.True(t, apperr.Is(err, apperr.KindValidation))
	require.NoError(t, e.svc.ChangeFAPassword(fctx, temp, "Kondapur-2026"))

	_, err = e.svc.Refresh(ctx, other.Tokens.Refresh)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized), "other sessions are signed out")
	_, err = e.svc.Refresh(ctx, in.Tokens.Refresh)
	assert.NoError(t, err, "the current session survives")

	_, err = e.svc.FALogin(ctx, "FA-KDP-014", temp, AppDevice{Key: "fa-phone-1"})
	assert.Equal(t, errBadFALogin, err, "old password no longer works")
	again, err := e.svc.FALogin(ctx, "FA-KDP-014", "Kondapur-2026", AppDevice{Key: "fa-phone-1"})
	require.NoError(t, err)
	assert.False(t, again.FA.MustChangePassword)
	assert.Equal(t, in.DeviceID, again.DeviceID, "same install, same device row")

	var hashes, audits string
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT string_agg(password_hash, ',') FROM field_assistants`).Scan(&hashes))
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT string_agg(coalesce(before::text,'') || coalesce(after::text,'') || coalesce(meta::text,''), ',') FROM audit_log`).Scan(&audits))
	assert.NotContains(t, audits, temp, "no secrets in the audit log")
	assert.NotContains(t, audits, "Kondapur-2026")
	assert.NotContains(t, audits, hashes)
}

func TestFALoginRateLimit(t *testing.T) {
	e := newEnv(t)
	ctx := anonCtx()
	var err error
	for range loginPerAccount15Min {
		_, err = e.svc.FALogin(ctx, "FA-KDP-001", "x", AppDevice{Key: "fa-phone-9"})
		require.Equal(t, errBadFALogin, err)
	}
	_, err = e.svc.FALogin(ctx, "FA-KDP-001", "x", AppDevice{Key: "fa-phone-9"})
	assert.True(t, apperr.Is(err, apperr.KindRateLimited))
}

func TestHOSignInWithTOTP(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	created, temp, err := e.svc.CreateHOAccount(testutil.Ctx(admin), NewHOAccount{Email: " Priya@Orbit.TEST ", Name: "Priya",
		Role: "finance", DistrictIDs: []uuid.UUID{district1}})
	require.NoError(t, err)
	assert.Equal(t, "priya@orbit.test", created.Email)
	assert.Equal(t, HOInvited, created.Status)
	ctx := anonCtx()

	// Correct password but no TOTP yet.
	_, err = e.svc.HOLogin(ctx, "priya@orbit.test", temp, nil)
	assert.Equal(t, "totp_enrolment_required", appCode(err))
	_, err = e.svc.HOLogin(ctx, "priya@orbit.test", "wrong", nil)
	assert.Equal(t, errBadHOLogin, err, "wrong password never reveals the TOTP state")

	enrol, err := e.svc.StartTOTPEnrolment(ctx, "PRIYA@orbit.test", temp)
	require.NoError(t, err)
	assert.True(t, strings.HasPrefix(enrol.URL, "otpauth://totp/"))
	_, err = e.svc.ConfirmTOTPEnrolment(ctx, "priya@orbit.test", temp, "000000")
	assert.Equal(t, "totp_invalid", appCode(err))
	code, err := auth.TOTPCode(enrol.Secret, e.clock.Now())
	require.NoError(t, err)
	in, err := e.svc.ConfirmTOTPEnrolment(ctx, "priya@orbit.test", temp, code)
	require.NoError(t, err)
	assert.Equal(t, HOActive, in.User.Status)
	assert.True(t, in.User.MustChangePassword)
	p, err := testutil.Tokens().Verify(in.Tokens.Access)
	require.NoError(t, err)
	assert.Equal(t, auth.RoleFinance, p.Role)
	assert.Equal(t, []uuid.UUID{district1}, p.DistrictIDs)

	_, err = e.svc.StartTOTPEnrolment(ctx, "priya@orbit.test", temp)
	assert.Equal(t, "totp_already_enabled", appCode(err))

	// A code works once.
	_, err = e.svc.HOLogin(ctx, "priya@orbit.test", temp, &code)
	assert.Equal(t, errBadHOLogin, err, "replayed code")
	e.clock.Advance(30 * time.Second)
	code2, _ := auth.TOTPCode(enrol.Secret, e.clock.Now())
	in2, err := e.svc.HOLogin(ctx, "priya@orbit.test", temp, &code2)
	require.NoError(t, err)

	// HO sessions keep their absolute end on refresh.
	next, err := e.svc.Refresh(ctx, in2.Tokens.Refresh)
	require.NoError(t, err)
	assert.Equal(t, in2.Tokens.RefreshExpiresAt.Unix(), next.RefreshExpiresAt.Unix())

	// Role change applies at the next refresh; disabling ends the session.
	finance := testutil.Ctx(auth.Principal{Kind: auth.KindHO, ID: created.ID, Role: auth.RoleFinance})
	_, err = e.svc.Me(finance)
	require.NoError(t, err)
	_, err = e.svc.UpdateHOAccount(testutil.Ctx(admin), created.ID, HOAccountPatch{Role: sp("ops")})
	require.NoError(t, err)
	next, err = e.svc.Refresh(ctx, next.Refresh)
	require.NoError(t, err)
	p, _ = testutil.Tokens().Verify(next.Access)
	assert.Equal(t, auth.RoleOps, p.Role)
	_, err = e.svc.SetHOAccountStatus(testutil.Ctx(admin), created.ID, HODisabled)
	require.NoError(t, err)
	_, err = e.svc.Refresh(ctx, next.Refresh)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))
	e.clock.Advance(30 * time.Second)
	code3, _ := auth.TOTPCode(enrol.Secret, e.clock.Now())
	_, err = e.svc.HOLogin(ctx, "priya@orbit.test", temp, &code3)
	assert.Equal(t, errBadHOLogin, err, "disabled users cannot sign in")
}
