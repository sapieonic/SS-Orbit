package app_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/app"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
)

// TestWorkerProcessesPublishedEvent runs the real worker wiring end to end:
// publish in a transaction -> domain_event job -> fan-out -> delivery to a
// subscriber.
func TestWorkerProcessesPublishedEvent(t *testing.T) {
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	mods := app.Build(deps)

	got := make(chan events.SystemPing, 1)
	var meta events.Meta
	bus := events.NewBus()
	events.Handle(bus, "test.ping_probe", func(ctx context.Context, e events.SystemPing) error {
		meta, _ = events.MetaFrom(ctx)
		got <- e
		return nil
	})
	client, err := app.NewWorker(deps, mods, bus)
	require.NoError(t, err)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	require.NoError(t, client.Start(ctx))
	t.Cleanup(func() {
		sctx, c := context.WithTimeout(context.Background(), 10*time.Second)
		defer c()
		_ = client.Stop(sctx)
	})

	require.NoError(t, app.PublishPing(testutil.Ctx(testutil.FA()), deps, "hello"))
	select {
	case e := <-got:
		assert.Equal(t, "hello", e.Message)
		assert.Equal(t, events.NameSystemPing, meta.Name)
		assert.Equal(t, "test.ping_probe", meta.Subscriber)
	case <-ctx.Done():
		t.Fatal("event was not delivered within 30s")
	}
}

// TestRouterWiring checks the real router: health, auth guard on admin routes
// and a 200 for an HO token on the audit endpoint.
func TestRouterWiring(t *testing.T) {
	pool := testutil.NewDB(t)
	deps := testutil.NewDeps(t, pool)
	h := app.NewRouter(deps, app.Build(deps))

	do := func(path, token string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec
	}
	assert.Equal(t, 200, do("/healthz", "").Code)
	rz := do("/readyz", "")
	assert.Equal(t, 200, rz.Code)
	assert.Contains(t, rz.Body.String(), `"degraded"`, "no Redis in tests")
	assert.Equal(t, 401, do("/v1/admin/audit", "").Code)
	assert.Equal(t, 200, do("/v1/admin/audit", testutil.Token(t, deps.Tokens, testutil.HO(auth.RoleAdmin))).Code)
	assert.Equal(t, 404, do("/v1/nothing", "").Code)
}
