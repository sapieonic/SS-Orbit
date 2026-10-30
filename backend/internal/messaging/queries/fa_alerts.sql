-- name: InsertFAAlert :one
-- Returns no rows when the FA already has an alert of this kind for ref_id.
INSERT INTO fa_alerts (id, fa_id, kind, farmer_id, ref_id, title, body, title_te, body_te, created_by)
VALUES (@id, @fa_id, @kind, sqlc.narg('farmer_id'), sqlc.narg('ref_id'), @title, sqlc.narg('body'),
        sqlc.narg('title_te'), sqlc.narg('body_te'), sqlc.narg('created_by'))
ON CONFLICT (fa_id, kind, ref_id) WHERE ref_id IS NOT NULL DO NOTHING
RETURNING *;

-- name: GetFAAlert :one
SELECT * FROM fa_alerts WHERE id = @id;

-- name: AckFAAlert :one
-- Returns no rows if the alert is not the FA's or is no longer open.
UPDATE fa_alerts SET status = 'acknowledged', acknowledged_at = @at
WHERE id = @id AND fa_id = @fa_id AND status = 'open'
RETURNING *;

-- name: ListFAAlerts :many
-- The FA's alerts, newest first, keyset on (created_at, id).
SELECT *
FROM fa_alerts
WHERE fa_id = @fa_id
  AND (sqlc.narg('status')::text IS NULL OR status = sqlc.narg('status'))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg('row_limit');

-- name: ListSnapshotFAAlerts :many
-- Alerts the FA app keeps offline: not closed and recent, newest first.
SELECT *
FROM fa_alerts
WHERE fa_id = @fa_id AND status <> 'closed' AND created_at >= @since
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg('row_limit');
