-- Identity review fixes:
--   * consent OTPs (FAR-04): otp_challenges gets a purpose and, for consent
--     codes, the FA who asked for it (only that FA can verify the code);
--   * temporary passwords expire (72 h after an admin sets one);
--   * indexes for the retention job (identity.maintenance);
--   * ho_users.totp_secret is now AES-256-GCM sealed with TOTP_ENC_KEY, as
--     "v1:<base64(nonce|ciphertext)>". SQL cannot encrypt, so existing
--     plaintext secrets stay as they are here and the identity code seals them:
--     at the user's next sign-in and in the maintenance job's sweep. Code reads
--     both forms; a value without the "v1:" prefix is legacy plaintext.

-- +goose Up
ALTER TABLE otp_challenges
  ADD COLUMN purpose text NOT NULL DEFAULT 'login' CHECK (purpose IN ('login', 'consent')),
  ADD COLUMN fa_id   uuid REFERENCES field_assistants (id);
DROP INDEX otp_challenges_phone_idx;
CREATE INDEX otp_challenges_phone_idx ON otp_challenges (phone, purpose, created_at DESC);
CREATE INDEX otp_challenges_created_idx ON otp_challenges (created_at);

ALTER TABLE field_assistants ADD COLUMN temp_password_expires_at timestamptz;
ALTER TABLE ho_users ADD COLUMN temp_password_expires_at timestamptz;
-- Temporary passwords issued before this migration get the full 72 h from now.
UPDATE field_assistants SET temp_password_expires_at = now() + interval '72 hours' WHERE must_change_password;
UPDATE ho_users SET temp_password_expires_at = now() + interval '72 hours' WHERE must_change_password;

CREATE INDEX sessions_expires_idx ON sessions (expires_at);
CREATE INDEX sessions_revoked_idx ON sessions (revoked_at) WHERE revoked_at IS NOT NULL;

COMMENT ON COLUMN ho_users.totp_secret IS
  'AES-256-GCM sealed with TOTP_ENC_KEY ("v1:" prefix); legacy plaintext is sealed by identity code';

-- +goose Down
COMMENT ON COLUMN ho_users.totp_secret IS NULL;
DROP INDEX sessions_revoked_idx;
DROP INDEX sessions_expires_idx;
ALTER TABLE ho_users DROP COLUMN temp_password_expires_at;
ALTER TABLE field_assistants DROP COLUMN temp_password_expires_at;
DROP INDEX otp_challenges_created_idx;
DROP INDEX otp_challenges_phone_idx;
DELETE FROM otp_challenges WHERE purpose <> 'login';
ALTER TABLE otp_challenges DROP COLUMN fa_id, DROP COLUMN purpose;
CREATE INDEX otp_challenges_phone_idx ON otp_challenges (phone, created_at DESC);
