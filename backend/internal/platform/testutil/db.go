// Package testutil provides helpers for integration and HTTP tests.
//
// NewDB connects to TEST_DATABASE_URL (database orbit_test from
// dev/docker-compose.yml), applies goose + River migrations once per process,
// and truncates every table before each test. Tests are skipped when
// TEST_DATABASE_URL is unset.
//
// Isolation: test binaries for different packages run in parallel processes
// against the same database, so NewDB serialises DB tests across processes
// with a Postgres advisory lock held for the whole test (and across tests in
// one process with a mutex). Non-DB tests are unaffected. Do not call
// t.Parallel() in DB tests; it gains nothing.
package testutil

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/sapionic/orbit/backend/internal/platform/db"
)

// advisoryKey is an arbitrary constant identifying the orbit test lock.
const advisoryKey = 7_340_517_001

// keepTables are never truncated: migration bookkeeping and PostGIS metadata.
var keepTables = map[string]bool{
	"goose_db_version": true,
	"river_migration":  true,
	"spatial_ref_sys":  true,
}

// reseedSQL restores rows that migrations insert (TRUNCATE removes them).
// If a migration seeds rows, add them here.
const reseedSQL = `INSERT INTO master_versions (kind, version) VALUES ('all', 1) ON CONFLICT DO NOTHING`

var (
	setupOnce sync.Once
	setupErr  error
	pool      *pgxpool.Pool
	lockConn  *pgx.Conn
	tables    []string

	mu       sync.Mutex // held for the duration of a DB test
	holderMu sync.Mutex // guards holder
	holder   testing.TB
)

func currentHolder() testing.TB {
	holderMu.Lock()
	defer holderMu.Unlock()
	return holder
}

func setHolder(t testing.TB) {
	holderMu.Lock()
	defer holderMu.Unlock()
	holder = t
}

// NewDB returns a pool on a freshly truncated, fully migrated test database.
// Skips the test if TEST_DATABASE_URL is unset. Do not Close the pool.
func NewDB(t testing.TB) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	setupOnce.Do(func() { setupErr = setup(url) })
	if setupErr != nil {
		t.Fatalf("testutil: %v", setupErr)
	}

	// A subtest of the test holding the DB shares it.
	if h := currentHolder(); h != nil && (h == t || strings.HasPrefix(t.Name(), h.Name()+"/")) {
		return pool
	}

	mu.Lock()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	if _, err := lockConn.Exec(ctx, `SELECT pg_advisory_lock($1)`, advisoryKey); err != nil {
		mu.Unlock()
		t.Fatalf("testutil: advisory lock: %v", err)
	}
	setHolder(t)
	t.Cleanup(func() {
		setHolder(nil)
		_, _ = lockConn.Exec(context.Background(), `SELECT pg_advisory_unlock($1)`, advisoryKey)
		mu.Unlock()
	})
	if err := truncate(ctx); err != nil {
		t.Fatalf("testutil: truncate: %v", err)
	}
	return pool
}

func setup(url string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	var err error
	pool, err = db.Open(ctx, url, 10)
	if err != nil {
		return err
	}
	lockConn, err = pgx.Connect(ctx, url)
	if err != nil {
		return fmt.Errorf("lock connection: %w", err)
	}
	// Migrate under the lock so parallel test processes don't race goose.
	if _, err := lockConn.Exec(ctx, `SELECT pg_advisory_lock($1)`, advisoryKey); err != nil {
		return err
	}
	defer lockConn.Exec(context.Background(), `SELECT pg_advisory_unlock($1)`, advisoryKey) //nolint:errcheck
	if err := db.MigrateUp(ctx, pool, io.Discard); err != nil {
		return fmt.Errorf("migrate: %w", err)
	}
	rows, err := pool.Query(ctx, `SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename`)
	if err != nil {
		return err
	}
	names, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		return err
	}
	for _, n := range names {
		if !keepTables[n] {
			tables = append(tables, pgx.Identifier{n}.Sanitize())
		}
	}
	return nil
}

// truncate empties every application and River table. TRUNCATE bypasses the
// append-only row triggers on audit_log and consents.
func truncate(ctx context.Context) error {
	if len(tables) == 0 {
		return nil
	}
	if _, err := pool.Exec(ctx, `TRUNCATE `+strings.Join(tables, ", ")+` RESTART IDENTITY CASCADE`); err != nil {
		return err
	}
	_, err := pool.Exec(ctx, reseedSQL)
	return err
}
