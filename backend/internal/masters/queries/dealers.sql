-- name: CreateDealer :one
INSERT INTO dealers (id, name, name_te, phone, village_id, location, status, source)
VALUES (sqlc.arg('id'), sqlc.arg('name'), sqlc.narg('name_te'), sqlc.narg('phone'), sqlc.narg('village_id'),
        CASE WHEN sqlc.narg('lat')::float8 IS NULL THEN NULL
             ELSE ST_SetSRID(ST_MakePoint(sqlc.narg('lng')::float8, sqlc.narg('lat')::float8), 4326)::geography END,
        sqlc.arg('status'), sqlc.arg('source'))
RETURNING id;

-- name: LockDealer :one
SELECT id FROM dealers WHERE id = $1 FOR UPDATE;

-- name: UpdateDealer :exec
UPDATE dealers SET
  name       = COALESCE(sqlc.narg('name'), name),
  name_te    = COALESCE(sqlc.narg('name_te'), name_te),
  phone      = COALESCE(sqlc.narg('phone'), phone),
  village_id = COALESCE(sqlc.narg('village_id'), village_id),
  location   = CASE WHEN sqlc.narg('lat')::float8 IS NULL THEN location
                    ELSE ST_SetSRID(ST_MakePoint(sqlc.narg('lng')::float8, sqlc.narg('lat')::float8), 4326)::geography END,
  status     = COALESCE(sqlc.narg('status'), status)
WHERE id = sqlc.arg('id');

-- name: ListDealers :many
-- has_location tells whether lat/lng are set (sqlc cannot infer nullability through PostGIS casts).
-- Oldest first, keyset on (created_at, id); also used to read one dealer (dealer_id).
SELECT d.id, d.name, d.name_te, d.phone, d.village_id, d.status, d.source, d.created_at, d.updated_at,
       (d.location IS NOT NULL)::boolean AS has_location,
       COALESCE(ST_Y(d.location::geometry), 0)::float8 AS lat,
       COALESCE(ST_X(d.location::geometry), 0)::float8 AS lng
FROM dealers d
WHERE (sqlc.narg('dealer_id')::uuid IS NULL OR d.id = sqlc.narg('dealer_id'))
  AND (sqlc.narg('status')::text IS NULL OR d.status = sqlc.narg('status'))
  AND (sqlc.narg('village_id')::uuid IS NULL OR d.village_id = sqlc.narg('village_id'))
  AND (sqlc.narg('q')::text IS NULL OR d.name ILIKE '%' || sqlc.narg('q') || '%')
  AND (sqlc.narg('sku_id')::uuid IS NULL
       OR EXISTS (SELECT 1 FROM dealer_skus ds WHERE ds.dealer_id = d.id AND ds.sku_id = sqlc.narg('sku_id')))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (d.created_at, d.id) > (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY d.created_at, d.id
LIMIT sqlc.arg('row_limit');

-- name: ListDealerSkus :many
SELECT dealer_id, sku_id FROM dealer_skus
WHERE dealer_id = ANY(sqlc.arg('dealer_ids')::uuid[])
ORDER BY dealer_id, sku_id;

-- name: DeleteDealerSkus :exec
DELETE FROM dealer_skus WHERE dealer_id = $1;

-- name: AddDealerSkus :exec
INSERT INTO dealer_skus (dealer_id, sku_id)
SELECT sqlc.arg('dealer_id'), unnest(sqlc.arg('sku_ids')::uuid[])
ON CONFLICT DO NOTHING;

-- name: NearbyDealers :many
-- Active dealers with a pinned location within radius_m of the point, nearest first.
SELECT d.id, d.name, d.name_te, d.phone, d.village_id,
       ST_Y(d.location::geometry)::float8 AS lat,
       ST_X(d.location::geometry)::float8 AS lng,
       ST_Distance(d.location, p.pt)::float8 AS distance_m
FROM dealers d,
     (SELECT ST_SetSRID(ST_MakePoint(sqlc.arg('lng')::float8, sqlc.arg('lat')::float8), 4326)::geography AS pt) p
WHERE d.status = 'active'
  AND d.location IS NOT NULL
  AND ST_DWithin(d.location, p.pt, sqlc.arg('radius_m')::float8)
  AND (sqlc.narg('sku_id')::uuid IS NULL
       OR EXISTS (SELECT 1 FROM dealer_skus ds WHERE ds.dealer_id = d.id AND ds.sku_id = sqlc.narg('sku_id')))
ORDER BY distance_m, d.id
LIMIT sqlc.arg('row_limit');
