package auth

import (
	"time"

	"github.com/pquerna/otp"
	"github.com/pquerna/otp/totp"
)

// GenerateTOTP creates a new TOTP secret for an HO user. accountName is
// usually the email. Returns the base32 secret (store in ho_users.totp_secret)
// and the otpauth:// URL to render as a QR code.
func GenerateTOTP(issuer, accountName string) (secret, url string, err error) {
	key, err := totp.Generate(totp.GenerateOpts{Issuer: issuer, AccountName: accountName})
	if err != nil {
		return "", "", err
	}
	return key.Secret(), key.URL(), nil
}

// ValidateTOTP checks a 6-digit code at time at, allowing one 30-second step of
// clock skew either side.
func ValidateTOTP(code, secret string, at time.Time) bool {
	ok, err := totp.ValidateCustom(code, secret, at, totp.ValidateOpts{
		Period: 30, Skew: 1, Digits: otp.DigitsSix, Algorithm: otp.AlgorithmSHA1,
	})
	return err == nil && ok
}

// TOTPCode returns the current code for secret (tests and dev tooling).
func TOTPCode(secret string, at time.Time) (string, error) {
	return totp.GenerateCode(secret, at)
}
