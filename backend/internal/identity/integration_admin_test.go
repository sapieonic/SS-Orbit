package identity

import (
	"context"
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

func TestFACodesAndProfile(t *testing.T) {
	e := newEnv(t)
	_, ops := e.seedHO(t, "ops@orbit.test", auth.RoleOps, true)
	ctx := testutil.Ctx(ops)
	mk := func(code, area *string) (FA, error) {
		fa, _, err := e.svc.CreateFA(ctx, FACreate{Code: code, AreaCode: area, Name: "FA", NameTe: sp("ఎఫ్ఏ"), Phone: "9848012345", Level: "mandal"})
		return fa, err
	}
	a, err := mk(nil, sp("KDP"))
	require.NoError(t, err)
	assert.Equal(t, "FA-KDP-001", a.Code)
	b, err := mk(nil, sp("KDP"))
	require.NoError(t, err)
	assert.Equal(t, "FA-KDP-002", b.Code)
	_, err = mk(sp("FA-KDP-014"), nil)
	require.NoError(t, err)
	c, err := mk(nil, sp("KDP"))
	require.NoError(t, err)
	assert.Equal(t, "FA-KDP-015", c.Code, "continues after the highest number")
	d, err := mk(nil, sp("KD"))
	require.NoError(t, err)
	assert.Equal(t, "FA-KD-001", d.Code, "areas are independent")
	_, err = mk(sp("FA-KDP-014"), nil)
	assert.Equal(t, "code_taken", appCode(err))
	assert.Equal(t, "active", a.Status)
	assert.True(t, a.MustChangePassword)

	// Patch: only sent fields change; empty string clears.
	up, err := e.svc.UpdateFA(ctx, a.ID, FAPatch{Name: sp("Suresh K"), NameTe: sp(""), Languages: &[]string{"te", "en", "te"}})
	require.NoError(t, err)
	assert.Equal(t, "Suresh K", up.Name)
	assert.Nil(t, up.NameTe)
	assert.Equal(t, []string{"te", "en"}, up.Languages)
	assert.Equal(t, "mandal", up.Level)
	assert.Equal(t, "FA-KDP-001", up.Code)
	_, err = e.svc.UpdateFA(ctx, ids.New(), FAPatch{Name: sp("x")})
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	// Search and keyset pagination.
	page, err := e.svc.ListFAs(ctx, FAFilter{Q: sp("suresh")}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	assert.Equal(t, a.ID, page.Items[0].ID)
	seen := map[uuid.UUID]bool{}
	var cursor *string
	two := 2
	for range 5 {
		page, err = e.svc.ListFAs(ctx, FAFilter{}, &two, cursor)
		require.NoError(t, err)
		for _, f := range page.Items {
			assert.False(t, seen[f.ID])
			seen[f.ID] = true
		}
		if cursor = page.NextCursor; cursor == nil {
			break
		}
	}
	assert.Len(t, seen, 5)
	assert.Equal(t, 5, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.fa_created'`))
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.fa_updated' AND before IS NOT NULL AND after IS NOT NULL`))

	// Provider view.
	got, err := e.svc.GetFieldAssistants(context.Background(), []uuid.UUID{b.ID, a.ID, a.ID, ids.New()})
	require.NoError(t, err)
	require.Len(t, got, 2)
	assert.Equal(t, "FA-KDP-001", got[0].Code)
	assert.Equal(t, "Suresh K", got[0].Name)
}

func TestFADeactivationWipesDevices(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	actx := testutil.Ctx(admin)
	fa, temp, err := e.svc.CreateFA(actx, FACreate{AreaCode: sp("SHB"), Name: "Gopal R", Phone: "9848000001", Level: "village"})
	require.NoError(t, err)
	in, err := e.svc.FALogin(anonCtx(), fa.Code, temp, AppDevice{Key: "gopal-phone", AppVersion: sp("1.0.3")})
	require.NoError(t, err)
	p, _ := testutil.Tokens().Verify(in.Tokens.Access)

	page, err := e.svc.ListFAs(actx, FAFilter{}, nil, nil)
	require.NoError(t, err)
	require.NotNil(t, page.Items[0].AppVersion)
	assert.Equal(t, "1.0.3", *page.Items[0].AppVersion)

	revoked, err := e.svc.IsDeviceRevoked(context.Background(), in.DeviceID)
	require.NoError(t, err)
	assert.False(t, revoked)
	hb, err := e.svc.Heartbeat(testutil.Ctx(p), auth.KindFA, DeviceHeartbeat{PushToken: sp("gopal-push")})
	require.NoError(t, err)
	assert.False(t, hb.Wipe)

	// Leaving still works; inactive revokes everything.
	_, err = e.svc.SetFAStatus(actx, fa.ID, FALeaving)
	require.NoError(t, err)
	_, err = e.svc.Refresh(anonCtx(), in.Tokens.Refresh)
	require.NoError(t, err)
	out, err := e.svc.SetFAStatus(actx, fa.ID, FAInactive)
	require.NoError(t, err)
	assert.Equal(t, FAInactive, out.Status)

	revoked, err = e.svc.IsDeviceRevoked(context.Background(), in.DeviceID)
	require.NoError(t, err)
	assert.True(t, revoked)
	hb, err = e.svc.Heartbeat(testutil.Ctx(p), auth.KindFA, DeviceHeartbeat{})
	require.NoError(t, err)
	assert.True(t, hb.Wipe)
	_, err = e.svc.FALogin(anonCtx(), fa.Code, temp, AppDevice{Key: "new-install"})
	assert.Equal(t, errBadFALogin, err)
	tokens, err := e.svc.PushTokens(context.Background(), SubjectFA, []uuid.UUID{fa.ID})
	require.NoError(t, err)
	assert.Empty(t, tokens, "revoked devices have no push token")
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM river_job WHERE args->>'name' = 'device.revoked' AND args->'payload'->>'device_id' = $1`, in.DeviceID.String()))
	assert.Equal(t, 0, e.count(t, `SELECT count(*) FROM sessions WHERE subject_id = $1 AND revoked_at IS NULL`, fa.ID))
}

func TestDeviceRevokeAndPushTokens(t *testing.T) {
	e := newEnv(t)
	_, ops := e.seedHO(t, "ops@orbit.test", auth.RoleOps, true)
	actx := testutil.Ctx(ops)

	// Two farmers sign in on the same phone (same push token) one after the other.
	first := e.farmerLogin(t, "9000000011", "shared-phone")
	_, err := e.svc.RequestOTP(anonCtx(), "9000000012", "te")
	require.NoError(t, err)
	second, err := e.svc.VerifyOTP(anonCtx(), "9000000012", e.sms.lastCode(t), AppDevice{Key: "shared-phone", PushToken: sp("token-x")})
	require.NoError(t, err)
	p1, _ := testutil.Tokens().Verify(first.Tokens.Access)
	_, err = e.svc.Heartbeat(testutil.Ctx(p1), auth.KindFarmer, DeviceHeartbeat{PushToken: sp("token-x"), AppVersion: sp("2.0.0")})
	require.NoError(t, err)
	tokens, err := e.svc.PushTokens(context.Background(), SubjectFarmer, []uuid.UUID{first.FarmerID, second.FarmerID})
	require.NoError(t, err)
	assert.Equal(t, map[uuid.UUID][]string{first.FarmerID: {"token-x"}}, tokens, "a push token belongs to the latest subject only")

	// Revoke the first farmer's device.
	d, err := e.svc.RevokeDevice(actx, first.DeviceID, "Phone lost")
	require.NoError(t, err)
	require.NotNil(t, d.RevokedAt)
	assert.False(t, d.HasPushToken)
	_, err = e.svc.RevokeDevice(actx, first.DeviceID, "again")
	require.NoError(t, err, "revoking twice is a no-op")
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.device_revoked' AND farmer_id = $1`, first.FarmerID))
	_, err = e.svc.RevokeDevice(actx, ids.New(), "x")
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	_, err = e.svc.Refresh(anonCtx(), first.Tokens.Refresh)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))
	hb, err := e.svc.Heartbeat(testutil.Ctx(p1), auth.KindFarmer, DeviceHeartbeat{})
	require.NoError(t, err)
	assert.True(t, hb.Wipe)

	// Signing in again on the revoked install is refused, and the code stays usable.
	e.clock.Advance(31 * time.Second)
	_, err = e.svc.RequestOTP(anonCtx(), "9000000011", "te")
	require.NoError(t, err)
	code := e.sms.lastCode(t)
	_, err = e.svc.VerifyOTP(anonCtx(), "9000000011", code, AppDevice{Key: "shared-phone"})
	assert.Equal(t, "device_revoked", appCode(err))
	again, err := e.svc.VerifyOTP(anonCtx(), "9000000011", code, AppDevice{Key: "fresh-install"})
	require.NoError(t, err)
	assert.NotEqual(t, first.DeviceID, again.DeviceID)

	page, err := e.svc.ListDevices(actx, SubjectFarmer, first.FarmerID, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 2)
	assert.Equal(t, again.DeviceID, page.Items[0].ID, "newest first")
	assert.NotNil(t, page.Items[1].RevokedAt)
}

func TestMarkSynced(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	fa, temp, err := e.svc.CreateFA(testutil.Ctx(admin), FACreate{AreaCode: sp("KDP"), Name: "S", Phone: "9848000002", Level: "village"})
	require.NoError(t, err)
	in, err := e.svc.FALogin(anonCtx(), fa.Code, temp, AppDevice{Key: "fa-sync-phone"})
	require.NoError(t, err)

	at := time.Date(2026, 10, 30, 10, 42, 0, 0, time.UTC)
	require.NoError(t, e.svc.MarkSynced(context.Background(), fa.ID, in.DeviceID, at))
	got, err := e.svc.GetFA(testutil.Ctx(admin), fa.ID)
	require.NoError(t, err)
	require.NotNil(t, got.LastSyncAt)
	assert.True(t, at.Equal(*got.LastSyncAt))
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM devices WHERE id = $1 AND last_sync_at = $2`, in.DeviceID, at))
	assert.True(t, apperr.Is(e.svc.MarkSynced(context.Background(), ids.New(), uuid.Nil, at), apperr.KindNotFound))
}

func TestHOUserAdminRules(t *testing.T) {
	e := newEnv(t)
	adminRow, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, true)
	actx := testutil.Ctx(admin)

	_, _, err := e.svc.CreateHOAccount(actx, NewHOAccount{Email: "ADMIN@orbit.test", Name: "Dup", Role: "ops"})
	assert.Equal(t, "email_taken", appCode(err))
	_, _, err = e.svc.CreateHOAccount(actx, NewHOAccount{Email: "not an email", Name: "X", Role: "ops"})
	assert.True(t, apperr.Is(err, apperr.KindValidation))

	// Nobody changes their own role or area; the last admin stays an admin.
	_, err = e.svc.UpdateHOAccount(actx, adminRow.ID, HOAccountPatch{Role: sp("ops")})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	_, err = e.svc.UpdateHOAccount(actx, adminRow.ID, HOAccountPatch{DistrictIDs: &[]uuid.UUID{district1}})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	renamed, err := e.svc.UpdateHOAccount(actx, adminRow.ID, HOAccountPatch{Name: sp("Head Admin")})
	require.NoError(t, err, "own name is fine")
	assert.Equal(t, "Head Admin", renamed.Name)

	// A second admin demotes the first; now the second is the last admin.
	invited, _, err := e.svc.CreateHOAccount(actx, NewHOAccount{Email: "invited@orbit.test", Name: "Invited", Role: "admin"})
	require.NoError(t, err)
	invitedCtx := testutil.Ctx(auth.Principal{Kind: auth.KindHO, ID: invited.ID, Role: auth.RoleAdmin})
	_, err = e.svc.UpdateHOAccount(invitedCtx, adminRow.ID, HOAccountPatch{Role: sp("ops")})
	assert.Equal(t, "last_admin", appCode(err), "an invited admin who never signed in does not count")
	second, secondP := e.seedHO(t, "second@orbit.test", auth.RoleAdmin, true)
	secondCtx := testutil.Ctx(secondP)
	_, err = e.svc.UpdateHOAccount(secondCtx, adminRow.ID, HOAccountPatch{Role: sp("ops")})
	require.NoError(t, err, "another admin remains")
	_, err = e.svc.SetHOAccountStatus(secondCtx, invited.ID, HODisabled)
	require.NoError(t, err)
	// The first user's token still says admin until it refreshes, but the
	// last active admin cannot be demoted or disabled.
	_, err = e.svc.SetHOAccountStatus(actx, second.ID, HODisabled)
	assert.Equal(t, "last_admin", appCode(err))
	_, err = e.svc.UpdateHOAccount(actx, second.ID, HOAccountPatch{Role: sp("finance")})
	assert.Equal(t, "last_admin", appCode(err))
	assert.Equal(t, 1, e.count(t, `SELECT count(*) FROM audit_log WHERE action = 'identity.ho_user_updated' AND (after->>'role') = 'ops'`))

	// Resets: TOTP must be set up again; a temporary password must be changed.
	require.NoError(t, e.svc.ResetHOTOTP(actx, second.ID))
	temp, err := e.svc.ResetHOPassword(actx, second.ID)
	require.NoError(t, err)
	_, err = e.svc.HOLogin(anonCtx(), "second@orbit.test", temp, nil)
	assert.Equal(t, "totp_enrolment_required", appCode(err))
	got, err := e.svc.GetHOAccount(secondCtx, second.ID)
	require.NoError(t, err)
	assert.True(t, got.MustChangePassword)
	assert.False(t, got.TOTPEnabled)

	// Reactivating a user who never signed in puts them back to invited.
	third, _, err := e.svc.CreateHOAccount(secondCtx, NewHOAccount{Email: "third@orbit.test", Name: "Third", Role: "agronomy"})
	require.NoError(t, err)
	off, err := e.svc.SetHOAccountStatus(secondCtx, third.ID, HODisabled)
	require.NoError(t, err)
	assert.Equal(t, HODisabled, off.Status)
	on, err := e.svc.SetHOAccountStatus(secondCtx, third.ID, HOActive)
	require.NoError(t, err)
	assert.Equal(t, HOInvited, on.Status)

	page, err := e.svc.ListHOAccounts(secondCtx, HOFilter{Role: sp("agronomy")}, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	assert.Equal(t, third.ID, page.Items[0].ID)
}

func TestHOChangePassword(t *testing.T) {
	e := newEnv(t)
	row, p := e.seedHO(t, "ops@orbit.test", auth.RoleOps, true)
	ctx := testutil.Ctx(p)
	assert.True(t, apperr.Is(e.svc.ChangeHOPassword(ctx, "Start-1234", "ops-pass-99"), apperr.KindValidation), "contains the email name")
	require.NoError(t, e.svc.ChangeHOPassword(ctx, "Start-1234", "Kondapur-2026"))
	code, _ := auth.TOTPCode(*row.TotpSecret, e.clock.Now())
	in, err := e.svc.HOLogin(anonCtx(), "ops@orbit.test", "Kondapur-2026", &code)
	require.NoError(t, err)
	assert.False(t, in.User.MustChangePassword)
	me, err := e.svc.Me(ctx)
	require.NoError(t, err)
	assert.Equal(t, "ops", me.Role)
}
