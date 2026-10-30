-- name: ListDistricts :many
SELECT * FROM districts ORDER BY name;

-- name: GetDistrict :one
SELECT * FROM districts WHERE id = $1;

-- name: FindDistrictByName :one
SELECT * FROM districts WHERE lower(name) = lower(@name::text);

-- name: InsertDistrict :one
INSERT INTO districts (id, lgd_code, name, name_te, state)
VALUES (@id, sqlc.narg('lgd_code'), @name, sqlc.narg('name_te'), COALESCE(sqlc.narg('state')::text, 'Telangana'))
RETURNING *;

-- name: UpdateDistrict :one
-- NULL arguments leave the column unchanged.
UPDATE districts
SET name     = COALESCE(sqlc.narg('name')::text, name),
    name_te  = COALESCE(sqlc.narg('name_te')::text, name_te),
    lgd_code = COALESCE(sqlc.narg('lgd_code')::text, lgd_code),
    state    = COALESCE(sqlc.narg('state')::text, state)
WHERE id = @id
RETURNING *;
