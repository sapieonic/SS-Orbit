// Command worker runs River jobs: every module's workers plus the domain event
// dispatcher and subscribers. Graceful shutdown on SIGINT/SIGTERM lets
// running jobs finish (bounded by SHUTDOWN_TIMEOUT). It also serves /healthz
// and /readyz on WORKER_HEALTH_ADDR (default :8081) for container health checks.
//
//	go run ./cmd/worker          # run
//	go run ./cmd/worker -ping    # also publish a system.ping event (smoke test)
//	worker -healthcheck          # probe a running worker's /readyz and exit 0/1
//	                             # (the ECS container check: the distroless image has no curl)
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/sapionic/orbit/backend/internal/app"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "worker:", err)
		os.Exit(1)
	}
}

func run() error {
	ping := flag.Bool("ping", false, "publish a system.ping event after start (smoke test)")
	healthcheck := flag.Bool("healthcheck", false, "probe the running worker's /readyz on WORKER_HEALTH_ADDR and exit")
	flag.Parse()
	if *healthcheck {
		return probe(os.Getenv("WORKER_HEALTH_ADDR"))
	}

	cfg, err := config.Load()
	if err != nil {
		return err
	}
	log := logx.New(cfg.LogLevel, cfg.LogFormat)
	slog.SetDefault(log)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	deps, cleanup, err := app.BuildDeps(ctx, cfg, log)
	if err != nil {
		return err
	}
	defer cleanup()
	mods := app.Build(deps)

	client, err := app.NewWorker(deps, mods, events.NewBus())
	if err != nil {
		return err
	}
	if err := client.Start(ctx); err != nil {
		return fmt.Errorf("start river: %w", err)
	}
	log.Info("worker started", "concurrency", cfg.WorkerConcurrency)

	var health *http.Server
	healthErr := make(chan error, 1)
	if cfg.WorkerHealthAddr != "" {
		health = newHealthServer(cfg.WorkerHealthAddr, deps.Pool)
		go func() {
			log.Info("worker health listening", "addr", cfg.WorkerHealthAddr)
			if err := health.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
				healthErr <- err
			}
		}()
	}

	if *ping {
		if err := app.PublishPing(ctx, deps, "hello from cmd/worker -ping"); err != nil {
			return fmt.Errorf("ping: %w", err)
		}
		log.Info("published system.ping")
	}

	var runErr error
	select {
	case <-ctx.Done():
	case err := <-healthErr:
		// Without health checks the orchestrator would kill the task anyway;
		// stop the jobs cleanly and exit non-zero.
		runErr = fmt.Errorf("health server: %w", err)
	}
	log.Info("worker shutting down")
	sctx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if health != nil {
		// Stop answering health checks first; the task is going away.
		_ = health.Shutdown(sctx)
	}
	if err := client.Stop(sctx); err != nil {
		return fmt.Errorf("stop river: %w", err)
	}
	log.Info("worker stopped")
	return runErr
}
