-- name: UpsertDevice :one
-- Registers a device on login, or refreshes its details. Nil details keep the
-- stored value. Revocation is never cleared here: a revoked device stays revoked
-- and the app must wipe itself and register with a new install ID.
INSERT INTO devices (id, subject_kind, subject_id, device_key, model, os_version, app_version,
                     push_token, last_seen_at)
VALUES (@id, @subject_kind, @subject_id, @device_key, sqlc.narg('model'), sqlc.narg('os_version'),
        sqlc.narg('app_version'), sqlc.narg('push_token'), @seen_at)
ON CONFLICT (subject_kind, subject_id, device_key) DO UPDATE SET
  model        = COALESCE(EXCLUDED.model, devices.model),
  os_version   = COALESCE(EXCLUDED.os_version, devices.os_version),
  app_version  = COALESCE(EXCLUDED.app_version, devices.app_version),
  push_token   = COALESCE(EXCLUDED.push_token, devices.push_token),
  last_seen_at = EXCLUDED.last_seen_at
RETURNING *;

-- name: GetDevice :one
SELECT * FROM devices WHERE id = @id;

-- name: GetDeviceForUpdate :one
SELECT * FROM devices WHERE id = @id FOR UPDATE;

-- name: TouchDevice :one
-- Heartbeat from the app. Nil details keep the stored value.
UPDATE devices SET
  model        = COALESCE(sqlc.narg('model'), model),
  os_version   = COALESCE(sqlc.narg('os_version'), os_version),
  app_version  = COALESCE(sqlc.narg('app_version'), app_version),
  push_token   = COALESCE(sqlc.narg('push_token'), push_token),
  last_seen_at = @seen_at
WHERE id = @id
RETURNING *;

-- name: ClearPushTokenElsewhere :exec
-- A push token belongs to one app install. When it shows up on another
-- subject's device (shared phone, new sign-in), drop it from the old rows so
-- one farmer's notifications never reach another.
UPDATE devices SET push_token = NULL WHERE push_token = @push_token AND id <> @keep_id;

-- name: RevokeDevice :one
UPDATE devices SET revoked_at = @revoked_at, revoke_reason = @revoke_reason, push_token = NULL
WHERE id = @id AND revoked_at IS NULL
RETURNING *;

-- name: RevokeSubjectDevices :many
UPDATE devices SET revoked_at = @revoked_at, revoke_reason = @revoke_reason, push_token = NULL
WHERE subject_kind = @subject_kind AND subject_id = @subject_id AND revoked_at IS NULL
RETURNING id;

-- name: ListSubjectDevices :many
-- Newest first, keyset on (created_at, id).
SELECT *
FROM devices
WHERE subject_kind = @subject_kind AND subject_id = @subject_id
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at DESC, id DESC
LIMIT @row_limit;

-- name: IsDeviceRevoked :one
SELECT (revoked_at IS NOT NULL)::bool AS revoked FROM devices WHERE id = @id;

-- name: ListPushTokens :many
SELECT subject_id, push_token::text AS push_token
FROM devices
WHERE subject_kind = @subject_kind AND subject_id = ANY(@subject_ids::uuid[])
  AND revoked_at IS NULL AND push_token IS NOT NULL AND push_token <> ''
ORDER BY subject_id, last_seen_at DESC NULLS LAST;

-- name: MarkDeviceSynced :exec
UPDATE devices SET last_sync_at = @synced_at, last_seen_at = @synced_at
WHERE id = @id AND subject_kind = 'fa' AND subject_id = @fa_id;
