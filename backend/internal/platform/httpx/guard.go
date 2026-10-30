package httpx

import (
	"errors"
	"net/http"
	"slices"
	"strings"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

// surface is one row of the CONVENTIONS section 4 table.
type surface struct {
	prefix   string
	kind     auth.Kind // required token kind; "" = no token required
	optional bool      // attach a principal if a valid token is sent, never reject
}

// surfaces is checked in order; first prefix match wins. Paths matching none
// need no token (e.g. /healthz, /readyz, /hooks/*, /dev/files/*).
var surfaces = []surface{
	{prefix: "/v1/auth", optional: true},
	{prefix: "/v1/farmer", kind: auth.KindFarmer},
	{prefix: "/v1/fa", kind: auth.KindFA},
	{prefix: "/v1/admin", kind: auth.KindHO},
	{prefix: "/v1/web", kind: auth.KindWeb},
}

func matchSurface(path string) (surface, bool) {
	for _, s := range surfaces {
		if path == s.prefix || strings.HasPrefix(path, s.prefix+"/") {
			return s, true
		}
	}
	return surface{}, false
}

// bearer extracts the token from "Authorization: Bearer <t>"; for web links
// it also accepts the ?t= query parameter.
func bearer(r *http.Request, allowQuery bool) string {
	if h := r.Header.Get("Authorization"); len(h) > 7 && strings.EqualFold(h[:7], "bearer ") {
		return strings.TrimSpace(h[7:])
	}
	if allowQuery {
		return r.URL.Query().Get("t")
	}
	return ""
}

// passwordChangePaths are the only token-guarded routes a principal with
// MustChangePassword may call (sign-out and refresh are under /v1/auth, which
// the guard never blocks).
var passwordChangePaths = []string{"/v1/fa/me/password", "/v1/admin/me/password", "/v1/admin/me"}

func errPasswordChangeRequired() *apperr.Error {
	return &apperr.Error{Kind: apperr.KindForbidden, Code: "password_change_required",
		Message: "change your temporary password first"}
}

// SurfaceGuard enforces token kind by path prefix (CONVENTIONS section 4) and
// puts the auth.Principal on the request context. Role checks are NOT done
// here; services call auth.RequireRole.
//
// After the token verifies, revocation is checked: deviceRevoked (if set)
// for farmer and FA tokens, then check (if set) for every principal. Finally
// a token carrying MustChangePassword may only reach passwordChangePaths.
func SurfaceGuard(tokens Verifier, deviceRevoked DeviceRevokedFunc, check PrincipalCheckFunc) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			s, ok := matchSurface(r.URL.Path)
			if !ok || r.Method == http.MethodOptions {
				next.ServeHTTP(w, r)
				return
			}
			tok := bearer(r, s.kind == auth.KindWeb)
			if s.optional {
				if tok != "" && tokens != nil {
					if p, err := tokens.Verify(tok); err == nil {
						r = withPrincipal(r, p)
					}
				}
				next.ServeHTTP(w, r)
				return
			}
			if tok == "" || tokens == nil {
				WriteError(w, r, apperr.Unauthorized(""))
				return
			}
			p, err := tokens.Verify(tok)
			if err != nil {
				WriteError(w, r, err)
				return
			}
			if p.Kind != s.kind {
				WriteError(w, r, apperr.Forbidden("this token cannot be used on "+s.prefix))
				return
			}
			if err := checkRevocation(r, p, deviceRevoked, check); err != nil {
				WriteError(w, r, err)
				return
			}
			if p.MustChangePassword && !slices.Contains(passwordChangePaths, r.URL.Path) {
				WriteError(w, r, errPasswordChangeRequired())
				return
			}
			next.ServeHTTP(w, withPrincipal(r, p))
		})
	}
}

// checkRevocation runs the revocation hooks. A hook's 401/403 apperr is
// returned as is; anything else is an infrastructure failure, logged and
// turned into 503 (fail closed).
func checkRevocation(r *http.Request, p auth.Principal, deviceRevoked DeviceRevokedFunc, check PrincipalCheckFunc) error {
	ctx := r.Context()
	if deviceRevoked != nil && (p.Kind == auth.KindFA || p.Kind == auth.KindFarmer) && p.DeviceID != uuid.Nil {
		revoked, err := deviceRevoked(ctx, p.DeviceID)
		if err != nil {
			logx.From(ctx).ErrorContext(ctx, "device revocation check failed", "err", err)
			return apperr.Unavailable("try again shortly")
		}
		if revoked {
			return &apperr.Error{Kind: apperr.KindUnauthorized, Code: "device_revoked", Message: "this device has been revoked"}
		}
	}
	if check == nil {
		return nil
	}
	err := check(ctx, p)
	if err == nil {
		return nil
	}
	var ae *apperr.Error
	if errors.As(err, &ae) && (ae.Kind == apperr.KindUnauthorized || ae.Kind == apperr.KindForbidden) {
		return ae
	}
	logx.From(ctx).ErrorContext(ctx, "principal revocation check failed", "err", err)
	return apperr.Unavailable("try again shortly")
}

func withPrincipal(r *http.Request, p auth.Principal) *http.Request {
	if s := state(r.Context()); s != nil {
		s.principal = &p
	}
	ctx := auth.WithPrincipal(r.Context(), p)
	ctx = logx.With(ctx, logx.From(ctx).With("actor_kind", p.Kind, "actor_id", p.ID))
	return r.WithContext(ctx)
}
