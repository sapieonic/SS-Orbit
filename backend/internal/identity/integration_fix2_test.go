package identity

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// GET /v1/auth/app-config needs no token, is cacheable and reflects config.
func TestAppConfigHTTP(t *testing.T) {
	tokens := testutil.Tokens()
	cfg := config.ForTest()
	cfg.AppMinVersionFA, cfg.AppLatestVersionFA = "1.4.0", "1.6.0"
	cfg.AppStoreURLFA = "https://play.google.com/store/apps/details?id=in.orbit.fa"
	cfg.AppFlagsFA = map[string]bool{"voice_notes": true}
	m := New(platform.Deps{Config: cfg, Clock: clock.System(), Tokens: tokens}, &Ports{})
	router := testutil.Router(tokens, m.Mount)

	rec := do(t, router, http.MethodGet, "/v1/auth/app-config?app=fa", "", nil)
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	assert.Equal(t, "public, max-age=300", rec.Header().Get("Cache-Control"))
	assert.JSONEq(t, `{"app":"fa","min_version":"1.4.0","latest_version":"1.6.0",
		"store_url":"https://play.google.com/store/apps/details?id=in.orbit.fa","flags":{"voice_notes":true}}`, rec.Body.String())

	rec = do(t, router, http.MethodGet, "/v1/auth/app-config?app=farmer", "", nil)
	require.Equal(t, http.StatusOK, rec.Code)
	assert.JSONEq(t, `{"app":"farmer","min_version":"0.0.0","latest_version":"0.0.0","store_url":null,"flags":{}}`, rec.Body.String())

	assert.Equal(t, http.StatusBadRequest, do(t, router, http.MethodGet, "/v1/auth/app-config?app=ho", "", nil).Code)
	assert.Equal(t, http.StatusBadRequest, do(t, router, http.MethodGet, "/v1/auth/app-config", "", nil).Code)
}

// Heartbeats tell an app below the configured min version to update.
func TestHeartbeatReturnsMinVersion(t *testing.T) {
	e := newEnv(t)
	e.svc.deps.Config.AppMinVersionFarmer = "2.1.0"
	in := e.farmerLogin(t, "9000000031", "phone-31")
	p, err := testutil.Tokens().Verify(in.Tokens.Access)
	require.NoError(t, err)
	ctx := testutil.Ctx(p)

	hb, err := e.svc.Heartbeat(ctx, auth.KindFarmer, DeviceHeartbeat{AppVersion: sp("2.0.9")})
	require.NoError(t, err)
	assert.Equal(t, "2.1.0", hb.MinVersion)
	assert.True(t, hb.UpdateRequired)

	hb, err = e.svc.Heartbeat(ctx, auth.KindFarmer, DeviceHeartbeat{AppVersion: sp("2.10.0")})
	require.NoError(t, err)
	assert.False(t, hb.UpdateRequired, "2.10 is newer than 2.1")

	hb, err = e.svc.Heartbeat(ctx, auth.KindFarmer, DeviceHeartbeat{})
	require.NoError(t, err)
	assert.Equal(t, "2.1.0", hb.MinVersion)
	assert.False(t, hb.UpdateRequired, "unknown app version is not forced")
}

// Every HO role can resolve user IDs to names; emails stay admin-only.
func TestHODirectory(t *testing.T) {
	e := newEnv(t)
	admin, _ := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, false)
	_, agro := e.seedHO(t, "agro@orbit.test", auth.RoleAgronomy, false)
	_, fin := e.seedHO(t, "fin@orbit.test", auth.RoleFinance, false)

	for _, p := range []auth.Principal{agro, fin} {
		list, err := e.svc.HODirectory(testutil.Ctx(p))
		require.NoError(t, err)
		require.Len(t, list, 3)
		names := []string{list[0].Name, list[1].Name, list[2].Name}
		assert.IsIncreasing(t, names, "sorted by name")
		var found bool
		for _, u := range list {
			if u.ID == admin.ID {
				found = true
				assert.Equal(t, HODirectoryEntry{ID: admin.ID, Name: admin.Name, Role: "admin", Status: HOActive}, u)
			}
		}
		assert.True(t, found)
	}
	_, err := e.svc.HODirectory(testutil.Ctx(testutil.FA()))
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
}

// not_synced_since keeps FAs who synced before the time or never synced.
func TestListFAsNotSyncedSince(t *testing.T) {
	e := newEnv(t)
	_, admin := e.seedHO(t, "admin@orbit.test", auth.RoleAdmin, false)
	actx := testutil.Ctx(admin)
	mk := func(name, phone string) FA {
		fa, _, err := e.svc.CreateFA(actx, FACreate{AreaCode: sp("SHB"), Name: name, Phone: phone, Level: "village"})
		require.NoError(t, err)
		return fa
	}
	recent, stale, never := mk("Recent", "9848000041"), mk("Stale", "9848000042"), mk("Never", "9848000043")
	now := time.Now()
	require.NoError(t, e.svc.MarkSynced(context.Background(), recent.ID, uuid.Nil, now.Add(-time.Hour)))
	require.NoError(t, e.svc.MarkSynced(context.Background(), stale.ID, uuid.Nil, now.Add(-30*time.Hour)))

	since := now.Add(-24 * time.Hour)
	page, err := e.svc.ListFAs(actx, FAFilter{NotSyncedSince: &since}, nil, nil)
	require.NoError(t, err)
	var got []string
	for _, fa := range page.Items {
		got = append(got, fa.ID.String())
	}
	assert.ElementsMatch(t, []string{stale.ID.String(), never.ID.String()}, got)

	all, err := e.svc.ListFAs(actx, FAFilter{}, nil, nil)
	require.NoError(t, err)
	assert.Len(t, all.Items, 3)
}
