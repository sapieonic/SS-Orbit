-- name: UpsertHOAlert :one
-- One alert per (kind, farmer). A later event fills in what an earlier one
-- did not know (district, FA) and merges payload keys, so the order of
-- farmer.registered and farmer.profile_completed does not matter.
INSERT INTO ho_alerts (id, kind, farmer_id, fa_id, district_id, payload)
VALUES (@id, @kind, @farmer_id, sqlc.narg('fa_id'), sqlc.narg('district_id'), @payload)
ON CONFLICT (kind, farmer_id) WHERE farmer_id IS NOT NULL DO UPDATE
SET district_id = COALESCE(ho_alerts.district_id, EXCLUDED.district_id),
    fa_id       = COALESCE(ho_alerts.fa_id, EXCLUDED.fa_id),
    payload     = ho_alerts.payload || EXCLUDED.payload
RETURNING *;

-- name: ListHOAlerts :many
-- Newest first, keyset on (created_at, id). With scope_district_ids (HO area
-- scope) only alerts in those districts are returned.
SELECT *
FROM ho_alerts
WHERE (sqlc.narg('kind')::text IS NULL OR kind = sqlc.narg('kind'))
  AND (sqlc.narg('scope_district_ids')::uuid[] IS NULL OR district_id = ANY (sqlc.narg('scope_district_ids')::uuid[]))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg('row_limit');

-- name: InsertFAOfflineAlert :one
-- One fa_offline alert per FA per IST day; returns no rows if it exists.
INSERT INTO ho_alerts (id, kind, fa_id, district_id, payload, alert_day)
VALUES (@id, 'fa_offline', @fa_id, sqlc.narg('district_id'), @payload, @alert_day)
ON CONFLICT (fa_id, alert_day) WHERE kind = 'fa_offline' DO NOTHING
RETURNING *;
