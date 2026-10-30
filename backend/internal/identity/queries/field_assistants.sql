-- name: CreateFieldAssistant :one
INSERT INTO field_assistants (id, code, name, name_te, phone, password_hash, must_change_password,
                              temp_password_expires_at, level, languages, working_hours, photo_key, created_by)
VALUES (@id, @code, @name, sqlc.narg('name_te'), @phone, @password_hash, true,
        @temp_password_expires_at, @level, @languages, sqlc.narg('working_hours'), sqlc.narg('photo_key'),
        sqlc.narg('created_by'))
RETURNING *;

-- name: GetFieldAssistant :one
SELECT * FROM field_assistants WHERE id = @id;

-- name: GetFieldAssistantForUpdate :one
SELECT * FROM field_assistants WHERE id = @id FOR UPDATE;

-- name: GetFieldAssistantByCode :one
SELECT * FROM field_assistants WHERE code = @code;

-- name: GetFieldAssistantsByIDs :many
SELECT * FROM field_assistants WHERE id = ANY(@ids::uuid[]) ORDER BY code;

-- name: ListFieldAssistants :many
-- HO list, newest first, keyset on (created_at, id). q matches name, code or phone.
SELECT fa.*,
       -- '' when the FA has no live device with a known app version.
       COALESCE((SELECT d.app_version FROM devices d
                 WHERE d.subject_kind = 'fa' AND d.subject_id = fa.id AND d.revoked_at IS NULL
                 ORDER BY d.last_seen_at DESC NULLS LAST LIMIT 1), '')::text AS app_version
FROM field_assistants fa
WHERE (sqlc.narg('status')::text IS NULL OR fa.status = sqlc.narg('status'))
  -- HO area scope: NULL = every FA, otherwise only these.
  AND (sqlc.narg('ids')::uuid[] IS NULL OR fa.id = ANY(sqlc.narg('ids')::uuid[]))
  AND (sqlc.narg('q')::text IS NULL
       OR fa.name ILIKE '%' || sqlc.narg('q') || '%'
       OR fa.name_te ILIKE '%' || sqlc.narg('q') || '%'
       OR fa.code ILIKE '%' || sqlc.narg('q') || '%'
       OR fa.phone LIKE '%' || sqlc.narg('q') || '%')
  -- Not synced since: last sync before this time, or never.
  AND (sqlc.narg('not_synced_since')::timestamptz IS NULL
       OR fa.last_sync_at IS NULL OR fa.last_sync_at < sqlc.narg('not_synced_since'))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (fa.created_at, fa.id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY fa.created_at DESC, fa.id DESC
LIMIT @row_limit;

-- name: MaxFACodeSeq :one
-- Highest numeric suffix among codes "<prefix><digits>" (prefix like "FA-KDP-").
SELECT COALESCE(max(substring(code FROM length(@prefix::text) + 1)::int), 0)::int AS seq
FROM field_assistants
WHERE starts_with(code, @prefix::text) AND substring(code FROM length(@prefix::text) + 1) ~ '^[0-9]{1,6}$';

-- name: UpdateFieldAssistantProfile :one
UPDATE field_assistants SET
  name = @name, name_te = sqlc.narg('name_te'), phone = @phone, level = @level,
  languages = @languages, working_hours = sqlc.narg('working_hours'), photo_key = sqlc.narg('photo_key')
WHERE id = @id
RETURNING *;

-- name: SetFieldAssistantStatus :one
UPDATE field_assistants SET status = @status WHERE id = @id RETURNING *;

-- name: SetFieldAssistantPassword :exec
-- A temporary password (must_change_password) expires at temp_password_expires_at.
UPDATE field_assistants SET password_hash = @password_hash, must_change_password = @must_change_password,
  temp_password_expires_at = sqlc.narg('temp_password_expires_at')
WHERE id = @id;

-- name: TouchFieldAssistantLogin :exec
UPDATE field_assistants SET last_login_at = @at WHERE id = @id;

-- name: MarkFieldAssistantSynced :execrows
UPDATE field_assistants SET last_sync_at = @synced_at WHERE id = @id;

-- name: ListFieldAssistantIDs :many
-- Every FA ID (a few hundred at most), for working out an HO user's area scope.
SELECT id FROM field_assistants ORDER BY id;

-- name: FieldAssistantStats :one
-- ADM-01 overview counts. ids NULL = every FA (unscoped HO user).
SELECT
  count(*) FILTER (WHERE status = 'active')::int   AS active,
  count(*) FILTER (WHERE status = 'leaving')::int  AS leaving,
  count(*) FILTER (WHERE status = 'inactive')::int AS inactive,
  count(*) FILTER (WHERE last_sync_at >= @synced_since)::int AS synced_recently
FROM field_assistants
WHERE sqlc.narg('ids')::uuid[] IS NULL OR id = ANY(sqlc.narg('ids')::uuid[]);

-- name: FieldAssistantsNotSyncedSince :many
-- Active FAs whose last sync is before @since, or who never synced and were
-- created before it (messaging's fa_offline HO alert).
SELECT * FROM field_assistants
WHERE status = 'active'
  AND (last_sync_at < @since OR (last_sync_at IS NULL AND created_at < @since))
ORDER BY code;
