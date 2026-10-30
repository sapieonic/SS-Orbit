package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
)

// consentAudience separates consent proofs from access and link tokens: Verify
// rejects them (no knd claim) and VerifyConsentProof rejects everything else.
const consentAudience = "orbit-consent"

// ConsentProof says the farmer on Phone read out the consent OTP to FA FAID at
// VerifiedAt (FAR-04). identity issues it after checking the OTP; farmers
// requires it in EnrolFarmer before recording an fa_otp consent.
type ConsentProof struct {
	FAID       uuid.UUID
	Phone      string // E.164
	VerifiedAt time.Time
}

type consentClaims struct {
	Phone string `json:"phn"`
	jwt.RegisteredClaims
}

// IssueConsentProof signs a proof valid for ttl (long enough for an offline
// enrolment to sync later).
func (t *Tokens) IssueConsentProof(p ConsentProof, ttl time.Duration) (string, error) {
	if p.FAID == uuid.Nil || p.Phone == "" || p.VerifiedAt.IsZero() {
		return "", errors.New("auth: consent proof needs FA, phone and time")
	}
	c := consentClaims{
		Phone: p.Phone,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    t.issuer,
			Subject:   p.FAID.String(),
			Audience:  jwt.ClaimStrings{consentAudience},
			IssuedAt:  jwt.NewNumericDate(p.VerifiedAt),
			ExpiresAt: jwt.NewNumericDate(p.VerifiedAt.Add(ttl)),
		},
	}
	s, err := jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString(t.secret)
	if err != nil {
		return "", fmt.Errorf("auth: sign consent proof: %w", err)
	}
	return s, nil
}

// VerifyConsentProof checks the signature, audience and expiry. Callers must
// still check FAID and Phone against the command. Failure is a validation
// error on field consent.otp_proof.
func (t *Tokens) VerifyConsentProof(token string) (ConsentProof, error) {
	var c consentClaims
	_, err := jwt.ParseWithClaims(token, &c, func(*jwt.Token) (any, error) { return t.secret, nil },
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithIssuer(t.issuer),
		jwt.WithAudience(consentAudience),
		jwt.WithExpirationRequired(),
		jwt.WithIssuedAt(),
		jwt.WithLeeway(30*time.Second),
		jwt.WithTimeFunc(t.clock.Now),
	)
	bad := apperr.Validation("consent.otp_proof", "invalid or expired consent proof")
	if err != nil || c.IssuedAt == nil || c.Phone == "" {
		return ConsentProof{}, bad
	}
	faID, err := uuid.Parse(c.Subject)
	if err != nil {
		return ConsentProof{}, bad
	}
	return ConsentProof{FAID: faID, Phone: c.Phone, VerifiedAt: c.IssuedAt.Time}, nil
}
