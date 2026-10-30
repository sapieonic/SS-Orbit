package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"math/big"
)

// NewRefreshToken returns a random opaque refresh token (43 chars, base64url,
// 256 bits) and its sha256 hash. Store only the hash (sessions.refresh_token_hash).
func NewRefreshToken() (token string, hash []byte) {
	b := make([]byte, 32)
	_, _ = rand.Read(b) // crypto/rand.Read never returns an error
	token = base64.RawURLEncoding.EncodeToString(b)
	return token, HashRefreshToken(token)
}

// HashRefreshToken returns sha256(token) for lookup.
func HashRefreshToken(token string) []byte {
	h := sha256.Sum256([]byte(token))
	return h[:]
}

// RandomDigits returns n cryptographically random decimal digits (OTP codes).
func RandomDigits(n int) string {
	b := make([]byte, n)
	ten := big.NewInt(10)
	for i := range b {
		d, _ := rand.Int(rand.Reader, ten)
		b[i] = byte('0' + d.Int64())
	}
	return string(b)
}
