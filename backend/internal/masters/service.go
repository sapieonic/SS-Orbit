package masters

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/masters/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// Page sizes for admin lists.
const (
	listDefaultLimit = 50
	listMaxLimit     = 200
)

// versionKind is the master_versions row bumped on every publish.
const versionKind = "all"

// Service holds the masters business rules.
type Service struct {
	deps  platform.Deps
	q     *store.Queries
	ports *Ports
}

// NewService builds the service.
func NewService(deps platform.Deps, q *store.Queries, ports *Ports) *Service {
	if ports == nil {
		ports = &Ports{}
	}
	return &Service{deps: deps, q: q, ports: ports}
}

// Role sets. Every HO role can read masters. Admin and agronomy maintain them;
// ops also maintains dealers (verifying shops is field work). Approving
// advisory rules is agronomy only (see service_rules.go).
var (
	readRoles        = []auth.Role{auth.RoleAdmin, auth.RoleAgronomy, auth.RoleFinance, auth.RoleOps}
	writeRoles       = []auth.Role{auth.RoleAdmin, auth.RoleAgronomy}
	dealerWriteRoles = []auth.Role{auth.RoleAdmin, auth.RoleAgronomy, auth.RoleOps}
)

func requireRead(ctx context.Context) error {
	_, err := auth.RequireRole(ctx, readRoles...)
	return err
}

func requireWrite(ctx context.Context) (auth.Principal, error) {
	return auth.RequireRole(ctx, writeRoles...)
}

// inTx runs fn in one transaction with queries bound to it.
func (s *Service) inTx(ctx context.Context, fn func(tx pgx.Tx, q *store.Queries) error) error {
	return db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		return fn(tx, s.q.WithTx(tx))
	})
}

// readSnapshot runs fn in a read-only REPEATABLE READ transaction, so the
// version it reads matches the rows it reads (no publish lands in between).
func (s *Service) readSnapshot(ctx context.Context, fn func(q *store.Queries) error) error {
	tx, err := s.deps.Pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead, AccessMode: pgx.ReadOnly})
	if err != nil {
		return apperr.Internalf("masters: begin read: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck // read-only; rollback after commit is a no-op
	if err := fn(s.q.WithTx(tx)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// publish bumps the masters version and announces it, inside the caller's
// transaction. Call it for every change the FA app can see (it is part of the
// FA snapshot cache key and the masters cache keys).
func (s *Service) publish(ctx context.Context, tx pgx.Tx, q *store.Queries) (int64, error) {
	v, err := q.BumpMasterVersion(ctx)
	if err != nil {
		return 0, apperr.Internalf("masters: bump version: %w", err)
	}
	if err := s.deps.Events.Publish(ctx, tx, events.MastersPublished{Kind: versionKind, Version: v.Version}); err != nil {
		return 0, apperr.Internalf("masters: publish: %w", err)
	}
	return v.Version, nil
}

// GetVersion returns the version counter for the HO portal.
func (s *Service) GetVersion(ctx context.Context) (Version, error) {
	if err := requireRead(ctx); err != nil {
		return Version{}, err
	}
	v, err := s.q.GetMasterVersion(ctx, versionKind)
	if err != nil {
		if db.IsNoRows(err) {
			return Version{Version: 1}, nil
		}
		return Version{}, apperr.Internalf("masters: version: %w", err)
	}
	return Version{Version: v.Version, UpdatedAt: v.UpdatedAt.UTC()}, nil
}

// CurrentVersion is the provider method for sync (CONVENTIONS section 5): the
// 'all' counter, read from Postgres every time so a publish is visible at once.
func (s *Service) CurrentVersion(ctx context.Context) (int64, error) {
	return currentVersion(ctx, s.q)
}

func currentVersion(ctx context.Context, q *store.Queries) (int64, error) {
	v, err := q.GetMasterVersion(ctx, versionKind)
	if err != nil {
		if db.IsNoRows(err) {
			return 1, nil
		}
		return 0, apperr.Internalf("masters: version: %w", err)
	}
	return v.Version, nil
}

// ---- small helpers shared by the service files ----

// pageArgs decodes the cursor and clamps the limit.
func pageArgs(limit *int, cursor *string) (paging.Cursor, int, error) {
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Cursor{}, 0, err
	}
	return cur, paging.Limit(limit, listDefaultLimit, listMaxLimit), nil
}

// text trims s and reports a validation error for field when it is blank.
func text(field, s string, errs map[string]string) string {
	t := strings.TrimSpace(s)
	if t == "" {
		errs[field] = "must not be blank"
	}
	return t
}

// optText trims an optional value; a blank value is an error (optional text
// fields cannot be cleared by sending "").
func optText(field string, s *string, errs map[string]string) *string {
	if s == nil {
		return nil
	}
	t := text(field, *s, errs)
	return &t
}

func validationErr(errs map[string]string) error {
	if len(errs) == 0 {
		return nil
	}
	return apperr.ValidationFields(errs)
}

func nullUUID(id *uuid.UUID) uuid.NullUUID {
	if id == nil {
		return uuid.NullUUID{}
	}
	return uuid.NullUUID{UUID: *id, Valid: true}
}

func uuidPtr(n uuid.NullUUID) *uuid.UUID {
	if !n.Valid {
		return nil
	}
	return &n.UUID
}

func utcPtr(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	u := t.UTC()
	return &u
}

// duplicate maps a unique violation to 409 duplicate naming the field.
func duplicate(err error, field string) error {
	if db.IsUniqueViolation(err, "") {
		return apperr.Conflict("duplicate", map[string]any{"field": field}).
			WithMessage("another record already has this " + field)
	}
	return nil
}
