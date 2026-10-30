-- name: GetVillageDetail :one
SELECT * FROM village_details WHERE id = $1;

-- name: GetVillageDetails :many
SELECT * FROM village_details WHERE id = ANY(@ids::uuid[]) ORDER BY name, id;

-- name: ListVillages :many
-- Oldest first, keyset on (created_at, id). Filters optional; district_scope
-- (empty = all) is the HO area scope.
SELECT * FROM village_details
WHERE (sqlc.narg('mandal_id')::uuid IS NULL OR mandal_id = sqlc.narg('mandal_id'))
  AND (sqlc.narg('district_id')::uuid IS NULL OR district_id = sqlc.narg('district_id'))
  AND (cardinality(@district_scope::uuid[]) = 0 OR district_id = ANY(@district_scope::uuid[]))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) > (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at, id
LIMIT sqlc.arg('row_limit');

-- name: SearchVillages :many
-- The village picker. An empty q lists by name. Otherwise matches a substring
-- (pattern = '%q%', LIKE-escaped) or a trigram match on name or name_te;
-- prefix matches rank first, then similarity.
SELECT * FROM village_details
WHERE (sqlc.narg('mandal_id')::uuid IS NULL OR mandal_id = sqlc.narg('mandal_id'))
  AND (sqlc.narg('district_id')::uuid IS NULL OR district_id = sqlc.narg('district_id'))
  AND (cardinality(@district_scope::uuid[]) = 0 OR district_id = ANY(@district_scope::uuid[]))
  AND (@q::text = ''
       OR name ILIKE @pattern::text OR name_te ILIKE @pattern::text
       OR name % @q::text OR name_te % @q::text)
ORDER BY (name ILIKE @prefix::text OR COALESCE(name_te ILIKE @prefix::text, false)) DESC,
         greatest(similarity(name, @q::text), similarity(COALESCE(name_te, ''), @q::text)) DESC,
         name, id
LIMIT sqlc.arg('row_limit');

-- name: InsertVillage :exec
INSERT INTO villages (id, mandal_id, lgd_code, name, name_te, centroid)
VALUES (@id, @mandal_id, sqlc.narg('lgd_code'), @name, sqlc.narg('name_te'),
        CASE WHEN sqlc.narg('lng')::float8 IS NULL OR sqlc.narg('lat')::float8 IS NULL THEN NULL
             ELSE ST_SetSRID(ST_MakePoint(sqlc.narg('lng')::float8, sqlc.narg('lat')::float8), 4326)::geography END);

-- name: UpdateVillage :execrows
-- NULL arguments leave the column unchanged; lat and lng change together.
UPDATE villages
SET name     = COALESCE(sqlc.narg('name')::text, name),
    name_te  = COALESCE(sqlc.narg('name_te')::text, name_te),
    lgd_code = COALESCE(sqlc.narg('lgd_code')::text, lgd_code),
    centroid = CASE WHEN sqlc.narg('lng')::float8 IS NULL OR sqlc.narg('lat')::float8 IS NULL THEN centroid
                    ELSE ST_SetSRID(ST_MakePoint(sqlc.narg('lng')::float8, sqlc.narg('lat')::float8), 4326)::geography END
WHERE id = @id;

-- name: UpsertVillage :one
-- CSV import, idempotent on (mandal_id, name). An existing village takes the
-- non-NULL values of the row. Returns no row when nothing changed; the
-- returned id differs from @id when an existing village was updated.
INSERT INTO villages AS cur (id, mandal_id, lgd_code, name, name_te, centroid)
VALUES (@id, @mandal_id, sqlc.narg('lgd_code'), @name, sqlc.narg('name_te'),
        CASE WHEN sqlc.narg('lng')::float8 IS NULL OR sqlc.narg('lat')::float8 IS NULL THEN NULL
             ELSE ST_SetSRID(ST_MakePoint(sqlc.narg('lng')::float8, sqlc.narg('lat')::float8), 4326)::geography END)
ON CONFLICT (mandal_id, name) DO UPDATE
SET lgd_code = COALESCE(EXCLUDED.lgd_code, cur.lgd_code),
    name_te  = COALESCE(EXCLUDED.name_te, cur.name_te),
    centroid = COALESCE(EXCLUDED.centroid, cur.centroid)
WHERE (EXCLUDED.lgd_code IS NOT NULL AND EXCLUDED.lgd_code IS DISTINCT FROM cur.lgd_code)
   OR (EXCLUDED.name_te IS NOT NULL AND EXCLUDED.name_te IS DISTINCT FROM cur.name_te)
   OR (EXCLUDED.centroid IS NOT NULL AND ST_AsBinary(EXCLUDED.centroid) IS DISTINCT FROM ST_AsBinary(cur.centroid))
RETURNING cur.id;

-- name: FindVillageName :one
-- The stored spelling of a village name in a mandal, matched ignoring case.
SELECT name FROM villages
WHERE mandal_id = @mandal_id AND lower(name) = lower(@name::text)
ORDER BY name
LIMIT 1;
