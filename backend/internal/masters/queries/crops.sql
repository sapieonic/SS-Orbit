-- name: CreateCrop :one
INSERT INTO crops (id, code, name, name_te, duration_days)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetCrop :one
SELECT * FROM crops WHERE id = $1;

-- name: GetCropForUpdate :one
SELECT * FROM crops WHERE id = $1 FOR UPDATE;

-- name: UpdateCrop :one
UPDATE crops SET
  name          = COALESCE(sqlc.narg('name'), name),
  name_te       = COALESCE(sqlc.narg('name_te'), name_te),
  duration_days = COALESCE(sqlc.narg('duration_days'), duration_days),
  active        = COALESCE(sqlc.narg('active'), active)
WHERE id = sqlc.arg('id')
RETURNING *;

-- name: ListCrops :many
-- Oldest first, keyset on (created_at, id).
SELECT * FROM crops
WHERE (sqlc.narg('active')::boolean IS NULL OR active = sqlc.narg('active'))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) > (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at, id
LIMIT sqlc.arg('row_limit');

-- name: ListActiveCrops :many
SELECT * FROM crops WHERE active ORDER BY name, id;

-- name: ListStagesForCrops :many
-- Stages of the given crops in calendar order; inactive ones only when asked.
SELECT * FROM crop_stages
WHERE crop_id = ANY(sqlc.arg('crop_ids')::uuid[])
  AND (sqlc.arg('include_inactive')::boolean OR active)
ORDER BY crop_id, active DESC, seq, id;

-- name: ListActiveStagesForCrop :many
SELECT * FROM crop_stages WHERE crop_id = $1 AND active ORDER BY seq;

-- name: DeactivateStages :exec
UPDATE crop_stages SET active = false WHERE crop_id = $1;

-- name: UpsertStage :one
-- A stage is identified by (crop_id, code); re-listing an inactive code reactivates it.
INSERT INTO crop_stages (id, crop_id, code, name, name_te, seq, start_day, end_day, active)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true)
ON CONFLICT (crop_id, code) DO UPDATE SET
  name = EXCLUDED.name, name_te = EXCLUDED.name_te, seq = EXCLUDED.seq,
  start_day = EXCLUDED.start_day, end_day = EXCLUDED.end_day, active = true
RETURNING *;

-- name: GetStage :one
SELECT * FROM crop_stages WHERE id = $1;
