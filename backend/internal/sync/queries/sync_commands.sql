-- name: GetSyncCommandsByIDs :many
-- Stored commands among ids (any FA): the idempotency lookup for a batch.
SELECT *
FROM sync_commands
WHERE id = ANY(sqlc.arg('ids')::uuid[]);

-- name: GetSyncCommand :one
SELECT *
FROM sync_commands
WHERE id = $1;

-- name: InsertSyncCommand :one
-- First writer wins: a concurrent duplicate gets no row (pgx.ErrNoRows) and
-- reads the stored one with GetSyncCommand.
INSERT INTO sync_commands (id, fa_id, device_id, type, payload, status, result, client_created_at, received_at)
VALUES (sqlc.arg('id'), sqlc.arg('fa_id'), sqlc.narg('device_id'), sqlc.arg('type'), sqlc.arg('payload'),
        sqlc.arg('status'), sqlc.arg('result'), sqlc.narg('client_created_at'), sqlc.arg('received_at'))
ON CONFLICT (id) DO NOTHING
RETURNING *;

-- name: ListSyncCommands :many
-- Newest first, keyset on (received_at, id). Every filter is optional (NULL = no filter).
-- failed_attempts/last_error show commands that needed server retries
-- (including dead-lettered ones, stored as rejected with server_could_not_apply).
SELECT sqlc.embed(c),
       f.attempts AS failed_attempts,
       f.last_error
FROM sync_commands c
LEFT JOIN sync_command_failures f ON f.id = c.id
WHERE (sqlc.narg('fa_id')::uuid IS NULL OR c.fa_id = sqlc.narg('fa_id'))
  AND (sqlc.narg('status')::text IS NULL OR c.status = sqlc.narg('status'))
  AND (sqlc.narg('type')::text IS NULL OR c.type = sqlc.narg('type'))
  AND (sqlc.narg('from_time')::timestamptz IS NULL OR c.received_at >= sqlc.narg('from_time'))
  AND (sqlc.narg('to_time')::timestamptz IS NULL OR c.received_at < sqlc.narg('to_time'))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (c.received_at, c.id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY c.received_at DESC, c.id DESC
LIMIT sqlc.arg('row_limit');

-- name: RecordSyncCommandFailure :one
-- Counts one infrastructure failure of a command not yet stored; returns the
-- attempt count so far.
INSERT INTO sync_command_failures (id, fa_id, type, attempts, last_error, first_at, last_at)
VALUES (sqlc.arg('id'), sqlc.arg('fa_id'), sqlc.arg('type'), 1, sqlc.arg('last_error'), sqlc.arg('at'), sqlc.arg('at'))
ON CONFLICT (id) DO UPDATE
  SET attempts = sync_command_failures.attempts + 1,
      last_error = EXCLUDED.last_error,
      last_at = EXCLUDED.last_at
RETURNING attempts;

-- name: DeleteOldSyncCommands :execrows
-- Retention: applied/merged commands older than routine_before, conflicts and
-- rejections (kept for HO review) older than review_before.
DELETE FROM sync_commands
WHERE (status IN ('applied', 'merged') AND received_at < sqlc.arg('routine_before'))
   OR (status IN ('conflict', 'rejected') AND received_at < sqlc.arg('review_before'));

-- name: DeleteOldSyncCommandFailures :execrows
DELETE FROM sync_command_failures
WHERE last_at < sqlc.arg('before');
