-- name: CreateSku :one
INSERT INTO skus (id, code, product_name, product_name_te, salt_id, pack_size, mrp_paise, cashback_eligible)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: GetSku :one
SELECT * FROM skus WHERE id = $1;

-- name: GetSkuForUpdate :one
SELECT * FROM skus WHERE id = $1 FOR UPDATE;

-- name: UpdateSku :one
UPDATE skus SET
  product_name      = COALESCE(sqlc.narg('product_name'), product_name),
  product_name_te   = COALESCE(sqlc.narg('product_name_te'), product_name_te),
  salt_id           = COALESCE(sqlc.narg('salt_id'), salt_id),
  pack_size         = COALESCE(sqlc.narg('pack_size'), pack_size),
  mrp_paise         = COALESCE(sqlc.narg('mrp_paise'), mrp_paise),
  cashback_eligible = COALESCE(sqlc.narg('cashback_eligible'), cashback_eligible),
  active            = COALESCE(sqlc.narg('active'), active)
WHERE id = sqlc.arg('id')
RETURNING *;

-- name: ListSkus :many
SELECT * FROM skus
WHERE (sqlc.narg('salt_id')::uuid IS NULL OR salt_id = sqlc.narg('salt_id'))
  AND (sqlc.narg('active')::boolean IS NULL OR active = sqlc.narg('active'))
  AND (sqlc.narg('q')::text IS NULL OR product_name ILIKE '%' || sqlc.narg('q') || '%'
       OR code ILIKE '%' || sqlc.narg('q') || '%')
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) > (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at, id
LIMIT sqlc.arg('row_limit');

-- name: ListActiveSkus :many
SELECT * FROM skus WHERE active ORDER BY product_name, id;

-- name: CountActiveSkus :one
SELECT count(*) FROM skus WHERE id = ANY(sqlc.arg('ids')::uuid[]) AND active;
