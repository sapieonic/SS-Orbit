package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParseDefaultsAndFixedOTP(t *testing.T) {
	t.Setenv("JWT_SECRET", "0123456789abcdef0123456789abcdef")
	t.Setenv("ORBIT_ENV", "dev")
	t.Setenv("DEV_FIXED_OTP", "123456")
	c, err := Parse()
	require.NoError(t, err)
	assert.Equal(t, ":8080", c.HTTPAddr)
	assert.Equal(t, "123456", c.FixedOTP())
	assert.Equal(t, c.JWTSecret, c.StorageSigningKey)

	c.Env = EnvTest
	assert.Equal(t, "", c.FixedOTP(), "fixed OTP is honoured only in dev")
}

func TestProdRejectsDevSettings(t *testing.T) {
	t.Setenv("JWT_SECRET", "0123456789abcdef0123456789abcdef")
	t.Setenv("ORBIT_ENV", "prod")
	t.Setenv("DEV_FIXED_OTP", "123456")
	_, err := Parse()
	require.Error(t, err)
}

func TestShortSecretRejected(t *testing.T) {
	t.Setenv("JWT_SECRET", "short")
	_, err := Parse()
	require.Error(t, err)
}

// prodEnv sets a prod environment whose only problems are the ones a test adds.
func prodEnv(t *testing.T) {
	t.Setenv("JWT_SECRET", "0123456789abcdef0123456789abcdef")
	t.Setenv("ORBIT_ENV", "prod")
	t.Setenv("DEV_FIXED_OTP", "")
	t.Setenv("CORS_ORIGINS", "https://ho.example.in")
	t.Setenv("SMS_PROVIDER", "msg91")
	t.Setenv("PUSH_PROVIDER", "fcm")
	t.Setenv("STORAGE_PROVIDER", "s3")
	t.Setenv("TOTP_ENC_KEY", "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=") // 32 bytes
}

func TestProdRefusesDevAdapters(t *testing.T) {
	prodEnv(t)
	_, err := Parse()
	require.NoError(t, err, "a fully configured prod env starts")

	for _, tc := range []struct{ env, val, want string }{
		{"SMS_PROVIDER", "log", "SMS_PROVIDER=log"},
		{"PUSH_PROVIDER", "log", "PUSH_PROVIDER=log"},
		{"STORAGE_PROVIDER", "local", "STORAGE_PROVIDER=local"},
		{"TOTP_ENC_KEY", "", "TOTP_ENC_KEY is required"},
	} {
		t.Run(tc.env, func(t *testing.T) {
			prodEnv(t)
			t.Setenv(tc.env, tc.val)
			_, err := Parse()
			require.Error(t, err)
			assert.Contains(t, err.Error(), tc.want)
		})
	}
}

func TestTOTPKey(t *testing.T) {
	t.Setenv("JWT_SECRET", "0123456789abcdef0123456789abcdef")
	t.Setenv("ORBIT_ENV", "dev")
	t.Setenv("TOTP_ENC_KEY", "")
	c, err := Parse()
	require.NoError(t, err)
	k, err := c.TOTPKey()
	require.NoError(t, err)
	assert.Len(t, k, 32, "dev falls back to a key derived from JWT_SECRET")

	t.Setenv("TOTP_ENC_KEY", "dG9vIHNob3J0") // "too short"
	_, err = Parse()
	require.Error(t, err)
	assert.Contains(t, err.Error(), "32 bytes")
}

func TestDefaults(t *testing.T) {
	c := ForTest()
	assert.Equal(t, "8h0m0s", c.RefreshTTLHO.String(), "HO sessions last a working day")
	assert.Equal(t, "720h0m0s", c.RefreshTTLFA.String())
	assert.EqualValues(t, 2<<20, c.HTTPMaxBodyBytes)
	assert.EqualValues(t, 5<<20, c.HTTPLargeBodyBytes)
}

func TestFarmerWebBaseFallsBackToPublicBaseURL(t *testing.T) {
	c := ForTest()
	c.PublicBaseURL = "https://api.example.in/"
	assert.Equal(t, "https://api.example.in", c.FarmerWebBase())
	c.FarmerWebBaseURL = "https://f.example.in/"
	assert.Equal(t, "https://f.example.in", c.FarmerWebBase())
}

func TestAppRelease(t *testing.T) {
	t.Setenv("JWT_SECRET", "0123456789abcdef0123456789abcdef")
	t.Setenv("ORBIT_ENV", "dev")
	t.Setenv("APP_MIN_VERSION_FA", "1.4.0")
	t.Setenv("APP_LATEST_VERSION_FA", "1.6.2")
	t.Setenv("APP_STORE_URL_FA", "https://play.google.com/store/apps/details?id=in.orbit.fa")
	t.Setenv("APP_FLAGS_FA", "voice_notes=true,map=false")
	c, err := Parse()
	require.NoError(t, err)
	fa, ok := c.App("fa")
	require.True(t, ok)
	assert.Equal(t, AppRelease{MinVersion: "1.4.0", LatestVersion: "1.6.2",
		StoreURL: "https://play.google.com/store/apps/details?id=in.orbit.fa",
		Flags:    map[string]bool{"voice_notes": true, "map": false}}, fa)

	farmer, ok := c.App("farmer")
	require.True(t, ok)
	assert.Equal(t, "0.0.0", farmer.MinVersion, "no forced update by default")
	assert.Equal(t, "0.0.0", farmer.LatestVersion)
	assert.NotNil(t, farmer.Flags)
	_, ok = c.App("ho")
	assert.False(t, ok)

	t.Setenv("APP_MIN_VERSION_FARMER", "one")
	_, err = Parse()
	require.Error(t, err)
	assert.Contains(t, err.Error(), "APP_MIN_VERSION_FARMER")
}

func TestCompareVersions(t *testing.T) {
	assert.Equal(t, 0, CompareVersions("1.4", "1.4.0"))
	assert.Equal(t, -1, CompareVersions("1.4.0", "1.10.0"))
	assert.Equal(t, 1, CompareVersions("2.0.0+45", "1.99.9"))
	assert.Equal(t, -1, CompareVersions("", "0.0.1"))
}

func TestOTPAppHashValidated(t *testing.T) {
	t.Setenv("JWT_SECRET", "0123456789abcdef0123456789abcdef")
	t.Setenv("ORBIT_ENV", "dev")
	t.Setenv("OTP_SMS_APP_HASH", "FA+9qCX9VSu")
	_, err := Parse()
	require.NoError(t, err)
	t.Setenv("OTP_SMS_APP_HASH", "too-short")
	_, err = Parse()
	require.Error(t, err)
}

func TestLoadDatabaseNeedsOnlyDatabaseURL(t *testing.T) {
	// A prod env with none of the API's settings: Load fails, LoadDatabase works.
	t.Setenv("ORBIT_ENV", "prod")
	t.Setenv("JWT_SECRET", "")
	t.Setenv("DATABASE_URL", "postgres://u:p@db:5432/orbit")
	_, err := Parse()
	require.Error(t, err)
	c, err := LoadDatabase()
	require.NoError(t, err)
	assert.Equal(t, "postgres://u:p@db:5432/orbit", c.DatabaseURL)
}

func TestEmptyRedisURLDisablesRedis(t *testing.T) {
	t.Setenv("JWT_SECRET", "0123456789abcdef0123456789abcdef")
	t.Setenv("ORBIT_ENV", "dev")
	t.Setenv("REDIS_URL", "")
	t.Setenv("APP_FLAGS_FARMER", "") // as in .env.example
	t.Setenv("FARMER_WEB_BASE_URL", "")
	c, err := Parse()
	require.NoError(t, err)
	assert.Empty(t, c.RedisURL, "REDIS_URL= must mean no Redis, not the default")
	assert.Equal(t, ":8081", c.WorkerHealthAddr)
}
