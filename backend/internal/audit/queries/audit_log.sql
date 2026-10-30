-- name: ListAuditEvents :many
-- Newest first, keyset on (occurred_at, id). Every filter is optional (NULL = no filter).
SELECT *
FROM audit_log
WHERE (sqlc.narg('entity_type')::text IS NULL OR entity_type = sqlc.narg('entity_type'))
  AND (sqlc.narg('entity_id')::uuid IS NULL OR entity_id = sqlc.narg('entity_id'))
  AND (sqlc.narg('actor_id')::uuid IS NULL OR actor_id = sqlc.narg('actor_id'))
  AND (sqlc.narg('farmer_id')::uuid IS NULL OR farmer_id = sqlc.narg('farmer_id'))
  AND (sqlc.narg('action_prefix')::text IS NULL OR starts_with(action, sqlc.narg('action_prefix')))
  AND (sqlc.narg('from_time')::timestamptz IS NULL OR occurred_at >= sqlc.narg('from_time'))
  AND (sqlc.narg('to_time')::timestamptz IS NULL OR occurred_at < sqlc.narg('to_time'))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (occurred_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY occurred_at DESC, id DESC
LIMIT sqlc.arg('row_limit');

-- name: ListEntityChain :many
-- Every event for one record, oldest first, keyset on (occurred_at, id).
SELECT *
FROM audit_log
WHERE entity_type = sqlc.arg('entity_type')
  AND entity_id = sqlc.arg('entity_id')
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (occurred_at, id) > (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY occurred_at ASC, id ASC
LIMIT sqlc.arg('row_limit');
