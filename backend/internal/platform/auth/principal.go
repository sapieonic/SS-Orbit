// Package auth handles identity primitives shared by every module: the
// authenticated Principal on the context, role checks, JWT access tokens,
// signed web-link tokens, opaque refresh tokens, argon2id password hashing and
// TOTP. Session and device storage live in the identity module.
package auth

import (
	"context"
	"slices"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
)

// Kind is the kind of subject a token was issued to.
type Kind string

const (
	KindFarmer Kind = "farmer" // farmer app
	KindFA     Kind = "fa"     // field assistant app
	KindHO     Kind = "ho"     // HO admin portal
	KindWeb    Kind = "web"    // signed farmer web-page link (ID = farmer ID)
	KindSystem Kind = "system" // workers / jobs; never issued as a token
)

// Role is an HO user's role. Only meaningful when Kind == KindHO.
type Role string

const (
	RoleAdmin    Role = "admin"
	RoleAgronomy Role = "agronomy"
	RoleFinance  Role = "finance"
	RoleOps      Role = "ops"
)

// Principal is who is making the request. Zero-valued fields mean "not
// applicable" (uuid.Nil, "" or nil), so it is cheap to copy and compare.
type Principal struct {
	Kind Kind
	// ID is the farmer, FA or HO user ID (for KindWeb, the farmer ID).
	ID uuid.UUID
	// Role is set for HO users only.
	Role Role
	// DistrictIDs is the HO area scope; empty means all districts.
	DistrictIDs []uuid.UUID
	// DeviceID is the devices.id for app tokens (farmer, fa); uuid.Nil otherwise.
	DeviceID uuid.UUID
	// SessionID is the sessions.id the access token was minted from.
	SessionID uuid.UUID
	// OnBehalfOf is the farmer an FA is acting for in assisted mode; uuid.Nil otherwise.
	OnBehalfOf uuid.UUID
	// LinkPurpose is set for KindWeb link tokens (e.g. "advice", "consent").
	LinkPurpose string
	// MustChangePassword is set on FA and HO tokens issued while the account
	// still has a temporary password. The surface guard then allows only the
	// password change (and sign-out, refresh, /v1/admin/me).
	MustChangePassword bool
}

// IsHO reports whether p is an HO portal user.
func (p Principal) IsHO() bool { return p.Kind == KindHO }

// HasAreaScope reports whether an HO user is limited to some districts.
func (p Principal) HasAreaScope() bool { return p.Kind == KindHO && len(p.DistrictIDs) > 0 }

// CanSeeDistrict reports whether an HO user may see data in district id.
// Unscoped HO users see everything.
func (p Principal) CanSeeDistrict(id uuid.UUID) bool {
	if !p.HasAreaScope() {
		return p.Kind == KindHO
	}
	return slices.Contains(p.DistrictIDs, id)
}

type ctxKey struct{}

// WithPrincipal returns ctx carrying p. httpx's surface guard calls this; tests
// use it (or testutil helpers) to fake a caller.
func WithPrincipal(ctx context.Context, p Principal) context.Context {
	return context.WithValue(ctx, ctxKey{}, p)
}

// FromContext returns the principal on ctx and whether one is present.
func FromContext(ctx context.Context) (Principal, bool) {
	p, ok := ctx.Value(ctxKey{}).(Principal)
	return p, ok
}

// WithOnBehalfOf returns ctx whose principal acts for farmerID (assisted mode).
// No-op if ctx has no principal.
func WithOnBehalfOf(ctx context.Context, farmerID uuid.UUID) context.Context {
	p, ok := FromContext(ctx)
	if !ok {
		return ctx
	}
	p.OnBehalfOf = farmerID
	return WithPrincipal(ctx, p)
}

// Require returns the principal or apperr.Unauthorized if there is none.
func Require(ctx context.Context) (Principal, error) {
	p, ok := FromContext(ctx)
	if !ok || p.ID == uuid.Nil {
		return Principal{}, apperr.Unauthorized("")
	}
	return p, nil
}

// RequireKind returns the principal if its Kind is one of kinds, otherwise
// Unauthorized (no principal) or Forbidden (wrong kind).
func RequireKind(ctx context.Context, kinds ...Kind) (Principal, error) {
	p, err := Require(ctx)
	if err != nil {
		return p, err
	}
	if !slices.Contains(kinds, p.Kind) {
		return p, apperr.Forbidden("")
	}
	return p, nil
}

// RequireRole returns the principal if it is an HO user with one of roles,
// otherwise Unauthorized (no principal) or Forbidden. Call it at the top of
// every HO service method.
func RequireRole(ctx context.Context, roles ...Role) (Principal, error) {
	p, err := RequireKind(ctx, KindHO)
	if err != nil {
		return p, err
	}
	if !slices.Contains(roles, p.Role) {
		return p, apperr.Forbidden("your role cannot do this")
	}
	return p, nil
}
