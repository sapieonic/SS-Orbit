package auth

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
)

const secret = "test-secret-test-secret-test-secret!"

func TestAccessTokenRoundTrip(t *testing.T) {
	clk := clock.NewFake(time.Date(2026, 6, 1, 9, 0, 0, 0, time.UTC))
	tk := NewTokens(secret, "orbit", 15*time.Minute, clk)
	p := Principal{
		Kind: KindHO, ID: uuid.New(), Role: RoleOps,
		DistrictIDs: []uuid.UUID{uuid.New()}, SessionID: uuid.New(),
	}
	tok, exp, err := tk.IssueAccess(p)
	require.NoError(t, err)
	assert.Equal(t, clk.Now().Add(15*time.Minute), exp)

	got, err := tk.Verify(tok)
	require.NoError(t, err)
	assert.Equal(t, p, got)

	fa := Principal{Kind: KindFA, ID: uuid.New(), DeviceID: uuid.New(), OnBehalfOf: uuid.New(), MustChangePassword: true}
	tok, _, err = tk.IssueAccess(fa)
	require.NoError(t, err)
	got, err = tk.Verify(tok)
	require.NoError(t, err)
	assert.Equal(t, fa, got)
}

func TestVerifyRejects(t *testing.T) {
	clk := clock.NewFake(time.Date(2026, 6, 1, 9, 0, 0, 0, time.UTC))
	tk := NewTokens(secret, "orbit", time.Minute, clk)
	tok, _, err := tk.IssueAccess(Principal{Kind: KindFarmer, ID: uuid.New()})
	require.NoError(t, err)

	// wrong secret
	_, err = NewTokens(strings.Repeat("x", 32), "orbit", time.Minute, clk).Verify(tok)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))
	// wrong issuer
	_, err = NewTokens(secret, "other", time.Minute, clk).Verify(tok)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))
	// tampered
	_, err = tk.Verify(tok[:len(tok)-2] + "xx")
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))
	// expired (beyond 30s leeway)
	clk.Advance(2 * time.Minute)
	_, err = tk.Verify(tok)
	e, ok := apperr.As(err)
	require.True(t, ok)
	assert.Equal(t, "expired", e.Details["reason"])
	// garbage
	_, err = tk.Verify("not-a-jwt")
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))
	// cannot issue system/web as access tokens
	_, _, err = tk.IssueAccess(Principal{Kind: KindSystem, ID: uuid.New()})
	assert.Error(t, err)
}

func TestLinkToken(t *testing.T) {
	tk := NewTokens(secret, "orbit", time.Minute, nil)
	farmer := uuid.New()
	tok, _, err := tk.IssueLink(farmer, "advice", time.Hour)
	require.NoError(t, err)
	p, err := tk.Verify(tok)
	require.NoError(t, err)
	assert.Equal(t, KindWeb, p.Kind)
	assert.Equal(t, farmer, p.ID)
	assert.Equal(t, "advice", p.LinkPurpose)
}

func TestPasswords(t *testing.T) {
	h, err := HashPassword("correct horse")
	require.NoError(t, err)
	assert.True(t, strings.HasPrefix(h, "$argon2id$v=19$m=19456,t=2,p=1$"))
	ok, err := VerifyPassword(h, "correct horse")
	require.NoError(t, err)
	assert.True(t, ok)
	ok, err = VerifyPassword(h, "wrong")
	require.NoError(t, err)
	assert.False(t, ok)
	h2, _ := HashPassword("correct horse")
	assert.NotEqual(t, h, h2, "salted")
	_, err = VerifyPassword("$bcrypt$xx", "x")
	assert.ErrorIs(t, err, ErrBadHash)
}

func TestTOTP(t *testing.T) {
	sec, url, err := GenerateTOTP("Orbit", "ops@shanmukha.in")
	require.NoError(t, err)
	assert.Contains(t, url, "otpauth://totp/")
	now := time.Now()
	code, err := TOTPCode(sec, now)
	require.NoError(t, err)
	assert.True(t, ValidateTOTP(code, sec, now))
	assert.True(t, ValidateTOTP(code, sec, now.Add(30*time.Second)), "one step skew allowed")
	assert.False(t, ValidateTOTP(code, sec, now.Add(5*time.Minute)))
	assert.False(t, ValidateTOTP("000000x", sec, now))
}

func TestRefreshToken(t *testing.T) {
	tok, hash := NewRefreshToken()
	assert.Len(t, tok, 43)
	assert.Equal(t, hash, HashRefreshToken(tok))
	tok2, _ := NewRefreshToken()
	assert.NotEqual(t, tok, tok2)
	d := RandomDigits(6)
	assert.Len(t, d, 6)
	for _, r := range d {
		assert.True(t, r >= '0' && r <= '9')
	}
}

func TestRequireRole(t *testing.T) {
	ctx := context.Background()
	_, err := RequireRole(ctx, RoleAdmin)
	assert.True(t, apperr.Is(err, apperr.KindUnauthorized))

	ctx = WithPrincipal(ctx, Principal{Kind: KindHO, ID: uuid.New(), Role: RoleAgronomy})
	_, err = RequireRole(ctx, RoleAdmin, RoleOps)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	p, err := RequireRole(ctx, RoleAgronomy)
	require.NoError(t, err)
	assert.Equal(t, RoleAgronomy, p.Role)

	fa := WithPrincipal(context.Background(), Principal{Kind: KindFA, ID: uuid.New()})
	_, err = RequireRole(fa, RoleAdmin)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	_, err = RequireKind(fa, KindFA)
	assert.NoError(t, err)
}

func TestAreaScope(t *testing.T) {
	d1, d2 := uuid.New(), uuid.New()
	all := Principal{Kind: KindHO, ID: uuid.New(), Role: RoleOps}
	scoped := Principal{Kind: KindHO, ID: uuid.New(), Role: RoleOps, DistrictIDs: []uuid.UUID{d1}}
	assert.True(t, all.CanSeeDistrict(d2))
	assert.True(t, scoped.CanSeeDistrict(d1))
	assert.False(t, scoped.CanSeeDistrict(d2))
	assert.False(t, Principal{Kind: KindFA}.CanSeeDistrict(d1))
}
