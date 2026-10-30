-- name: CreateSalt :one
INSERT INTO salts (id, name, name_te) VALUES ($1, $2, $3) RETURNING *;

-- name: GetSalt :one
SELECT * FROM salts WHERE id = $1;

-- name: GetSaltForUpdate :one
SELECT * FROM salts WHERE id = $1 FOR UPDATE;

-- name: UpdateSalt :one
UPDATE salts SET
  name    = COALESCE(sqlc.narg('name'), name),
  name_te = COALESCE(sqlc.narg('name_te'), name_te),
  active  = COALESCE(sqlc.narg('active'), active)
WHERE id = sqlc.arg('id')
RETURNING *;

-- name: ListSalts :many
SELECT * FROM salts
WHERE (sqlc.narg('active')::boolean IS NULL OR active = sqlc.narg('active'))
  AND (sqlc.narg('q')::text IS NULL OR name ILIKE '%' || sqlc.narg('q') || '%')
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) > (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at, id
LIMIT sqlc.arg('row_limit');

-- name: ListActiveSalts :many
SELECT * FROM salts WHERE active ORDER BY name, id;

-- name: ActiveSkuIDsForSalt :many
SELECT id FROM skus WHERE salt_id = $1 AND active;
