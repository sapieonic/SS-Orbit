-- name: CreateHOUser :one
INSERT INTO ho_users (id, email, name, password_hash, role, district_ids, status, must_change_password,
                      temp_password_expires_at)
VALUES (@id, @email, @name, @password_hash, @role, @district_ids, 'invited', true, @temp_password_expires_at)
RETURNING *;

-- name: GetHOUser :one
SELECT * FROM ho_users WHERE id = @id;

-- name: GetHOUserForUpdate :one
SELECT * FROM ho_users WHERE id = @id FOR UPDATE;

-- name: GetHOUserByEmail :one
SELECT * FROM ho_users WHERE email = @email::text;

-- name: ListHOUsers :many
-- Newest first, keyset on (created_at, id). q matches name or email.
SELECT *
FROM ho_users
WHERE (sqlc.narg('status')::text IS NULL OR status = sqlc.narg('status'))
  AND (sqlc.narg('role')::text IS NULL OR role = sqlc.narg('role'))
  AND (sqlc.narg('q')::text IS NULL
       OR name ILIKE '%' || sqlc.narg('q') || '%'
       OR email::text ILIKE '%' || sqlc.narg('q') || '%')
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at DESC, id DESC
LIMIT @row_limit;

-- name: ListHOUserDirectory :many
-- Every HO user's display fields, for resolving IDs to names.
SELECT id, name, role, status
FROM ho_users
ORDER BY lower(name), id;

-- name: UpdateHOUser :one
UPDATE ho_users SET name = @name, role = @role, district_ids = @district_ids
WHERE id = @id
RETURNING *;

-- name: SetHOUserStatus :one
UPDATE ho_users SET status = @status WHERE id = @id RETURNING *;

-- name: SetHOUserPassword :exec
UPDATE ho_users SET password_hash = @password_hash, must_change_password = @must_change_password,
  temp_password_expires_at = sqlc.narg('temp_password_expires_at')
WHERE id = @id;

-- name: SetHOUserTOTP :exec
-- totp_secret is the sealed form ("v1:...", see identity/totp_seal.go).
UPDATE ho_users SET totp_secret = sqlc.narg('totp_secret'), totp_enabled = @totp_enabled WHERE id = @id;

-- name: ListLegacyTOTPSecrets :many
-- Secrets still stored in clear (written before migration 00016).
SELECT id, totp_secret::text AS totp_secret FROM ho_users
WHERE totp_secret IS NOT NULL AND NOT starts_with(totp_secret, 'v1:')
LIMIT 500;

-- name: SealTOTPSecret :execrows
-- Replaces a plaintext secret with its sealed form, only if it is unchanged.
UPDATE ho_users SET totp_secret = @sealed WHERE id = @id AND totp_secret = @plain;

-- name: TouchHOUserLogin :exec
-- First successful sign-in turns an invited user active.
UPDATE ho_users SET last_login_at = @at,
  status = CASE WHEN status = 'invited' THEN 'active' ELSE status END
WHERE id = @id;

-- name: CountOtherActiveAdmins :one
-- Admins who can actually sign in (active, TOTP set up), other than @id.
SELECT count(*)::int AS n FROM ho_users
WHERE role = 'admin' AND status = 'active' AND totp_enabled AND id <> @id;
