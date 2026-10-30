package db

import (
	"context"
	"database/sql"
	"fmt"
	"io"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivermigrate"

	"github.com/sapionic/orbit/backend/migrations"
)

func gooseProvider(pool *pgxpool.Pool) (*goose.Provider, *sql.DB, error) {
	sqlDB := stdlib.OpenDBFromPool(pool)
	// Allow out-of-order versions: modules reserve migration numbers (CONVENTIONS
	// section 13), so a lower number can land after a higher one in dev.
	p, err := goose.NewProvider(goose.DialectPostgres, sqlDB, migrations.FS, goose.WithAllowOutofOrder(true))
	if err != nil {
		_ = sqlDB.Close()
		return nil, nil, fmt.Errorf("goose: %w", err)
	}
	return p, sqlDB, nil
}

// MigrateUp applies all pending goose migrations (embedded SQL), then River's
// own migrations. Safe to run repeatedly. Log lines go to w (may be io.Discard).
func MigrateUp(ctx context.Context, pool *pgxpool.Pool, w io.Writer) error {
	p, sqlDB, err := gooseProvider(pool)
	if err != nil {
		return err
	}
	defer sqlDB.Close()
	res, err := p.Up(ctx)
	if err != nil {
		return fmt.Errorf("goose up: %w", err)
	}
	for _, r := range res {
		fmt.Fprintf(w, "goose: applied %s (%s)\n", r.Source.Path, r.Duration)
	}

	m, err := rivermigrate.New(riverpgxv5.New(pool), nil)
	if err != nil {
		return fmt.Errorf("rivermigrate: %w", err)
	}
	rr, err := m.Migrate(ctx, rivermigrate.DirectionUp, nil)
	if err != nil {
		return fmt.Errorf("river migrate up: %w", err)
	}
	for _, v := range rr.Versions {
		fmt.Fprintf(w, "river: applied version %d (%s)\n", v.Version, v.Name)
	}
	return nil
}

// MigrateDown rolls back the most recent goose migration. River's tables are
// left alone (they are only removed by dropping the database).
func MigrateDown(ctx context.Context, pool *pgxpool.Pool, w io.Writer) error {
	p, sqlDB, err := gooseProvider(pool)
	if err != nil {
		return err
	}
	defer sqlDB.Close()
	r, err := p.Down(ctx)
	if err != nil {
		return fmt.Errorf("goose down: %w", err)
	}
	if r != nil {
		fmt.Fprintf(w, "goose: rolled back %s\n", r.Source.Path)
	}
	return nil
}

// MigrationStatus prints goose and River migration state to w.
func MigrationStatus(ctx context.Context, pool *pgxpool.Pool, w io.Writer) error {
	p, sqlDB, err := gooseProvider(pool)
	if err != nil {
		return err
	}
	defer sqlDB.Close()
	st, err := p.Status(ctx)
	if err != nil {
		return fmt.Errorf("goose status: %w", err)
	}
	for _, s := range st {
		applied := "pending"
		if s.State == goose.StateApplied {
			applied = "applied " + s.AppliedAt.Format("2006-01-02 15:04:05")
		}
		fmt.Fprintf(w, "goose  %-28s %s\n", s.Source.Path, applied)
	}
	m, err := rivermigrate.New(riverpgxv5.New(pool), nil)
	if err != nil {
		return fmt.Errorf("rivermigrate: %w", err)
	}
	existing, err := m.ExistingVersions(ctx)
	if err != nil {
		fmt.Fprintf(w, "river  not migrated (%v)\n", err)
		return nil
	}
	applied := map[int]bool{}
	for _, v := range existing {
		applied[v.Version] = true
	}
	for _, v := range m.AllVersions() {
		state := "pending"
		if applied[v.Version] {
			state = "applied"
		}
		fmt.Fprintf(w, "river  %03d %-22s %s\n", v.Version, v.Name, state)
	}
	return nil
}
