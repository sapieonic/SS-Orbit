-- name: ListSeasons :many
SELECT * FROM crop_seasons
WHERE id = ANY(@season_ids::uuid[]) OR farmer_id = ANY(@farmer_ids::uuid[])
ORDER BY created_at DESC, id DESC;

-- name: GetSeasonForUpdate :one
SELECT * FROM crop_seasons WHERE id = $1 FOR UPDATE;

-- name: ActiveSeasonForPlot :one
SELECT * FROM crop_seasons WHERE plot_id = $1 AND status = 'active';

-- name: InsertSeason :one
INSERT INTO crop_seasons (id, farmer_id, plot_id, season_code, crop_id, sowing_date, previous_crop_id, last_command_id)
VALUES (@id, @farmer_id, @plot_id, @season_code, @crop_id, sqlc.narg('sowing_date'), sqlc.narg('previous_crop_id'), sqlc.narg('last_command_id'))
RETURNING *;

-- name: CloseSeason :one
UPDATE crop_seasons SET status = @status, version = version + 1
WHERE id = @id AND status = 'active'
RETURNING *;

-- name: CloseSeasonsByCode :many
-- Season rollover: closes every active season with this code (within the HO
-- user's districts) and returns what changed, with the farmer's FA to bump.
UPDATE crop_seasons s
SET status = @status, version = s.version + 1
FROM farmers f
WHERE s.farmer_id = f.id
  AND s.season_code = @season_code
  AND s.status = 'active'
  AND (cardinality(@scope_district_ids::uuid[]) = 0 OR f.district_id = ANY(@scope_district_ids::uuid[]))
RETURNING s.id, s.farmer_id, s.plot_id, f.assigned_fa_id;

-- name: ActiveSeasonsForFarmers :many
SELECT id, farmer_id, crop_id, sowing_date FROM crop_seasons
WHERE status = 'active' AND farmer_id = ANY(@farmer_ids::uuid[])
  AND (cardinality(@crop_ids::uuid[]) = 0 OR crop_id = ANY(@crop_ids::uuid[]));
