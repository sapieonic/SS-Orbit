package identity

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"strings"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

// HO TOTP secrets are stored sealed with AES-256-GCM under TOTP_ENC_KEY
// (config.TOTPKey), as "v1:" + base64(nonce || ciphertext). The user ID is the
// additional data, so a sealed secret copied onto another user does not open.
//
// Rows written before migration 00016 hold the secret in clear. openTOTP
// accepts both; a legacy secret is sealed at the user's next sign-in
// (sealLegacyTOTP) and by the maintenance job's sweep (SealLegacyTOTPSecrets).
// The "v1" prefix leaves room to rotate the key later ("v2:" with a new key).
const totpSealPrefix = "v1:"

func (s *Service) totpAEAD() (cipher.AEAD, error) {
	key, err := s.deps.Config.TOTPKey()
	if err != nil {
		return nil, apperr.Internalf("identity: totp key: %w", err)
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, apperr.Internalf("identity: totp cipher: %w", err)
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, apperr.Internalf("identity: totp gcm: %w", err)
	}
	return aead, nil
}

// sealTOTP encrypts a TOTP secret for storage.
func (s *Service) sealTOTP(userID uuid.UUID, secret string) (string, error) {
	aead, err := s.totpAEAD()
	if err != nil {
		return "", err
	}
	nonce := make([]byte, aead.NonceSize())
	_, _ = rand.Read(nonce)
	sealed := aead.Seal(nonce, nonce, []byte(secret), userID[:])
	return totpSealPrefix + base64.StdEncoding.EncodeToString(sealed), nil
}

// openTOTP returns the secret from its stored form; legacy is true when it was
// stored in clear.
func (s *Service) openTOTP(userID uuid.UUID, stored string) (secret string, legacy bool, err error) {
	body, ok := strings.CutPrefix(stored, totpSealPrefix)
	if !ok {
		return stored, true, nil
	}
	aead, err := s.totpAEAD()
	if err != nil {
		return "", false, err
	}
	raw, err := base64.StdEncoding.DecodeString(body)
	if err != nil || len(raw) < aead.NonceSize() {
		return "", false, apperr.Internalf("identity: totp secret of %s is malformed", userID)
	}
	plain, err := aead.Open(nil, raw[:aead.NonceSize()], raw[aead.NonceSize():], userID[:])
	if err != nil {
		// Wrong TOTP_ENC_KEY or a tampered row. Never fall back to clear text.
		return "", false, apperr.Internalf("identity: open totp secret of %s: %w", userID, err)
	}
	return string(plain), false, nil
}

// sealLegacyTOTP replaces a plaintext secret with its sealed form, if the row
// still holds that plaintext.
func (s *Service) sealLegacyTOTP(ctx context.Context, q *store.Queries, userID uuid.UUID, plain string) error {
	sealed, err := s.sealTOTP(userID, plain)
	if err != nil {
		return err
	}
	if _, err := q.SealTOTPSecret(ctx, store.SealTOTPSecretParams{Sealed: &sealed, ID: userID, Plain: &plain}); err != nil {
		return apperr.Internalf("identity: seal totp secret: %w", err)
	}
	return nil
}

// SealLegacyTOTPSecrets seals every TOTP secret still stored in clear and
// returns how many it sealed. Idempotent; run by the maintenance job.
func (s *Service) SealLegacyTOTPSecrets(ctx context.Context) (int, error) {
	rows, err := s.q.ListLegacyTOTPSecrets(ctx)
	if err != nil {
		return 0, apperr.Internalf("identity: list legacy totp secrets: %w", err)
	}
	n := 0
	for _, r := range rows {
		if err := s.sealLegacyTOTP(ctx, s.q, r.ID, r.TotpSecret); err != nil {
			logx.From(ctx).ErrorContext(ctx, "identity: seal legacy totp secret", "user_id", r.ID, "err", err)
			continue
		}
		n++
	}
	return n, nil
}
