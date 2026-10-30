package identity

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"math/big"
	"strings"
	"sync"
	"unicode"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
)

// otpHash is HMAC-SHA256(server secret, challenge ID || code). A plain hash of
// a 6-digit code could be reversed from a database dump in milliseconds; the
// keyed hash cannot without the secret. Comparing with hmac.Equal is constant
// time.
func (s *Service) otpHash(challengeID uuid.UUID, code string) []byte {
	m := hmac.New(sha256.New, []byte("orbit-otp:"+s.deps.Config.JWTSecret))
	m.Write(challengeID[:])
	m.Write([]byte(code))
	return m.Sum(nil)
}

// successorToken derives the refresh token that replaces prev at rotation:
// base64url(HMAC-SHA256(server secret, prev)). Only the server can compute it,
// so it is as unguessable as a random token, and a retried refresh inside the
// grace window can be answered with the same successor without the server
// ever storing a refresh token in clear.
func (s *Service) successorToken(prev string) string {
	m := hmac.New(sha256.New, []byte("orbit-refresh-successor:"+s.deps.Config.JWTSecret))
	m.Write([]byte(prev))
	return base64.RawURLEncoding.EncodeToString(m.Sum(nil))
}

// tempPasswordAlphabet leaves out look-alike characters (0/o, 1/l/i) because
// HO reads temporary passwords out to FAs over the phone.
const tempPasswordAlphabet = "abcdefghjkmnpqrstuvwxyz23456789"

// newTempPassword returns a random 10-character password (about 49 bits),
// always with at least one letter and one digit so it passes the policy.
func newTempPassword() string {
	for {
		b := make([]byte, 10)
		n := big.NewInt(int64(len(tempPasswordAlphabet)))
		for i := range b {
			d, _ := rand.Int(rand.Reader, n)
			b[i] = tempPasswordAlphabet[d.Int64()]
		}
		if p := string(b); checkPasswordRules(p) == "" {
			return p
		}
	}
}

// checkPasswordRules returns why p is too weak, or "".
func checkPasswordRules(p string) string {
	if utf8.RuneCountInString(p) < 8 {
		return "must be at least 8 characters"
	}
	var letter, digit bool
	for _, r := range p {
		letter = letter || unicode.IsLetter(r)
		digit = digit || unicode.IsDigit(r)
	}
	if !letter || !digit {
		return "must contain a letter and a digit"
	}
	return ""
}

// validateNewPassword applies the password policy for a self-chosen password.
func validateNewPassword(next, current, loginID string) error {
	if why := checkPasswordRules(next); why != "" {
		return apperr.Validation("new_password", why)
	}
	if next == current {
		return apperr.Validation("new_password", "must be different from the current password")
	}
	if loginID != "" && strings.Contains(strings.ToLower(next), strings.ToLower(loginID)) {
		return apperr.Validation("new_password", "must not contain your login ID or email")
	}
	return nil
}

var (
	dummyHashOnce sync.Once
	dummyHash     string
)

// burnPasswordCheck verifies password against a fixed dummy hash so a login
// for an unknown account takes as long as one for a real account.
func burnPasswordCheck(password string) {
	dummyHashOnce.Do(func() { dummyHash, _ = auth.HashPassword("orbit-dummy-password-1") })
	_, _ = auth.VerifyPassword(dummyHash, password)
}
