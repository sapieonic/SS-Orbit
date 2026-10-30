package httpx

import (
	"context"
	"log/slog"
	"net"
	"net/http"
	"regexp"
	"runtime/debug"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/reqctx"
)

// Verifier verifies bearer tokens. *auth.Tokens implements it.
type Verifier interface {
	Verify(token string) (auth.Principal, error)
}

// DeviceRevokedFunc reports whether a device has been revoked. The identity
// module provides it; the guard rejects farmer and FA requests from revoked
// devices.
type DeviceRevokedFunc func(ctx context.Context, deviceID uuid.UUID) (bool, error)

// PrincipalCheckFunc decides whether a verified token may still be used
// (device revoked, session signed out, user disabled). It returns nil to
// allow, a 401/403 *apperr.Error to reject, or any other error, which the
// guard logs and answers with 503. It runs on every guarded request, so it
// must be cheap (cached). The identity module provides it.
type PrincipalCheckFunc func(ctx context.Context, p auth.Principal) error

// RouterConfig configures NewRouter.
type RouterConfig struct {
	Logger            *slog.Logger
	Tokens            Verifier
	CORSOrigins       []string // "*" allows any origin
	TrustProxyHeaders bool
	// DeviceRevoked is optional; when nil the device check is skipped.
	DeviceRevoked DeviceRevokedFunc
	// CheckPrincipal is optional; when nil only DeviceRevoked runs.
	CheckPrincipal PrincipalCheckFunc
	// MaxBodyBytes caps request bodies (0 = DefaultMaxBodyBytes).
	MaxBodyBytes int64
	// BodyLimits raises (or lowers) the cap for specific routes, keyed by
	// path. A key ending in "/*" matches every path under it. Keep this list
	// short: only bulk endpoints (FA sync batch, CSV imports) need more.
	BodyLimits map[string]int64
}

// NewRouter returns a chi router with the standard middleware stack, in
// order: request ID + client meta, panic recovery, access log, CORS, body
// size limit, surface guard. Unknown routes and methods get JSON errors.
func NewRouter(cfg RouterConfig) *chi.Mux {
	if cfg.Logger == nil {
		cfg.Logger = discardLogger
	}
	r := chi.NewRouter()
	r.Use(requestMeta(cfg.Logger, cfg.TrustProxyHeaders))
	r.Use(recoverer)
	r.Use(accessLog)
	r.Use(cors(cfg.CORSOrigins))
	r.Use(BodyLimit(cfg.MaxBodyBytes, cfg.BodyLimits))
	r.Use(SurfaceGuard(cfg.Tokens, cfg.DeviceRevoked, cfg.CheckPrincipal))
	r.NotFound(notFound)
	r.MethodNotAllowed(methodNotAllowed)
	return r
}

var requestIDPattern = regexp.MustCompile(`^[A-Za-z0-9._-]{1,64}$`)

// HeaderRequestID is echoed on every response.
const HeaderRequestID = "X-Request-ID"

// requestMeta assigns a request ID (reusing a sane incoming X-Request-ID),
// records client IP and user agent, and stores a request-scoped logger.
func requestMeta(base *slog.Logger, trustProxy bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			id := r.Header.Get(HeaderRequestID)
			if !requestIDPattern.MatchString(id) {
				id = ids.New().String()
			}
			w.Header().Set(HeaderRequestID, id)
			m := reqctx.Meta{RequestID: id, IP: clientIP(r, trustProxy), UserAgent: r.UserAgent()}
			ctx := reqctx.With(r.Context(), m)
			ctx = logx.With(ctx, base.With("request_id", id))
			ctx = context.WithValue(ctx, stateKey{}, &reqState{})
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func clientIP(r *http.Request, trustProxy bool) string {
	if trustProxy {
		if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
			first, _, _ := strings.Cut(xff, ",")
			if ip := net.ParseIP(strings.TrimSpace(first)); ip != nil {
				return ip.String()
			}
		}
		if ip := net.ParseIP(r.Header.Get("X-Real-IP")); ip != nil {
			return ip.String()
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	if ip := net.ParseIP(host); ip != nil {
		return ip.String()
	}
	return ""
}

// reqState is filled by inner middleware for the access log.
type reqState struct {
	principal *auth.Principal
}

type stateKey struct{}

func state(ctx context.Context) *reqState {
	s, _ := ctx.Value(stateKey{}).(*reqState)
	return s
}

func recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				if rec == http.ErrAbortHandler {
					panic(rec)
				}
				logx.From(r.Context()).ErrorContext(r.Context(), "panic", "panic", rec, "stack", string(debug.Stack()))
				WriteError(w, r, apperr.Internalf("panic: %v", rec))
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func accessLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
		next.ServeHTTP(ww, r)
		attrs := []any{
			"method", r.Method, "path", r.URL.Path, "status", ww.Status(),
			"bytes", ww.BytesWritten(), "duration_ms", time.Since(start).Milliseconds(),
		}
		if rc := chi.RouteContext(r.Context()); rc != nil && rc.RoutePattern() != "" {
			attrs = append(attrs, "route", rc.RoutePattern())
		}
		if s := state(r.Context()); s != nil && s.principal != nil {
			attrs = append(attrs, "actor_kind", s.principal.Kind, "actor_id", s.principal.ID)
		}
		level := slog.LevelInfo
		if ww.Status() >= 500 {
			level = slog.LevelError
		}
		if r.URL.Path == "/healthz" || r.URL.Path == "/readyz" {
			level = slog.LevelDebug
		}
		logx.From(r.Context()).Log(r.Context(), level, "http request", attrs...)
	})
}

// cors handles browser preflight and response headers for allowed origins.
func cors(origins []string) func(http.Handler) http.Handler {
	allowAll := false
	allowed := map[string]bool{}
	for _, o := range origins {
		o = strings.TrimSpace(o)
		if o == "*" {
			allowAll = true
		}
		if o != "" {
			allowed[o] = true
		}
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin == "" || (!allowAll && !allowed[origin]) {
				next.ServeHTTP(w, r)
				return
			}
			h := w.Header()
			h.Set("Access-Control-Allow-Origin", origin)
			h.Add("Vary", "Origin")
			h.Set("Access-Control-Allow-Credentials", "true")
			h.Set("Access-Control-Expose-Headers", "ETag, X-Request-ID, Retry-After")
			if r.Method == http.MethodOptions && r.Header.Get("Access-Control-Request-Method") != "" {
				h.Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
				h.Set("Access-Control-Allow-Headers", "Authorization, Content-Type, If-None-Match, If-Match, X-Request-ID")
				h.Set("Access-Control-Max-Age", "600")
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
