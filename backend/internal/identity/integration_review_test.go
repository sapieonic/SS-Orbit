package identity

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// Regression tests for the review fixes.

// newFA creates an FA as admin and signs them in once; returns the FA, its
// temporary password and the sign-in.
func (e *env) newFA(t *testing.T, admin auth.Principal, code string) (FA, string) {
	t.Helper()
	fa, temp, err := e.svc.CreateFA(testutil.Ctx(admin), FACreate{Code: sp(code), Name: "FA " + code, Phone: "9848012345", Level: "village"})
	require.NoError(t, err)
	return fa, temp
}

// hoLogin signs a seeded HO user in with a fresh TOTP code.
func (e *env) hoLogin(t testing.TB, u store.HoUser) HOSignIn {
	t.Helper()
	e.clock.Advance(31 * time.Second) // a new TOTP step, so the code is not a replay
	code, err := auth.TOTPCode(*u.TotpSecret, e.clock.Now())
	require.NoError(t, err)
	in, err := e.svc.HOLogin(anonCtx(), u.Email, "Start-1234", &code)
	require.NoError(t, err)
	return in
}

func (e *env) principal(t testing.TB, access string) auth.Principal {
	t.Helper()
	p, err := testutil.Tokens().Verify(access)
	require.NoError(t, err)
	return p
}

// ---- FAR-04 consent OTP ----

func TestConsentOTP(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	fa, _ := e.newFA(t, admin, "FA-KDP-001")
	other, _ := e.newFA(t, admin, "FA-KDP-002")
	faP := auth.Principal{Kind: auth.KindFA, ID: fa.ID, DeviceID: ids.New()}
	otherP := auth.Principal{Kind: auth.KindFA, ID: other.ID, DeviceID: ids.New()}
	ctx := testutil.Ctx(faP)
	const farmerPhone = "98480 55555"

	_, err := e.svc.RequestConsentOTP(testutil.Ctx(testutil.HO(auth.RoleAdmin)), farmerPhone, "te")
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "FA only")

	sent, err := e.svc.RequestConsentOTP(ctx, farmerPhone, "te")
	require.NoError(t, err)
	assert.Equal(t, "+91******5555", sent.PhoneMasked)
	msg := e.sms.msgs[len(e.sms.msgs)-1]
	assert.Equal(t, "+919848055555", msg.To)
	assert.Equal(t, sms.DLTConsentOTPTe, msg.TemplateID, "Telugu wording, Telugu DLT ID")
	assert.Contains(t, msg.Body, "షణ్ముఖ అగ్రిటెక్", "Telugu, names who the data is shared with")
	code := e.sms.lastCode(t)

	// A sign-in code request for the same phone does not replace the consent code.
	_, err = e.svc.RequestOTP(anonCtx(), farmerPhone, "te")
	require.NoError(t, err)

	// Another FA cannot use this FA's code.
	_, err = e.svc.VerifyConsentOTP(testutil.Ctx(otherP), farmerPhone, code)
	assert.Equal(t, "otp_expired", appCode(err))

	wrong := "000000"
	if code == wrong {
		wrong = "111111"
	}
	_, err = e.svc.VerifyConsentOTP(ctx, farmerPhone, wrong)
	assert.Equal(t, "otp_invalid", appCode(err))

	out, err := e.svc.VerifyConsentOTP(ctx, farmerPhone, code)
	require.NoError(t, err)
	assert.Equal(t, "+919848055555", out.Phone)
	assert.Equal(t, out.VerifiedAt.Add(7*24*time.Hour), out.ExpiresAt)
	proof, err := testutil.Tokens().VerifyConsentProof(out.Proof)
	require.NoError(t, err)
	assert.Equal(t, fa.ID, proof.FAID)
	assert.Equal(t, "+919848055555", proof.Phone)

	_, err = e.svc.VerifyConsentOTP(ctx, farmerPhone, code)
	assert.Equal(t, "otp_expired", appCode(err), "single use")
	_, err = e.svc.VerifyOTP(anonCtx(), farmerPhone, code, AppDevice{Key: "install-consent"})
	assert.Error(t, err, "a consent code is not a sign-in code")

	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.consent_otp_sent' AND actor_id = $1`, fa.ID))
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.consent_otp_verified' AND actor_id = $1`, fa.ID))
	var audits string
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT string_agg(coalesce(meta::text,''), ',') FROM audit_log WHERE action LIKE 'identity.consent%'`).Scan(&audits))
	assert.NotContains(t, audits, code, "no codes in audit")
	assert.NotContains(t, audits, out.Proof, "no proofs in audit")

	// Rate limit per FA across phones (one request was made above).
	for i := range consentSendsPerFAHour - 1 {
		_, err = e.svc.RequestConsentOTP(ctx, fmt.Sprintf("97000001%02d", i), "en")
		require.NoError(t, err, "send %d", i)
	}
	_, err = e.svc.RequestConsentOTP(ctx, "9700000199", "en")
	assert.True(t, apperr.Is(err, apperr.KindRateLimited), "per-FA limit")
}

func TestConsentOTPDevFixedCode(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	fa, _ := e.newFA(t, admin, "FA-KDP-001")
	e.svc.deps.Config.Env = "dev"
	e.svc.deps.Config.DevFixedOTP = "123456"
	ctx := testutil.Ctx(auth.Principal{Kind: auth.KindFA, ID: fa.ID})
	_, err := e.svc.RequestConsentOTP(ctx, "9848012345", "en")
	require.NoError(t, err)
	out, err := e.svc.VerifyConsentOTP(ctx, "9848012345", "123456")
	require.NoError(t, err)
	assert.NotEmpty(t, out.Proof)
}

// ---- forced password change and temporary password expiry ----

func TestTemporaryPasswordFlagAndExpiry(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	_, temp := e.newFA(t, admin, "FA-KDP-014")
	ctx := anonCtx()

	in, err := e.svc.FALogin(ctx, "FA-KDP-014", temp, AppDevice{Key: "fa-phone-1"})
	require.NoError(t, err)
	p := e.principal(t, in.Tokens.Access)
	assert.True(t, p.MustChangePassword, "the access token carries the flag")
	next, err := e.svc.Refresh(ctx, in.Tokens.Refresh)
	require.NoError(t, err)
	assert.True(t, e.principal(t, next.Access).MustChangePassword, "and keeps it on refresh")

	require.NoError(t, e.svc.ChangeFAPassword(testutil.Ctx(p), temp, "Kondapur-2026"))
	e.clock.Advance(refreshGrace + time.Second)
	after, err := e.svc.Refresh(ctx, next.Refresh)
	require.NoError(t, err)
	assert.False(t, e.principal(t, after.Access).MustChangePassword, "refresh after the change drops the flag")

	// A reset password expires after 72 hours.
	_, temp2 := e.newFA(t, admin, "FA-KDP-015")
	held, err := e.svc.FALogin(ctx, "FA-KDP-015", temp2, AppDevice{Key: "fa-phone-2"})
	require.NoError(t, err)
	e.clock.Advance(tempPasswordTTL + time.Minute)
	_, err = e.svc.FALogin(ctx, "FA-KDP-015", temp2, AppDevice{Key: "fa-phone-2"})
	assert.Equal(t, "temp_password_expired", appCode(err))
	_, err = e.svc.FALogin(ctx, "FA-KDP-015", "wrong-pass-1", AppDevice{Key: "fa-phone-2"})
	assert.Equal(t, errBadFALogin, err, "wrong password says nothing about expiry")
	err = e.svc.ChangeFAPassword(testutil.Ctx(e.principal(t, held.Tokens.Access)), temp2, "Kondapur-2027")
	assert.Equal(t, "temp_password_expired", appCode(err))
	_, err = e.svc.Refresh(ctx, held.Tokens.Refresh)
	assert.Equal(t, "temp_password_expired", appCode(err), "a session on an expired temp password ends")

	// The admin resets again: works for another 72 hours.
	fa15, err := e.svc.q.GetFieldAssistantByCode(context.Background(), "FA-KDP-015")
	require.NoError(t, err)
	temp3, err := e.svc.ResetFAPassword(testutil.Ctx(admin), fa15.ID)
	require.NoError(t, err)
	_, err = e.svc.FALogin(ctx, "FA-KDP-015", temp3, AppDevice{Key: "fa-phone-2"})
	require.NoError(t, err)
}

func TestHOTemporaryPasswordExpiry(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	_, temp, err := e.svc.CreateHOAccount(testutil.Ctx(admin), NewHOAccount{Email: "new@orbit.test", Name: "New", Role: "ops"})
	require.NoError(t, err)
	e.clock.Advance(tempPasswordTTL + time.Minute)
	_, err = e.svc.HOLogin(anonCtx(), "new@orbit.test", temp, nil)
	assert.Equal(t, "temp_password_expired", appCode(err))
	_, err = e.svc.StartTOTPEnrolment(anonCtx(), "new@orbit.test", temp)
	assert.Equal(t, "temp_password_expired", appCode(err))
}

// ---- HO area scope on FA management ----

func TestFAAreaScope(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	kadapa, kurnool := ids.New(), ids.New()
	inKadapa, _ := e.newFA(t, admin, "FA-KDP-001")
	inKurnool, _ := e.newFA(t, admin, "FA-KNL-001")
	unallocated, _ := e.newFA(t, admin, "FA-NEW-001")
	e.geo.allocate(inKadapa.ID, kadapa)
	e.geo.allocate(inKurnool.ID, kurnool)
	_, err := e.svc.FALogin(anonCtx(), "FA-KNL-001", "x", AppDevice{Key: "x"}) // nothing; keep devices empty
	require.Error(t, err)

	scopedOps := testutil.Ctx(testutil.HO(auth.RoleOps, kadapa))
	scopedAdmin := testutil.Ctx(testutil.HO(auth.RoleAdmin, kadapa))

	page, err := e.svc.ListFAs(scopedOps, FAFilter{}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	assert.Equal(t, inKadapa.ID, page.Items[0].ID)

	page, err = e.svc.ListFAs(scopedAdmin, FAFilter{}, nil, nil)
	require.NoError(t, err)
	got := []uuid.UUID{}
	for _, f := range page.Items {
		got = append(got, f.ID)
	}
	assert.ElementsMatch(t, []uuid.UUID{inKadapa.ID, unallocated.ID}, got, "scoped admin also sees unallocated FAs")

	page, err = e.svc.ListFAs(testutil.Ctx(admin), FAFilter{}, nil, nil)
	require.NoError(t, err)
	assert.Len(t, page.Items, 3, "unscoped sees all")

	// Paging stays exact under scope.
	page, err = e.svc.ListFAs(scopedAdmin, FAFilter{}, ip(1), nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	require.NotNil(t, page.NextCursor)
	page2, err := e.svc.ListFAs(scopedAdmin, FAFilter{}, ip(1), page.NextCursor)
	require.NoError(t, err)
	require.Len(t, page2.Items, 1)
	assert.Nil(t, page2.NextCursor)

	_, err = e.svc.GetFA(scopedOps, inKadapa.ID)
	require.NoError(t, err)
	for name, call := range map[string]func() error{
		"get":      func() error { _, err := e.svc.GetFA(scopedOps, inKurnool.ID); return err },
		"update":   func() error { _, err := e.svc.UpdateFA(scopedOps, inKurnool.ID, FAPatch{Name: sp("x")}); return err },
		"status":   func() error { _, err := e.svc.SetFAStatus(scopedOps, inKurnool.ID, FAInactive); return err },
		"reset":    func() error { _, err := e.svc.ResetFAPassword(scopedOps, inKurnool.ID); return err },
		"sign-out": func() error { return e.svc.SignOutFA(scopedOps, inKurnool.ID) },
		"devices": func() error {
			_, err := e.svc.ListDevices(scopedOps, SubjectFA, inKurnool.ID, nil, nil)
			return err
		},
		"unallocated": func() error { _, err := e.svc.GetFA(scopedOps, unallocated.ID); return err },
	} {
		assert.True(t, apperr.Is(call(), apperr.KindNotFound), name)
	}

	// Device revoke follows the device's FA.
	knlDevice, err := e.svc.FALogin(anonCtx(), "FA-KNL-001", e.resetFA(t, admin, inKurnool.ID), AppDevice{Key: "knl-phone"})
	require.NoError(t, err)
	_, err = e.svc.RevokeDevice(scopedOps, knlDevice.DeviceID, "lost")
	assert.True(t, apperr.Is(err, apperr.KindNotFound))
	_, err = e.svc.RevokeDevice(testutil.Ctx(testutil.HO(auth.RoleOps, kurnool)), knlDevice.DeviceID, "lost")
	require.NoError(t, err)

	// Stats follow the same scope.
	_, err = e.svc.SetFAStatus(testutil.Ctx(admin), unallocated.ID, FALeaving)
	require.NoError(t, err)
	require.NoError(t, e.svc.MarkSynced(context.Background(), inKadapa.ID, uuid.Nil, e.clock.Now()))
	all, err := e.svc.FAStats(testutil.Ctx(testutil.HO(auth.RoleFinance)))
	require.NoError(t, err)
	assert.Equal(t, FACounts{Active: 2, Leaving: 1, SyncedLast24h: 1}, all)
	scoped, err := e.svc.FAStats(scopedOps)
	require.NoError(t, err)
	assert.Equal(t, FACounts{Active: 1, SyncedLast24h: 1}, scoped)
}

func (e *env) resetFA(t *testing.T, admin auth.Principal, id uuid.UUID) string {
	t.Helper()
	temp, err := e.svc.ResetFAPassword(testutil.Ctx(admin), id)
	require.NoError(t, err)
	return temp
}

func ip(n int) *int { return &n }

// ---- revocation check for the surface guard ----

func TestCheckPrincipal(t *testing.T) {
	e := newEnv(t)
	adminRow, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	opsRow, _ := e.seedHO(t, "ops@orbit.test", auth.RoleOps, true)
	ctx := context.Background()

	// Farmer device revoked: its unexpired access token stops working.
	login := e.farmerLogin(t, "9000000021", "install-guard")
	fp := e.principal(t, login.Tokens.Access)
	require.NoError(t, e.svc.CheckPrincipal(ctx, fp))
	_, err := e.svc.RevokeDevice(testutil.Ctx(admin), login.DeviceID, "stolen")
	require.NoError(t, err)
	assert.Equal(t, "device_revoked", appCode(e.svc.CheckPrincipal(ctx, fp)))

	// HO sign-out ends the access token too.
	in := e.hoLogin(t, opsRow)
	hp := e.principal(t, in.Tokens.Access)
	require.NoError(t, e.svc.CheckPrincipal(ctx, hp))
	require.NoError(t, e.svc.Logout(testutil.Ctx(hp), nil))
	assert.Equal(t, "session_revoked", appCode(e.svc.CheckPrincipal(ctx, hp)))

	// Disabling the user ends their live sessions.
	in = e.hoLogin(t, opsRow)
	hp = e.principal(t, in.Tokens.Access)
	_, err = e.svc.SetHOAccountStatus(testutil.Ctx(admin), opsRow.ID, HODisabled)
	require.NoError(t, err)
	assert.Equal(t, "session_revoked", appCode(e.svc.CheckPrincipal(ctx, hp)))

	// A token whose session row does not exist (dev tokens) still passes,
	// unless the user is disabled.
	require.NoError(t, e.svc.CheckPrincipal(ctx, auth.Principal{Kind: auth.KindHO, ID: adminRow.ID, SessionID: ids.New()}))
	assert.Equal(t, "session_revoked", appCode(e.svc.CheckPrincipal(ctx, auth.Principal{Kind: auth.KindHO, ID: opsRow.ID, SessionID: ids.New()})))
}

// ---- TOTP secrets at rest ----

func TestTOTPSecretsSealedAtRest(t *testing.T) {
	e := newEnv(t)
	legacy, _ := e.seedHO(t, "legacy@orbit.test", auth.RoleOps, true) // seeded in clear, like pre-00016 rows
	other, _ := e.seedHO(t, "other@orbit.test", auth.RoleOps, true)
	stored := func(id uuid.UUID) string {
		var s string
		require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT totp_secret FROM ho_users WHERE id = $1`, id).Scan(&s))
		return s
	}
	assert.Equal(t, *legacy.TotpSecret, stored(legacy.ID))

	// Sign-in still works with a legacy secret and seals it.
	e.hoLogin(t, legacy)
	sealed := stored(legacy.ID)
	assert.True(t, strings.HasPrefix(sealed, totpSealPrefix), sealed)
	assert.NotContains(t, sealed, *legacy.TotpSecret)
	e.hoLogin(t, legacy) // and keeps working sealed

	// The maintenance sweep seals the rest.
	r, err := e.svc.RunMaintenance(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 1, r.TOTPSecretsSealed)
	assert.True(t, strings.HasPrefix(stored(other.ID), totpSealPrefix))

	// A sealed secret is bound to its user.
	_, _, err = e.svc.openTOTP(other.ID, sealed)
	assert.Error(t, err)

	// New enrolments are stored sealed.
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	created, temp, err := e.svc.CreateHOAccount(testutil.Ctx(admin), NewHOAccount{Email: "new@orbit.test", Name: "New", Role: "ops"})
	require.NoError(t, err)
	enrol, err := e.svc.StartTOTPEnrolment(anonCtx(), "new@orbit.test", temp)
	require.NoError(t, err)
	assert.NotContains(t, stored(created.ID), enrol.Secret)
	code, err := auth.TOTPCode(enrol.Secret, e.clock.Now())
	require.NoError(t, err)
	_, err = e.svc.ConfirmTOTPEnrolment(anonCtx(), "new@orbit.test", temp, code)
	require.NoError(t, err)
	assert.True(t, strings.HasPrefix(stored(created.ID), totpSealPrefix))
}

// ---- retention ----

func TestMaintenanceRetention(t *testing.T) {
	e := newEnv(t)
	ctx := context.Background()
	now := e.clock.Now()
	_, err := e.pool.Exec(ctx, `INSERT INTO otp_challenges (id, phone, code_hash, max_attempts, expires_at, created_at)
		VALUES ($1, '+919000000001', '\x00', 5, $2, $2), ($3, '+919000000002', '\x00', 5, $4, $4)`,
		ids.New(), now.Add(-25*time.Hour), ids.New(), now.Add(-time.Hour))
	require.NoError(t, err)
	sid := func() uuid.UUID { return ids.New() }
	_, err = e.pool.Exec(ctx, `INSERT INTO sessions (id, subject_kind, subject_id, family_id, refresh_token_hash, expires_at, revoked_at) VALUES
		($1, 'ho', $1, $1, '\x01', $5, NULL),  -- expired 31 days ago
		($2, 'ho', $2, $2, '\x02', $6, $5),    -- revoked 31 days ago
		($3, 'ho', $3, $3, '\x03', $6, $7),    -- revoked yesterday
		($4, 'ho', $4, $4, '\x04', $6, NULL)   -- live`,
		sid(), sid(), sid(), sid(), now.Add(-31*24*time.Hour), now.Add(24*time.Hour), now.Add(-24*time.Hour))
	require.NoError(t, err)
	_, err = e.pool.Exec(ctx, `INSERT INTO rate_limit_counters (key, window_start, count) VALUES ('old', $1, 1), ('new', $2, 1)`,
		now.Add(-72*time.Hour), now.Add(-time.Minute))
	require.NoError(t, err)

	r, err := e.svc.RunMaintenance(ctx)
	require.NoError(t, err)
	assert.Equal(t, MaintenanceResult{OTPChallengesDeleted: 1, SessionsDeleted: 2, RateCountersDeleted: 1}, r)
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM otp_challenges`))
	assert.Equal(t, 2, e.count(t, `SELECT count(*) FROM sessions`))
	assert.Len(t, PeriodicJobs(), 1)
}

// ---- provider methods ----

func TestFAsNotSyncedSinceAndLastSync(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	synced, _ := e.newFA(t, admin, "FA-KDP-001")
	stale, _ := e.newFA(t, admin, "FA-KDP-002")
	never, _ := e.newFA(t, admin, "FA-KDP-003")
	gone, _ := e.newFA(t, admin, "FA-KDP-004")
	ctx := context.Background()
	now := e.clock.Now()
	require.NoError(t, e.svc.MarkSynced(ctx, synced.ID, uuid.Nil, now))
	require.NoError(t, e.svc.MarkSynced(ctx, stale.ID, uuid.Nil, now.Add(-3*24*time.Hour)))
	_, err := e.svc.SetFAStatus(testutil.Ctx(admin), gone.ID, FAInactive)
	require.NoError(t, err)

	codes := func(since time.Time) []string {
		list, err := e.svc.FAsNotSyncedSince(ctx, since)
		require.NoError(t, err)
		out := []string{}
		for _, f := range list {
			out = append(out, f.Code)
		}
		return out
	}
	assert.Equal(t, []string{"FA-KDP-002"}, codes(now.Add(-24*time.Hour)), "the never-synced FA is newer than the cut-off")
	assert.Equal(t, []string{"FA-KDP-001", "FA-KDP-002", "FA-KDP-003"}, codes(time.Now().Add(time.Hour)),
		"active only; never-synced included once older than the cut-off")

	fas, err := e.svc.GetFieldAssistants(ctx, []uuid.UUID{synced.ID, never.ID})
	require.NoError(t, err)
	require.Len(t, fas, 2)
	require.NotNil(t, fas[0].LastSyncAt)
	assert.WithinDuration(t, now, *fas[0].LastSyncAt, time.Millisecond)
	assert.Nil(t, fas[1].LastSyncAt)
}

// ---- over HTTP, with the production guard wiring ----

func TestHTTPReviewFixes(t *testing.T) {
	e := newEnv(t)
	adminRow, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	_, err := e.pool.Exec(context.Background(), `UPDATE ho_users SET must_change_password = false WHERE id = $1`, adminRow.ID)
	require.NoError(t, err)
	tokens := testutil.Tokens()
	m := &Module{svc: e.svc, handler: &handler{svc: e.svc}}
	router := httpx.NewRouter(httpx.RouterConfig{Logger: logx.Discard(), Tokens: tokens, CheckPrincipal: e.svc.CheckPrincipal})
	m.Mount(router)

	// FA on a temporary password: only the password change works.
	_, temp := e.newFA(t, admin, "FA-KDP-001")
	rec := do(t, router, "POST", "/v1/auth/fa/login", "", map[string]any{"code": "FA-KDP-001", "password": temp,
		"device": map[string]any{"device_key": "fa-install-1"}})
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var fs FASession
	require.NoError(t, jsonUnmarshal(rec.Body.Bytes(), &fs))
	rec = do(t, router, "POST", "/v1/fa/consent-otp/request", fs.Tokens.AccessToken, map[string]any{"phone": "9848012345"})
	require.Equal(t, http.StatusForbidden, rec.Code, rec.Body.String())
	assert.Contains(t, rec.Body.String(), "password_change_required")
	rec = do(t, router, "POST", "/v1/fa/me/password", fs.Tokens.AccessToken, map[string]any{"current_password": temp, "new_password": "Kondapur-2026"})
	require.Equal(t, 204, rec.Code, rec.Body.String())
	e.clock.Advance(refreshGrace + time.Second)
	rec = do(t, router, "POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": fs.Tokens.RefreshToken})
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var pair TokenPair
	require.NoError(t, jsonUnmarshal(rec.Body.Bytes(), &pair))

	// Consent OTP over HTTP.
	rec = do(t, router, "POST", "/v1/fa/consent-otp/request", pair.AccessToken, map[string]any{"phone": "9848012345", "language": "en"})
	require.Equal(t, 200, rec.Code, rec.Body.String())
	rec = do(t, router, "POST", "/v1/fa/consent-otp/verify", pair.AccessToken, map[string]any{"phone": "9848012345", "code": e.sms.lastCode(t)})
	require.Equal(t, 200, rec.Code, rec.Body.String())
	var cp ConsentProof
	require.NoError(t, jsonUnmarshal(rec.Body.Bytes(), &cp))
	assert.NotEmpty(t, cp.OtpProof)
	assert.Equal(t, "+919848012345", cp.Phone)

	// Stats route is not taken for /{fa_id}.
	in := e.hoLogin(t, adminRow)
	rec = do(t, router, "GET", "/v1/admin/field-assistants/stats", in.Tokens.Access, nil)
	require.Equal(t, 200, rec.Code, rec.Body.String())
	assert.JSONEq(t, `{"active":1,"leaving":0,"inactive":0,"synced_last_24h":0}`, rec.Body.String())

	// HO sign-out: the access token stops working at once.
	rec = do(t, router, "POST", "/v1/auth/logout", in.Tokens.Access, nil)
	require.Equal(t, 204, rec.Code)
	rec = do(t, router, "GET", "/v1/admin/me", in.Tokens.Access, nil)
	require.Equal(t, 401, rec.Code, rec.Body.String())
	assert.Contains(t, rec.Body.String(), "session_revoked")
}
