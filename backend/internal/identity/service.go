package identity

import (
	"context"
	"net/netip"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/reqctx"
)

// Page sizes for admin lists.
const (
	listDefaultLimit = 50
	listMaxLimit     = 200
)

// tempPasswordTTL is how long a temporary password (new login or admin
// reset) works. After that the user cannot sign in and an admin resets again.
const tempPasswordTTL = 72 * time.Hour

// Service holds the identity rules: sign-in for the three kinds of user,
// sessions with refresh rotation, the device registry, and HO management of
// FA logins and HO users. Reads outside a transaction use q (the pool); writes
// run in db.WithTx with store.New(tx).
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

func (s *Service) now() time.Time { return s.deps.Clock.Now().UTC() }

// withTx runs fn in a transaction with a store bound to it.
func (s *Service) withTx(ctx context.Context, fn func(tx pgx.Tx, q *store.Queries) error) error {
	return db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error { return fn(tx, store.New(tx)) })
}

// allow consumes one unit of a rate limit. Fails closed when neither Redis nor
// Postgres can count (CONVENTIONS section 3).
func (s *Service) allow(ctx context.Context, key string, limit int, window time.Duration) error {
	ok, err := s.deps.Limiter.Allow(ctx, key, limit, window)
	if err != nil {
		return apperr.Unavailable("please try again shortly").Wrap(err)
	}
	if !ok {
		return apperr.RateLimited(window)
	}
	return nil
}

// allowIP applies a per-IP limit when the client IP is known.
func (s *Service) allowIP(ctx context.Context, scope string, limit int, window time.Duration) error {
	ip := reqctx.From(ctx).IP
	if ip == "" {
		return nil
	}
	return s.allow(ctx, scope+":ip:"+ip, limit, window)
}

// record writes an audit row in tx as the given actor (sign-in flows have no
// principal on the context yet, but the row should name who signed in).
func record(ctx context.Context, tx pgx.Tx, actor *auth.Principal, e audit.Entry) error {
	if actor != nil {
		ctx = auth.WithPrincipal(ctx, *actor)
	}
	_, err := audit.Record(ctx, tx, e)
	return err
}

// recordLoginFailure audits a failed sign-in for a known account in its own
// transaction. Failures to audit are logged, never shown to the caller.
func (s *Service) recordLoginFailure(ctx context.Context, entityType string, id uuid.UUID, reason string) {
	err := s.withTx(ctx, func(tx pgx.Tx, _ *store.Queries) error {
		return record(ctx, tx, nil, audit.Entry{Action: "identity.login_failed", EntityType: entityType, EntityID: id,
			Meta: map[string]any{"reason": reason}})
	})
	if err != nil {
		logx.From(ctx).WarnContext(ctx, "identity: audit login failure", "err", err)
	}
}

// Errors shared by the sign-in flows. Login failures use one message whatever
// went wrong so they do not reveal which accounts exist.
var (
	errBadFALogin = apperr.Unauthorized("invalid login ID or password")
	errBadHOLogin = apperr.Unauthorized("invalid email, password or code")
)

func errDeviceRevoked() *apperr.Error {
	return &apperr.Error{Kind: apperr.KindUnauthorized, Code: "device_revoked",
		Message: "this device has been revoked; clear the app data and sign in again"}
}

func unauthorizedCode(code, msg string) *apperr.Error {
	return &apperr.Error{Kind: apperr.KindUnauthorized, Code: code, Message: msg}
}

func errTempPasswordExpired() *apperr.Error {
	return unauthorizedCode("temp_password_expired", "your temporary password has expired; ask HO to reset it")
}

// tempPasswordExpired reports whether an account's temporary password has run
// out. A NULL expiry on a must-change account does not expire (rows from
// before migration 00016 were back-filled, so this should not happen).
func tempPasswordExpired(mustChange bool, expiresAt *time.Time, now time.Time) bool {
	return mustChange && expiresAt != nil && !now.Before(*expiresAt)
}

// ---- small conversions ----

func tp(t time.Time) *time.Time { return &t }

func sp(s string) *string { return &s }

// optText trims s; nil or blank becomes nil.
func optText(s *string) *string {
	if s == nil {
		return nil
	}
	t := strings.TrimSpace(*s)
	if t == "" {
		return nil
	}
	return &t
}

// clip trims s and cuts it to at most n runes.
func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

func ipAddr(ctx context.Context) *netip.Addr {
	a, err := netip.ParseAddr(reqctx.From(ctx).IP)
	if err != nil {
		return nil
	}
	return &a
}

func userAgent(ctx context.Context) *string {
	ua := clip(reqctx.From(ctx).UserAgent, 300)
	if ua == "" {
		return nil
	}
	return &ua
}

func nullUUID(id uuid.UUID) uuid.NullUUID { return uuid.NullUUID{UUID: id, Valid: id != uuid.Nil} }

func dedupeUUIDs(in []uuid.UUID) []uuid.UUID {
	out := make([]uuid.UUID, 0, len(in))
	seen := make(map[uuid.UUID]bool, len(in))
	for _, id := range in {
		if id == uuid.Nil || seen[id] {
			continue
		}
		seen[id] = true
		out = append(out, id)
	}
	return out
}
