-- name: ListMandals :many
-- Optional district filter; district_scope (empty = all) is the HO area scope.
SELECT m.*, d.name AS district_name, d.name_te AS district_name_te
FROM mandals m
JOIN districts d ON d.id = m.district_id
WHERE (sqlc.narg('district_id')::uuid IS NULL OR m.district_id = sqlc.narg('district_id'))
  AND (cardinality(@district_scope::uuid[]) = 0 OR m.district_id = ANY(@district_scope::uuid[]))
ORDER BY d.name, m.name;

-- name: GetMandal :one
SELECT m.*, d.name AS district_name, d.name_te AS district_name_te
FROM mandals m
JOIN districts d ON d.id = m.district_id
WHERE m.id = $1;

-- name: FindMandalByName :one
SELECT * FROM mandals WHERE district_id = @district_id AND lower(name) = lower(@name::text);

-- name: InsertMandal :one
INSERT INTO mandals (id, district_id, lgd_code, name, name_te)
VALUES (@id, @district_id, sqlc.narg('lgd_code'), @name, sqlc.narg('name_te'))
RETURNING *;

-- name: UpdateMandal :execrows
UPDATE mandals
SET name     = COALESCE(sqlc.narg('name')::text, name),
    name_te  = COALESCE(sqlc.narg('name_te')::text, name_te),
    lgd_code = COALESCE(sqlc.narg('lgd_code')::text, lgd_code)
WHERE id = @id;

-- name: ListMandalVillageCounts :many
-- Every mandal with its village count, for the cached tree.
SELECT m.id, m.district_id, m.name, m.name_te, m.lgd_code,
       (SELECT count(*) FROM villages v WHERE v.mandal_id = m.id)::int AS village_count
FROM mandals m
ORDER BY m.name;
