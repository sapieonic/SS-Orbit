// Package app assembles the processes: it builds platform.Deps from config,
// constructs every module (wire.go), and produces the HTTP router (api) and
// the River worker client (worker). cmd/api and cmd/worker are thin mains
// around it, so both processes share exactly the same wiring.
package app

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/identity"
	"github.com/sapionic/orbit/backend/internal/messaging"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/cache"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/httpx"
	"github.com/sapionic/orbit/backend/internal/platform/jobs"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/push"
	"github.com/sapionic/orbit/backend/internal/platform/ratelimit"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/platform/storage"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/sync"
	"github.com/sapionic/orbit/backend/internal/visits"
)

// BuildDeps connects to Postgres and Redis and builds every platform service.
// The returned cleanup closes connections.
func BuildDeps(ctx context.Context, cfg config.Config, log *slog.Logger) (platform.Deps, func(), error) {
	pool, err := db.Open(ctx, cfg.DatabaseURL, cfg.DatabaseMaxConn)
	if err != nil {
		return platform.Deps{}, nil, err
	}
	rdb, err := cache.Open(cfg.RedisURL)
	if err != nil {
		pool.Close()
		return platform.Deps{}, nil, err
	}
	cleanup := func() {
		if rdb != nil {
			_ = rdb.Close()
		}
		pool.Close()
	}
	fail := func(err error) (platform.Deps, func(), error) {
		cleanup()
		return platform.Deps{}, nil, err
	}
	clk := clock.System()

	j, err := jobs.NewInsertOnly(pool, log)
	if err != nil {
		return fail(err)
	}
	// Only dev adapters exist so far; config.Validate refuses them in prod.
	var st storage.Storage
	switch cfg.StorageProvider {
	case "local":
		if st, err = storage.NewLocal(cfg.StorageDir, cfg.PublicBaseURL, []byte(cfg.StorageSigningKey), clk); err != nil {
			return fail(err)
		}
	default:
		return fail(fmt.Errorf("unknown STORAGE_PROVIDER %q", cfg.StorageProvider))
	}
	var smsSender sms.Sender
	switch {
	case cfg.SMSProvider == "log" && cfg.IsDev():
		smsSender = sms.NewDevLog(log)
	case cfg.SMSProvider == "log":
		smsSender = sms.NewLog(log) // bodies redacted
	default:
		return fail(fmt.Errorf("unknown SMS_PROVIDER %q", cfg.SMSProvider))
	}
	var pushSender push.Sender
	switch {
	case cfg.PushProvider == "log" && cfg.IsDev():
		pushSender = push.NewDevLog(log)
	case cfg.PushProvider == "log":
		pushSender = push.NewLog(log) // bodies redacted
	default:
		return fail(fmt.Errorf("unknown PUSH_PROVIDER %q", cfg.PushProvider))
	}

	return platform.Deps{
		Config:    cfg,
		Pool:      pool,
		Cache:     cache.New(rdb, log),
		Limiter:   ratelimit.New(rdb, pool, clk, log),
		Jobs:      j,
		Events:    events.NewPublisher(j, clk),
		Tokens:    auth.NewTokens(cfg.JWTSecret, cfg.JWTIssuer, cfg.AccessTokenTTL, clk),
		Storage:   st,
		SMS:       smsSender,
		Push:      pushSender,
		Clock:     clk,
		Logger:    log,
		Commands:  commands.NewRegistry(),
		Territory: territory.NewRegistry(),
	}, cleanup, nil
}

// Build constructs every module and registers the hooks both processes need
// (sync commands and snapshot providers).
func Build(d platform.Deps) *Modules {
	m := NewModules(d)
	checkHooks(m.all())
	m.RegisterCommands(d.Commands)
	m.RegisterSnapshot(d.Territory)
	d.Logger.Debug("modules wired", "hooks", m.Hooks(), "commands", d.Commands.Types(), "snapshot_sections", d.Territory.Sections())
	return m
}

// NewRouter builds the api's HTTP handler: middleware, health checks, dev file
// serving and every module's routes.
func NewRouter(d platform.Deps, m *Modules) http.Handler {
	r := httpx.NewRouter(httpx.RouterConfig{
		Logger:            d.Logger,
		Tokens:            d.Tokens,
		CORSOrigins:       d.Config.CORSOrigins,
		TrustProxyHeaders: d.Config.TrustProxyHeaders,
		CheckPrincipal:    m.Identity.Service().CheckPrincipal, // device, session and user checks
		MaxBodyBytes:      d.Config.HTTPMaxBodyBytes,
		BodyLimits: map[string]int64{
			"/v1/fa/sync/commands":          d.Config.HTTPLargeBodyBytes,
			"/v1/admin/geo/village-imports": d.Config.HTTPLargeBodyBytes,
		},
	})
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	r.Get("/readyz", readyz(d))
	if local, ok := d.Storage.(*storage.Local); ok && d.Config.IsDev() {
		local.Mount(r)
	}
	m.Mount(r)
	return r
}

// readyz reports dependency health. Postgres down => 503. Redis down =>
// 200 "degraded": the app keeps working (cache misses, rate limits on Postgres).
func readyz(d platform.Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		checks := map[string]string{"postgres": "ok", "redis": "ok"}
		status, code := "ok", http.StatusOK
		if err := d.Pool.Ping(ctx); err != nil {
			checks["postgres"] = "error: " + err.Error()
			status, code = "unavailable", http.StatusServiceUnavailable
		}
		if err := d.Cache.Ping(ctx); err != nil {
			checks["redis"] = "error: " + err.Error()
			if code == http.StatusOK {
				status = "degraded"
			}
		}
		httpx.WriteJSON(w, code, map[string]any{"status": status, "checks": checks})
	}
}

// NewWorker builds the worker process's River client: every module's workers
// and event subscribers on bus, plus the event dispatcher. Subscribe any
// extra handlers on bus before calling. Call Start/Stop on the result.
func NewWorker(d platform.Deps, m *Modules, bus *events.Bus) (*river.Client[pgx.Tx], error) {
	workers := river.NewWorkers()
	m.RegisterWorkers(workers)
	m.RegisterSubscribers(bus)
	registerPlatformSubscribers(bus)
	events.RegisterWorkers(workers, bus, d.Pool, d.Logger)
	return jobs.NewWorker(d.Pool, workers, jobs.WorkerConfig{
		MaxWorkers:   d.Config.WorkerConcurrency,
		PeriodicJobs: periodicJobs(),
	}, d.Logger)
}

func registerPlatformSubscribers(bus *events.Bus) {
	events.Handle(bus, "platform.ping_logger", func(ctx context.Context, e events.SystemPing) error {
		logx.From(ctx).InfoContext(ctx, "system.ping received", "message", e.Message)
		return nil
	})
}

// PublishPing publishes a system.ping event (smoke test for the worker).
func PublishPing(ctx context.Context, d platform.Deps, msg string) error {
	return db.WithTx(ctx, d.Pool, func(tx pgx.Tx) error {
		return d.Events.Publish(ctx, tx, events.SystemPing{Message: msg})
	})
}

// periodicJobs lists every module's scheduled jobs (CONVENTIONS section 13).
func periodicJobs() []*river.PeriodicJob {
	var all []*river.PeriodicJob
	all = append(all, visits.MarkMissedPeriodicJob())
	all = append(all, identity.PeriodicJobs()...)
	all = append(all, messaging.PeriodicJobs()...)
	all = append(all, sync.PeriodicJobs()...)
	return all
}
