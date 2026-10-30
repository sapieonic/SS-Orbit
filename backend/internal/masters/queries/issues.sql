-- name: CreateIssue :one
INSERT INTO issues (id, crop_id, type, name, name_te) VALUES ($1, $2, $3, $4, $5) RETURNING *;

-- name: GetIssue :one
SELECT * FROM issues WHERE id = $1;

-- name: GetIssueForUpdate :one
SELECT * FROM issues WHERE id = $1 FOR UPDATE;

-- name: UpdateIssue :one
UPDATE issues SET
  type    = COALESCE(sqlc.narg('type'), type),
  name    = COALESCE(sqlc.narg('name'), name),
  name_te = COALESCE(sqlc.narg('name_te'), name_te),
  active  = COALESCE(sqlc.narg('active'), active)
WHERE id = sqlc.arg('id')
RETURNING *;

-- name: ListIssues :many
SELECT * FROM issues
WHERE (sqlc.narg('crop_id')::uuid IS NULL OR crop_id = sqlc.narg('crop_id'))
  AND (sqlc.narg('type')::text IS NULL OR type = sqlc.narg('type'))
  AND (sqlc.narg('active')::boolean IS NULL OR active = sqlc.narg('active'))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) > (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at, id
LIMIT sqlc.arg('row_limit');

-- name: ListActiveIssues :many
-- Active issues of active crops.
SELECT i.* FROM issues i JOIN crops c ON c.id = i.crop_id
WHERE i.active AND c.active
ORDER BY i.crop_id, i.name, i.id;
