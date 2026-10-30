// Package config loads process configuration from the environment. In dev a
// .env file in the working directory is loaded first (real environment
// variables always win). See backend/.env.example for every variable.
package config

import (
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/caarlos0/env/v11"
	"github.com/joho/godotenv"
)

// Environments.
const (
	EnvDev  = "dev"
	EnvTest = "test"
	EnvProd = "prod"
)

// Config is the full process configuration. Add new fields here (with an
// env tag and a sane default) and to .env.example.
type Config struct {
	Env      string `env:"ORBIT_ENV" envDefault:"dev"` // dev | test | prod
	LogLevel string `env:"LOG_LEVEL" envDefault:"info"`
	// LogFormat is "text" (dev) or "json" (prod).
	LogFormat string `env:"LOG_FORMAT" envDefault:"text"`

	HTTPAddr string `env:"HTTP_ADDR" envDefault:":8080"`
	// PublicBaseURL is how clients reach this server; used for dev file URLs.
	PublicBaseURL string `env:"PUBLIC_BASE_URL" envDefault:"http://localhost:8080"`
	// FarmerWebBaseURL is where the farmer web pages live (links in SMS and
	// WhatsApp, e.g. <base>/web/notices/{id}?t=..., the farmer-web app route). Empty means
	// PublicBaseURL; use FarmerWebBase().
	FarmerWebBaseURL string `env:"FARMER_WEB_BASE_URL"`
	// CORSOrigins allowed for browser clients (HO portal, farmer web). "*" allows all (dev only).
	CORSOrigins []string `env:"CORS_ORIGINS" envSeparator:"," envDefault:"http://localhost:5173,http://localhost:3000"`
	// TrustProxyHeaders makes the client IP come from X-Forwarded-For / X-Real-IP. Enable only behind a trusted proxy.
	TrustProxyHeaders bool `env:"TRUST_PROXY_HEADERS" envDefault:"false"`
	// HTTPMaxBodyBytes caps every request body (413 payload_too_large above it).
	HTTPMaxBodyBytes int64 `env:"HTTP_MAX_BODY_BYTES" envDefault:"2097152"` // 2 MiB
	// HTTPLargeBodyBytes is the cap for the few routes that opt in to bigger
	// bodies (FA sync batch, CSV imports); see httpx.RouterConfig.BodyLimits.
	HTTPLargeBodyBytes int64 `env:"HTTP_LARGE_BODY_BYTES" envDefault:"5242880"` // 5 MiB

	DatabaseURL     string `env:"DATABASE_URL" envDefault:"postgres://orbit:orbit@localhost:5432/orbit?sslmode=disable"`
	DatabaseMaxConn int32  `env:"DATABASE_MAX_CONNS" envDefault:"20"`
	// TestDatabaseURL is only read by tests (internal/platform/testutil).
	TestDatabaseURL string `env:"TEST_DATABASE_URL"`
	// RedisURL; empty or unset disables Redis (cache misses, rate limits fall
	// back to Postgres). No envDefault on purpose: the env library replaces an
	// empty value with the default, so "REDIS_URL=" could never mean "off".
	// .env.example sets the dev value.
	RedisURL string `env:"REDIS_URL"`

	JWTSecret string `env:"JWT_SECRET"`
	JWTIssuer string `env:"JWT_ISSUER" envDefault:"orbit"`
	// AccessTokenTTL applies to every access token kind.
	AccessTokenTTL time.Duration `env:"ACCESS_TOKEN_TTL" envDefault:"15m"`
	// Refresh token lifetimes per subject kind.
	RefreshTTLFarmer time.Duration `env:"REFRESH_TTL_FARMER" envDefault:"2160h"` // 90 days
	RefreshTTLFA     time.Duration `env:"REFRESH_TTL_FA" envDefault:"720h"`      // 30 days
	// HO sessions end after a working day whatever the activity (absolute, not sliding).
	RefreshTTLHO time.Duration `env:"REFRESH_TTL_HO" envDefault:"8h"`
	// WebLinkTTL is the default lifetime of signed farmer web-page links.
	WebLinkTTL time.Duration `env:"WEB_LINK_TTL" envDefault:"168h"`
	// OTPTTL is how long an SMS OTP stays valid.
	OTPTTL time.Duration `env:"OTP_TTL" envDefault:"5m"`
	// OTPSMSAppHash is the 11-character Android app signature hash. When set,
	// sign-in OTP SMS carry the "<#>" prefix and end with this hash so the
	// farmer app can read the code with the SMS Retriever API (zero tap).
	OTPSMSAppHash string `env:"OTP_SMS_APP_HASH"`
	// DevFixedOTP, when set and Env is dev, is accepted as the OTP for every phone
	// and no SMS is needed. Ignored outside dev; use FixedOTP().
	DevFixedOTP string `env:"DEV_FIXED_OTP"`

	// TOTPEncKey encrypts HO TOTP secrets at rest (AES-256-GCM): 32 random bytes,
	// base64. Required in prod; in dev/test an empty value falls back to a key
	// derived from JWT_SECRET. Generate one with: openssl rand -base64 32
	TOTPEncKey string `env:"TOTP_ENC_KEY"`

	// StorageProvider selects the object storage adapter. Only "local" (disk,
	// dev) exists today; prod refuses to start with it.
	StorageProvider string `env:"STORAGE_PROVIDER" envDefault:"local"`
	// StorageDir is where the local-disk storage keeps files (dev).
	StorageDir string `env:"STORAGE_DIR" envDefault:".data/storage"`
	// StorageSigningKey signs dev file URLs; defaults to JWTSecret.
	StorageSigningKey string `env:"STORAGE_SIGNING_KEY"`

	// SMSProvider and PushProvider select the senders. Only "log" exists today
	// (dev: prints, never sends); prod refuses to start with it.
	SMSProvider  string `env:"SMS_PROVIDER" envDefault:"log"`
	PushProvider string `env:"PUSH_PROVIDER" envDefault:"log"`

	// App releases for GET /v1/auth/app-config and the device heartbeats; use
	// App(kind). Versions are dotted numbers ("1.4.0"). An app older than the
	// min version must update before it is used; "0.0.0" forces nothing. An
	// empty latest version means the min version. Flags are
	// "name=true,other=false" (feature switches the app reads at start).
	AppMinVersionFarmer    string          `env:"APP_MIN_VERSION_FARMER" envDefault:"0.0.0"`
	AppLatestVersionFarmer string          `env:"APP_LATEST_VERSION_FARMER"`
	AppStoreURLFarmer      string          `env:"APP_STORE_URL_FARMER"`
	AppFlagsFarmer         map[string]bool `env:"APP_FLAGS_FARMER" envKeyValSeparator:"="`
	AppMinVersionFA        string          `env:"APP_MIN_VERSION_FA" envDefault:"0.0.0"`
	AppLatestVersionFA     string          `env:"APP_LATEST_VERSION_FA"`
	AppStoreURLFA          string          `env:"APP_STORE_URL_FA"`
	AppFlagsFA             map[string]bool `env:"APP_FLAGS_FA" envKeyValSeparator:"="`

	// WorkerConcurrency is the max number of River jobs worked at once.
	WorkerConcurrency int `env:"WORKER_CONCURRENCY" envDefault:"20"`
	// WorkerHealthAddr is where the worker serves /healthz and /readyz (ECS
	// health checks).
	WorkerHealthAddr string `env:"WORKER_HEALTH_ADDR" envDefault:":8081"`
	// ShutdownTimeout bounds graceful shutdown of api and worker.
	ShutdownTimeout time.Duration `env:"SHUTDOWN_TIMEOUT" envDefault:"20s"`
}

var (
	appHashRe = regexp.MustCompile(`^[A-Za-z0-9+/]{11}$`)
	versionRe = regexp.MustCompile(`^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$`)
)

// Load reads .env (if present, never overriding real env vars) and parses the
// environment into Config, then validates it.
func Load() (Config, error) {
	_ = godotenv.Load() // .env is optional
	return Parse()
}

// Parse parses the current environment without touching .env.
func Parse() (Config, error) {
	var c Config
	if err := env.Parse(&c); err != nil {
		return c, fmt.Errorf("config: %w", err)
	}
	if c.StorageSigningKey == "" {
		c.StorageSigningKey = c.JWTSecret
	}
	return c, c.Validate()
}

// Validate checks invariants.
func (c Config) Validate() error {
	var errs []error
	switch c.Env {
	case EnvDev, EnvTest, EnvProd:
	default:
		errs = append(errs, fmt.Errorf("ORBIT_ENV must be dev, test or prod, got %q", c.Env))
	}
	if len(c.JWTSecret) < 32 {
		errs = append(errs, errors.New("JWT_SECRET must be at least 32 characters"))
	}
	if c.DatabaseURL == "" {
		errs = append(errs, errors.New("DATABASE_URL is required"))
	}
	if c.TOTPEncKey != "" {
		if _, err := decodeKey32(c.TOTPEncKey); err != nil {
			errs = append(errs, fmt.Errorf("TOTP_ENC_KEY: %w", err))
		}
	}
	if c.OTPSMSAppHash != "" && !appHashRe.MatchString(c.OTPSMSAppHash) {
		errs = append(errs, errors.New("OTP_SMS_APP_HASH must be the 11-character app signature hash (letters, digits, + and /)"))
	}
	for name, v := range map[string]string{
		"APP_MIN_VERSION_FARMER": c.AppMinVersionFarmer, "APP_LATEST_VERSION_FARMER": c.AppLatestVersionFarmer,
		"APP_MIN_VERSION_FA": c.AppMinVersionFA, "APP_LATEST_VERSION_FA": c.AppLatestVersionFA,
	} {
		if v != "" && !versionRe.MatchString(v) {
			errs = append(errs, fmt.Errorf("%s must look like 1.4.0, got %q", name, v))
		}
	}
	if c.HTTPMaxBodyBytes <= 0 || c.HTTPLargeBodyBytes < c.HTTPMaxBodyBytes {
		errs = append(errs, errors.New("HTTP_MAX_BODY_BYTES must be positive and HTTP_LARGE_BODY_BYTES at least as big"))
	}
	if c.Env == EnvProd {
		// Fail closed: the dev adapters print OTPs and signed links to the
		// logs, and local disk is not durable storage.
		if c.SMSProvider == "log" {
			errs = append(errs, errors.New("SMS_PROVIDER=log is not allowed in prod: configure a real SMS adapter (none is implemented yet)"))
		}
		if c.PushProvider == "log" {
			errs = append(errs, errors.New("PUSH_PROVIDER=log is not allowed in prod: configure a real push adapter (none is implemented yet)"))
		}
		if c.StorageProvider == "local" {
			errs = append(errs, errors.New("STORAGE_PROVIDER=local is not allowed in prod: configure an object storage adapter (none is implemented yet)"))
		}
		if c.TOTPEncKey == "" {
			errs = append(errs, errors.New("TOTP_ENC_KEY is required in prod (openssl rand -base64 32)"))
		}
		if c.DevFixedOTP != "" {
			errs = append(errs, errors.New("DEV_FIXED_OTP must not be set in prod"))
		}
		for _, o := range c.CORSOrigins {
			if o == "*" {
				errs = append(errs, errors.New("CORS_ORIGINS must not contain * in prod"))
			}
		}
	}
	if len(errs) > 0 {
		return fmt.Errorf("config: %w", errors.Join(errs...))
	}
	return nil
}

// ForTest returns a Config with every default applied, Env "test" and a fixed
// JWT secret, ignoring the process environment. Used by testutil.
func ForTest() Config {
	var c Config
	_ = env.ParseWithOptions(&c, env.Options{Environment: map[string]string{}})
	c.Env = EnvTest
	c.JWTSecret = "orbit-test-secret-orbit-test-secret!"
	c.StorageSigningKey = c.JWTSecret
	c.RedisURL = ""
	return c
}

// TOTPKey returns the 32-byte key that encrypts HO TOTP secrets: TOTP_ENC_KEY,
// or outside prod, when it is empty, a key derived from JWT_SECRET.
func (c Config) TOTPKey() ([]byte, error) {
	if c.TOTPEncKey != "" {
		return decodeKey32(c.TOTPEncKey)
	}
	if c.Env == EnvProd {
		return nil, errors.New("config: TOTP_ENC_KEY is required in prod")
	}
	sum := sha256.Sum256([]byte("orbit-totp-dev-key:" + c.JWTSecret))
	return sum[:], nil
}

func decodeKey32(s string) ([]byte, error) {
	k, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		return nil, errors.New("must be base64")
	}
	if len(k) != 32 {
		return nil, fmt.Errorf("must decode to 32 bytes, got %d", len(k))
	}
	return k, nil
}

// IsDev reports whether this is a local development process.
func (c Config) IsDev() bool { return c.Env == EnvDev }

// FixedOTP returns DEV_FIXED_OTP only in dev, otherwise "". Identity must use
// this, never DevFixedOTP directly.
func (c Config) FixedOTP() string {
	if c.Env != EnvDev {
		return ""
	}
	return c.DevFixedOTP
}

// FarmerWebBase is the base URL of the farmer web pages, without a trailing
// slash: FARMER_WEB_BASE_URL, or PUBLIC_BASE_URL when that is empty.
func (c Config) FarmerWebBase() string {
	base := c.FarmerWebBaseURL
	if base == "" {
		base = c.PublicBaseURL
	}
	return strings.TrimRight(base, "/")
}

// AppRelease is what an app needs to decide whether to force or offer an update.
type AppRelease struct {
	MinVersion    string
	LatestVersion string // never below MinVersion
	StoreURL      string // "" when not configured
	Flags         map[string]bool
}

// App returns the release settings of the farmer ("farmer") or FA ("fa") app.
func (c Config) App(app string) (AppRelease, bool) {
	var r AppRelease
	switch app {
	case "farmer":
		r = AppRelease{c.AppMinVersionFarmer, c.AppLatestVersionFarmer, c.AppStoreURLFarmer, c.AppFlagsFarmer}
	case "fa":
		r = AppRelease{c.AppMinVersionFA, c.AppLatestVersionFA, c.AppStoreURLFA, c.AppFlagsFA}
	default:
		return AppRelease{}, false
	}
	if r.MinVersion == "" {
		r.MinVersion = "0.0.0"
	}
	if r.LatestVersion == "" || CompareVersions(r.LatestVersion, r.MinVersion) < 0 {
		r.LatestVersion = r.MinVersion
	}
	if r.Flags == nil {
		r.Flags = map[string]bool{}
	}
	return r, true
}

// CompareVersions compares dotted version numbers ("1.4" == "1.4.0" < "1.10").
// Anything after a "-" or "+" (pre-release, build) and non-numeric parts are
// ignored. Returns -1, 0 or 1.
func CompareVersions(a, b string) int {
	pa, pb := versionParts(a), versionParts(b)
	for i := 0; i < max(len(pa), len(pb)); i++ {
		var x, y int
		if i < len(pa) {
			x = pa[i]
		}
		if i < len(pb) {
			y = pb[i]
		}
		if x != y {
			if x < y {
				return -1
			}
			return 1
		}
	}
	return 0
}

func versionParts(v string) []int {
	if i := strings.IndexAny(v, "-+ "); i >= 0 {
		v = v[:i]
	}
	var out []int
	for _, p := range strings.Split(strings.TrimPrefix(v, "v"), ".") {
		n, _ := strconv.Atoi(p)
		out = append(out, n)
	}
	return out
}

// DatabaseConfig is the little cmd/migrate needs. Unlike Load it validates
// nothing else, so migrations can run as a one-off task without the API's
// secrets and provider settings.
type DatabaseConfig struct {
	DatabaseURL string `env:"DATABASE_URL" envDefault:"postgres://orbit:orbit@localhost:5432/orbit?sslmode=disable"`
}

// LoadDatabase reads .env (if present) and DATABASE_URL only.
func LoadDatabase() (DatabaseConfig, error) {
	_ = godotenv.Load()
	var c DatabaseConfig
	if err := env.Parse(&c); err != nil {
		return c, fmt.Errorf("config: %w", err)
	}
	if c.DatabaseURL == "" {
		return c, errors.New("config: DATABASE_URL is required")
	}
	return c, nil
}
