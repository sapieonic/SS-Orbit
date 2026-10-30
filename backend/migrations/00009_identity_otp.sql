-- Identity: farmer sign-in OTP challenges, plus a forced-password-change flag
-- for HO users (they get a temporary password from an admin, like FAs).
--
-- OTPs live in Postgres, not only Redis, so farmers can still sign in when
-- Redis is down (CONVENTIONS section 13). Codes are stored as an HMAC keyed
-- with a server secret, never in clear.

-- +goose Up
CREATE TABLE otp_challenges (
  id           uuid PRIMARY KEY,
  phone        text NOT NULL,              -- E.164
  code_hash    bytea NOT NULL,             -- HMAC-SHA256(server secret, id || code)
  attempts     integer NOT NULL DEFAULT 0, -- wrong codes entered so far
  max_attempts integer NOT NULL,
  expires_at   timestamptz NOT NULL,
  consumed_at  timestamptz,                -- set once the code is verified (single use)
  ip           inet,                       -- requester, for abuse review
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX otp_challenges_phone_idx ON otp_challenges (phone, created_at DESC);

ALTER TABLE ho_users ADD COLUMN must_change_password boolean NOT NULL DEFAULT false;

-- +goose Down
ALTER TABLE ho_users DROP COLUMN must_change_password;
DROP TABLE otp_challenges;
