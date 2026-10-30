// Command migrate applies the embedded goose migrations (backend/migrations)
// and River's own migrations.
//
//	go run ./cmd/migrate up       # goose up, then River up
//	go run ./cmd/migrate down     # roll back the latest goose migration
//	go run ./cmd/migrate status   # goose + River state
//
// DATABASE_URL selects the database (TEST_DATABASE_URL is not used here). It
// is the only setting read, so migrate runs as a one-off task (ECS, CI) without
// the API's secrets or provider settings.
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"

	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/db"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "migrate:", err)
		os.Exit(1)
	}
}

func run() error {
	if len(os.Args) != 2 {
		return fmt.Errorf("usage: migrate up|down|status")
	}
	cfg, err := config.LoadDatabase()
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	pool, err := db.Open(ctx, cfg.DatabaseURL, 2)
	if err != nil {
		return err
	}
	defer pool.Close()

	switch os.Args[1] {
	case "up":
		if err := db.MigrateUp(ctx, pool, os.Stdout); err != nil {
			return err
		}
		fmt.Println("migrations up to date")
		return nil
	case "down":
		return db.MigrateDown(ctx, pool, os.Stdout)
	case "status":
		return db.MigrationStatus(ctx, pool, os.Stdout)
	default:
		return fmt.Errorf("unknown command %q (want up|down|status)", os.Args[1])
	}
}
