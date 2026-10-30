-- "Ask your FA to call you back" requests.

-- name: GetOpenCallbackForFarmer :one
SELECT * FROM callback_requests WHERE farmer_id = $1 AND status = 'open';

-- name: InsertCallback :one
INSERT INTO callback_requests (id, farmer_id, fa_id, status, requested_at)
VALUES (sqlc.arg('id'), sqlc.arg('farmer_id'), sqlc.arg('fa_id'), 'open', sqlc.arg('requested_at'))
RETURNING *;

-- name: LockCallback :one
SELECT * FROM callback_requests WHERE id = $1 FOR UPDATE;

-- name: FinishCallback :one
-- Close (FA called or visited) or cancel (farmer withdrew) an open request.
UPDATE callback_requests
SET status    = sqlc.arg('status'),
    closed_at = sqlc.arg('closed_at'),
    closed_by = sqlc.arg('closed_by'),
    note      = COALESCE(sqlc.narg('note'), note)
WHERE id = sqlc.arg('id')
RETURNING *;

-- name: CloseOpenCallbacksForFarmer :many
-- A logged visit answers any open call-back request of that farmer.
UPDATE callback_requests
SET status    = 'closed',
    closed_at = sqlc.arg('closed_at'),
    closed_by = sqlc.arg('closed_by'),
    note      = COALESCE(note, sqlc.arg('note'))
WHERE farmer_id = sqlc.arg('farmer_id')
  AND status = 'open'
RETURNING *;

-- name: ListOpenCallbacksForFA :many
SELECT * FROM callback_requests WHERE fa_id = $1 AND status = 'open' ORDER BY requested_at, id;

-- name: ReassignOpenCallbacks :many
UPDATE callback_requests c
SET fa_id = sqlc.arg('to_fa_id')
FROM (SELECT id, fa_id
      FROM callback_requests
      WHERE status = 'open'
        AND farmer_id = ANY (sqlc.arg('farmer_ids')::uuid[])
        AND fa_id <> sqlc.arg('to_fa_id')
      FOR UPDATE) prev
WHERE c.id = prev.id
RETURNING c.id, c.farmer_id, prev.fa_id AS from_fa_id;
