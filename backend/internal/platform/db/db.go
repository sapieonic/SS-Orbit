// Package db owns the Postgres connection pool, transactions and migrations.
//
// Services run writes inside db.WithTx and pass the pgx.Tx to sqlc
// (store.New(tx)), audit.Record, events Publish, jobs Insert and
// territory.Bump so everything commits or rolls back together.
package db

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// DBTX is satisfied by *pgxpool.Pool, *pgxpool.Conn, *pgx.Conn and pgx.Tx.
// It matches the interface sqlc generates, so store.New accepts any of them.
type DBTX interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// Beginner starts a transaction. *pgxpool.Pool satisfies it, and so does
// pgx.Tx (which starts a savepoint), so WithTx nests safely.
type Beginner interface {
	Begin(ctx context.Context) (pgx.Tx, error)
}

// Open creates a pool for url and verifies connectivity. maxConns <= 0 keeps
// the pgx default.
func Open(ctx context.Context, url string, maxConns int32) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, fmt.Errorf("db: parse url: %w", err)
	}
	if maxConns > 0 {
		cfg.MaxConns = maxConns
	}
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("db: connect: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("db: ping: %w", err)
	}
	return pool, nil
}

// WithTx runs fn in a transaction: commit if fn returns nil, rollback
// otherwise (and on panic, which is re-raised). The error from fn is returned
// unchanged so apperr types survive.
func WithTx(ctx context.Context, b Beginner, fn func(tx pgx.Tx) error) (err error) {
	tx, err := b.Begin(ctx)
	if err != nil {
		return fmt.Errorf("db: begin: %w", err)
	}
	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback(context.WithoutCancel(ctx))
			panic(p)
		}
		if err != nil {
			_ = tx.Rollback(context.WithoutCancel(ctx))
		}
	}()
	if err = fn(tx); err != nil {
		return err
	}
	if err = tx.Commit(ctx); err != nil {
		return fmt.Errorf("db: commit: %w", err)
	}
	return nil
}

// IsNoRows reports whether err is pgx.ErrNoRows (sqlc :one with no match).
func IsNoRows(err error) bool { return errors.Is(err, pgx.ErrNoRows) }

// Postgres error codes callers commonly branch on.
const (
	CodeUniqueViolation     = "23505"
	CodeForeignKeyViolation = "23503"
	CodeCheckViolation      = "23514"
	CodeSerialization       = "40001"
)

// PgErrorCode returns the SQLSTATE of err, or "".
func PgErrorCode(err error) string {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code
	}
	return ""
}

// IsUniqueViolation reports a unique violation; if constraint is non-empty it
// must also match the violated constraint/index name.
func IsUniqueViolation(err error, constraint string) bool {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) || pgErr.Code != CodeUniqueViolation {
		return false
	}
	return constraint == "" || pgErr.ConstraintName == constraint
}

// IsForeignKeyViolation reports a foreign-key violation.
func IsForeignKeyViolation(err error) bool { return PgErrorCode(err) == CodeForeignKeyViolation }
