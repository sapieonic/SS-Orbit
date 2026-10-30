-- name: ListPlots :many
-- Plots by ID or by farmer. Geography is read as GeoJSON text / lat-lng; ''
-- and has_pin = false mean absent (sqlc cannot see nullability through casts).
SELECT id, farmer_id, label, village_id,
  COALESCE(ST_AsGeoJSON(boundary), '')::text AS boundary_geojson,
  (pin IS NOT NULL)::bool AS has_pin,
  COALESCE(ST_Y(pin::geometry), 0)::float8 AS pin_lat,
  COALESCE(ST_X(pin::geometry), 0)::float8 AS pin_lng,
  area_acres::float8 AS area_acres,
  area_source,
  COALESCE(gps_accuracy_m, -1)::float8 AS gps_accuracy_m,
  status, version, created_by_fa_id, last_command_id, created_at, updated_at
FROM plots
WHERE id = ANY(@plot_ids::uuid[]) OR farmer_id = ANY(@farmer_ids::uuid[])
ORDER BY created_at, id;

-- name: LockPlot :one
SELECT id, farmer_id, version FROM plots WHERE id = $1 FOR UPDATE;

-- name: CountFarmerPlots :one
SELECT count(*)::int FROM plots WHERE farmer_id = $1;

-- name: MeasureBoundary :one
-- Parses a GeoJSON boundary and returns its geometry type, validity and area
-- in acres (1 acre = 4046.8564224 m2). Run outside a transaction: bad GeoJSON
-- raises an error.
SELECT GeometryType(ST_GeomFromGeoJSON(@geojson::text))::text AS geom_type,
  ST_IsValid(ST_GeomFromGeoJSON(@geojson::text))::bool AS valid,
  (ST_Area(ST_GeomFromGeoJSON(@geojson::text)::geography) / 4046.8564224)::float8 AS area_acres;

-- name: InsertPlot :exec
INSERT INTO plots (id, farmer_id, label, village_id, boundary, pin, area_acres, area_source, gps_accuracy_m, created_by_fa_id, last_command_id)
VALUES (
  @id, @farmer_id, @label, sqlc.narg('village_id'),
  ST_GeomFromGeoJSON(sqlc.narg('boundary_geojson')::text)::geography,
  CASE WHEN sqlc.narg('pin_lat')::float8 IS NULL THEN NULL
       ELSE ST_SetSRID(ST_MakePoint(sqlc.narg('pin_lng')::float8, sqlc.narg('pin_lat')::float8), 4326)::geography END,
  (@area_acres::float8)::numeric, @area_source, (sqlc.narg('gps_accuracy_m')::float8)::numeric,
  sqlc.narg('created_by_fa_id'), sqlc.narg('last_command_id')
);

-- name: UpdatePlot :exec
UPDATE plots SET
  label           = @label,
  boundary        = ST_GeomFromGeoJSON(sqlc.narg('boundary_geojson')::text)::geography,
  pin             = CASE WHEN sqlc.narg('pin_lat')::float8 IS NULL THEN NULL
                         ELSE ST_SetSRID(ST_MakePoint(sqlc.narg('pin_lng')::float8, sqlc.narg('pin_lat')::float8), 4326)::geography END,
  area_acres      = (@area_acres::float8)::numeric,
  area_source     = @area_source,
  gps_accuracy_m  = (sqlc.narg('gps_accuracy_m')::float8)::numeric,
  last_command_id = sqlc.narg('last_command_id'),
  version         = version + 1
WHERE id = @id;
