-- Visits written by FA sync commands, and the reads the FA and farmer apps need.

-- name: GetVisit :one
SELECT * FROM visit_details WHERE id = $1;

-- name: LockVisit :one
-- Row lock for a status change. Only the fields the rules need.
SELECT id, farmer_id, plot_id, season_id, fa_id, status, planned_for, planned_slot, purpose
FROM visits
WHERE id = $1
FOR UPDATE;

-- name: UpsertPlannedVisit :exec
-- New plan, or re-plan of an existing planned/missed visit (the service checks
-- the status and owner first).
INSERT INTO visits (id, farmer_id, plot_id, season_id, fa_id, status, planned_for, planned_slot, purpose, client_created_at,
                    district_id)
VALUES (sqlc.arg('id'), sqlc.arg('farmer_id'), sqlc.arg('plot_id'), sqlc.arg('season_id'), sqlc.arg('fa_id'), 'planned',
        sqlc.arg('planned_for'), sqlc.arg('planned_slot'), sqlc.narg('purpose'), sqlc.narg('client_created_at'),
        sqlc.narg('district_id'))
ON CONFLICT (id) DO UPDATE
  SET status       = 'planned',
      planned_for  = EXCLUDED.planned_for,
      planned_slot = EXCLUDED.planned_slot,
      purpose      = EXCLUDED.purpose,
      district_id  = EXCLUDED.district_id;

-- name: InsertPlannedVisitIfAbsent :execrows
-- The optional next visit on a LogVisit. 0 rows = the ID already exists.
INSERT INTO visits (id, farmer_id, plot_id, season_id, fa_id, status, planned_for, planned_slot, client_created_at,
                    district_id)
VALUES (sqlc.arg('id'), sqlc.arg('farmer_id'), sqlc.arg('plot_id'), sqlc.arg('season_id'), sqlc.arg('fa_id'), 'planned',
        sqlc.arg('planned_for'), sqlc.arg('planned_slot'), sqlc.narg('client_created_at'), sqlc.narg('district_id'))
ON CONFLICT (id) DO NOTHING;

-- name: UpsertLoggedVisit :exec
-- A logged visit: new, or a planned/missed/cancelled visit that turns done.
-- planned_for and planned_slot of an earlier plan are kept.
INSERT INTO visits (id, farmer_id, plot_id, season_id, fa_id, status, visited_at, location, farmer_present,
                    stage_id, stage_name, stage_name_te, notes, client_created_at, district_id)
VALUES (sqlc.arg('id'), sqlc.arg('farmer_id'), sqlc.arg('plot_id'), sqlc.arg('season_id'), sqlc.arg('fa_id'), 'done',
        sqlc.arg('visited_at'), ST_GeomFromGeoJSON(sqlc.narg('location_geojson')::text)::geography,
        sqlc.arg('farmer_present'), sqlc.narg('stage_id'), sqlc.narg('stage_name'), sqlc.narg('stage_name_te'),
        sqlc.narg('notes'), sqlc.narg('client_created_at'), sqlc.narg('district_id'))
ON CONFLICT (id) DO UPDATE
  SET status         = 'done',
      district_id    = EXCLUDED.district_id,
      fa_id          = EXCLUDED.fa_id,
      visited_at     = EXCLUDED.visited_at,
      location       = EXCLUDED.location,
      farmer_present = EXCLUDED.farmer_present,
      stage_id       = EXCLUDED.stage_id,
      stage_name     = EXCLUDED.stage_name,
      stage_name_te  = EXCLUDED.stage_name_te,
      notes          = EXCLUDED.notes;

-- name: SetVisitStatus :exec
UPDATE visits SET status = sqlc.arg('status') WHERE id = sqlc.arg('id');

-- name: InsertVisitIssue :exec
-- The phone mints issue_visit_id. A logged visit is never written twice, so
-- an existing ID belongs to another visit: the unique violation rejects it.
INSERT INTO visit_issues (id, visit_id, farmer_id, plot_id, season_id, issue_id, severity, advisory_rule_id, rule_version,
                          issue_name, issue_name_te, salt_id, salt_name, salt_name_te, sku_id, product_name,
                          product_name_te, dose_per_acre, dose_per_acre_te, advice_status, requested_rule_id,
                          unresolved_reason)
VALUES (sqlc.arg('id'), sqlc.arg('visit_id'), sqlc.arg('farmer_id'), sqlc.arg('plot_id'), sqlc.arg('season_id'),
        sqlc.arg('issue_id'), sqlc.arg('severity'), sqlc.narg('advisory_rule_id'), sqlc.narg('rule_version'),
        sqlc.narg('issue_name'), sqlc.narg('issue_name_te'), sqlc.narg('salt_id'), sqlc.narg('salt_name'),
        sqlc.narg('salt_name_te'), sqlc.narg('sku_id'), sqlc.narg('product_name'), sqlc.narg('product_name_te'),
        sqlc.narg('dose_per_acre'), sqlc.narg('dose_per_acre_te'), sqlc.arg('advice_status'),
        sqlc.narg('requested_rule_id'), sqlc.narg('unresolved_reason'));

-- name: ListVisitIssues :many
SELECT *
FROM visit_issues
WHERE visit_id = ANY (sqlc.arg('visit_ids')::uuid[])
ORDER BY visit_id, created_at, id;

-- name: InsertVisitPhoto :exec
-- Awaiting upload until the phone confirms it. Like issues, a photo_id that
-- already exists belongs to another visit and is rejected.
INSERT INTO visit_photos (id, visit_id, storage_key, content_type)
VALUES (sqlc.arg('id'), sqlc.arg('visit_id'), sqlc.arg('storage_key'), sqlc.arg('content_type'));

-- name: GetVisitPhoto :one
SELECT * FROM visit_photos WHERE id = sqlc.arg('id') AND visit_id = sqlc.arg('visit_id');

-- name: SetPhotoSize :exec
UPDATE visit_photos SET bytes = sqlc.arg('bytes') WHERE id = sqlc.arg('id');

-- name: MarkPhotoUploaded :one
UPDATE visit_photos
SET uploaded_at = sqlc.arg('uploaded_at'),
    sha256      = COALESCE(sqlc.narg('sha256'), sha256)
WHERE id = sqlc.arg('id')
RETURNING *;

-- name: ListVisitPhotos :many
SELECT * FROM visit_photos WHERE visit_id = $1 ORDER BY created_at, id;

-- name: ListPlannedVisitsForFarmers :many
-- Snapshot: every planned visit of the FA's farmers.
SELECT *
FROM visit_details
WHERE status = 'planned'
  AND farmer_id = ANY (sqlc.arg('farmer_ids')::uuid[])
ORDER BY planned_for, id;

-- name: ListRecentDoneVisitsForFarmers :many
-- Snapshot: the last per_farmer logged visits of each farmer.
SELECT d.*
FROM visit_details d
JOIN (SELECT id, row_number() OVER (PARTITION BY farmer_id ORDER BY visited_at DESC, id DESC) AS rn
      FROM visits
      WHERE status = 'done'
        AND farmer_id = ANY (sqlc.arg('farmer_ids')::uuid[])) r ON r.id = d.id
WHERE r.rn <= sqlc.arg('per_farmer')::integer
ORDER BY d.farmer_id, d.visited_at DESC, d.id DESC;

-- name: ListFarmerDoneVisits :many
-- Farmer app history, newest first, keyset on (visited_at, id).
SELECT *
FROM visit_details
WHERE farmer_id = sqlc.arg('farmer_id')
  AND status = 'done'
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (visited_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY visited_at DESC, id DESC
LIMIT sqlc.arg('row_limit');

-- name: NextPlannedVisit :one
SELECT *
FROM visit_details
WHERE farmer_id = sqlc.arg('farmer_id')
  AND status = 'planned'
  AND planned_for >= sqlc.arg('today')::date
ORDER BY planned_for,
         CASE planned_slot WHEN 'morning' THEN 0 WHEN 'afternoon' THEN 1 ELSE 2 END,
         id
LIMIT 1;

-- name: MarkMissedVisits :many
-- Planned visits whose day has passed become missed (River job).
UPDATE visits
SET status = 'missed'
WHERE status = 'planned'
  AND planned_for < sqlc.arg('today')::date
RETURNING id, farmer_id, plot_id, season_id, fa_id, planned_for;

-- name: ReassignPlannedVisits :many
-- farmers.reassigned: planned visits follow the farmer to the new FA.
UPDATE visits v
SET fa_id = sqlc.arg('to_fa_id')
FROM (SELECT id, fa_id
      FROM visits
      WHERE status = 'planned'
        AND farmer_id = ANY (sqlc.arg('farmer_ids')::uuid[])
        AND fa_id <> sqlc.arg('to_fa_id')
      FOR UPDATE) prev
WHERE v.id = prev.id
RETURNING v.id, v.farmer_id, prev.fa_id AS from_fa_id;
