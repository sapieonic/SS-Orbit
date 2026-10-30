-- name: CreateSession :exec
INSERT INTO sessions (id, subject_kind, subject_id, device_id, family_id, refresh_token_hash,
                      expires_at, user_agent, ip, created_at)
VALUES (@id, @subject_kind, @subject_id, sqlc.narg('device_id'), @family_id, @refresh_token_hash,
        @expires_at, sqlc.narg('user_agent'), sqlc.narg('ip'), @created_at);

-- name: GetSessionByHashForUpdate :one
SELECT * FROM sessions WHERE refresh_token_hash = @refresh_token_hash FOR UPDATE;

-- name: GetSession :one
SELECT * FROM sessions WHERE id = @id;

-- name: MarkSessionRotated :exec
UPDATE sessions SET rotated_at = @rotated_at WHERE id = @id;

-- name: RevokeSessionFamily :many
-- Returns the revoked session IDs so their cached guard answers can be dropped.
UPDATE sessions SET revoked_at = @revoked_at
WHERE family_id = @family_id AND revoked_at IS NULL
RETURNING id;

-- name: RevokeSubjectSessions :many
-- Every live session of a subject, optionally keeping one family (the caller's own).
UPDATE sessions SET revoked_at = @revoked_at
WHERE subject_kind = @subject_kind AND subject_id = @subject_id AND revoked_at IS NULL
  AND (sqlc.narg('keep_family_id')::uuid IS NULL OR family_id <> sqlc.narg('keep_family_id'))
RETURNING id;

-- name: RevokeDeviceSessions :execrows
UPDATE sessions SET revoked_at = @revoked_at
WHERE device_id = @device_id AND revoked_at IS NULL;

-- name: HOAccessAllowed :one
-- Surface guard check for an HO access token: the session it was minted from
-- is not revoked and the user is not disabled. A session or user that does
-- not exist (dev tokens; rows purged long after the token expired) does not
-- block.
SELECT
  COALESCE((SELECT s.revoked_at IS NULL FROM sessions s
            WHERE s.id = @session_id AND s.subject_kind = 'ho' AND s.subject_id = @user_id), true)::bool AS session_live,
  COALESCE((SELECT u.status <> 'disabled' FROM ho_users u WHERE u.id = @user_id), true)::bool AS user_enabled;

-- name: PurgeSessions :execrows
-- Retention (maintenance job): sessions that expired or were revoked before
-- @before. Live rotated rows stay until they expire, so reuse detection keeps
-- working for every token that could still be presented.
DELETE FROM sessions WHERE expires_at < @before OR revoked_at < @before;
