package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
)

// Tokens issues and verifies HS256 JWTs: access tokens (farmer, fa, ho) and
// signed web-link tokens (web). Refresh tokens are opaque (see refresh.go).
type Tokens struct {
	secret    []byte
	issuer    string
	accessTTL time.Duration
	clock     clock.Clock
}

// NewTokens builds a token service. secret must be >= 32 bytes (config
// validates this).
func NewTokens(secret, issuer string, accessTTL time.Duration, clk clock.Clock) *Tokens {
	if clk == nil {
		clk = clock.System()
	}
	return &Tokens{secret: []byte(secret), issuer: issuer, accessTTL: accessTTL, clock: clk}
}

// claims is the JWT body. Short claim names keep tokens small on 2G networks.
type claims struct {
	Kind        Kind     `json:"knd"`
	Role        Role     `json:"rol,omitempty"`
	DistrictIDs []string `json:"dst,omitempty"`
	DeviceID    string   `json:"dev,omitempty"`
	SessionID   string   `json:"sid,omitempty"`
	OnBehalfOf  string   `json:"obo,omitempty"`
	Purpose     string   `json:"pur,omitempty"`
	MustChange  bool     `json:"pwc,omitempty"`
	jwt.RegisteredClaims
}

// IssueAccess mints an access token for p (Kind farmer, fa or ho) valid for
// the configured access TTL.
func (t *Tokens) IssueAccess(p Principal) (token string, expiresAt time.Time, err error) {
	switch p.Kind {
	case KindFarmer, KindFA, KindHO:
	default:
		return "", time.Time{}, fmt.Errorf("auth: cannot issue access token for kind %q", p.Kind)
	}
	return t.issue(p, t.accessTTL)
}

// IssueLink mints a signed farmer web-page link token (KindWeb) for farmerID.
func (t *Tokens) IssueLink(farmerID uuid.UUID, purpose string, ttl time.Duration) (string, time.Time, error) {
	return t.issue(Principal{Kind: KindWeb, ID: farmerID, LinkPurpose: purpose}, ttl)
}

func (t *Tokens) issue(p Principal, ttl time.Duration) (string, time.Time, error) {
	if p.ID == uuid.Nil {
		return "", time.Time{}, errors.New("auth: principal ID is required")
	}
	now := t.clock.Now()
	exp := now.Add(ttl)
	c := claims{
		Kind:       p.Kind,
		Role:       p.Role,
		Purpose:    p.LinkPurpose,
		MustChange: p.MustChangePassword,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    t.issuer,
			Subject:   p.ID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now.Add(-time.Minute)),
			ExpiresAt: jwt.NewNumericDate(exp),
		},
	}
	for _, d := range p.DistrictIDs {
		c.DistrictIDs = append(c.DistrictIDs, d.String())
	}
	if p.DeviceID != uuid.Nil {
		c.DeviceID = p.DeviceID.String()
	}
	if p.SessionID != uuid.Nil {
		c.SessionID = p.SessionID.String()
	}
	if p.OnBehalfOf != uuid.Nil {
		c.OnBehalfOf = p.OnBehalfOf.String()
	}
	s, err := jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString(t.secret)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("auth: sign: %w", err)
	}
	return s, exp, nil
}

// Verify parses and validates a token (signature, HS256 only, issuer, expiry)
// and returns its principal. Any failure is apperr.Unauthorized.
func (t *Tokens) Verify(token string) (Principal, error) {
	var c claims
	_, err := jwt.ParseWithClaims(token, &c, func(*jwt.Token) (any, error) { return t.secret, nil },
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithIssuer(t.issuer),
		jwt.WithExpirationRequired(),
		jwt.WithLeeway(30*time.Second),
		jwt.WithTimeFunc(t.clock.Now),
	)
	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return Principal{}, apperr.Unauthorized("token expired").WithDetail("reason", "expired")
		}
		return Principal{}, apperr.Unauthorized("invalid token")
	}
	p := Principal{Kind: c.Kind, Role: c.Role, LinkPurpose: c.Purpose, MustChangePassword: c.MustChange}
	bad := func() (Principal, error) { return Principal{}, apperr.Unauthorized("invalid token") }
	if p.ID, err = uuid.Parse(c.Subject); err != nil {
		return bad()
	}
	switch p.Kind {
	case KindFarmer, KindFA, KindHO, KindWeb:
	default:
		return bad()
	}
	for _, s := range c.DistrictIDs {
		id, err := uuid.Parse(s)
		if err != nil {
			return bad()
		}
		p.DistrictIDs = append(p.DistrictIDs, id)
	}
	for _, f := range []struct {
		src string
		dst *uuid.UUID
	}{{c.DeviceID, &p.DeviceID}, {c.SessionID, &p.SessionID}, {c.OnBehalfOf, &p.OnBehalfOf}} {
		if f.src == "" {
			continue
		}
		if *f.dst, err = uuid.Parse(f.src); err != nil {
			return bad()
		}
	}
	return p, nil
}

// AccessTTL returns the configured access token lifetime.
func (t *Tokens) AccessTTL() time.Duration { return t.accessTTL }
