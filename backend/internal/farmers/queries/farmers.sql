-- name: GetFarmer :one
SELECT * FROM farmers WHERE id = $1;

-- name: GetFarmerForUpdate :one
SELECT * FROM farmers WHERE id = $1 FOR UPDATE;

-- name: GetFarmerByPhoneForUpdate :one
SELECT * FROM farmers WHERE phone = $1 FOR UPDATE;

-- name: ListFarmersByIDs :many
SELECT * FROM farmers WHERE id = ANY(@ids::uuid[]) ORDER BY id;

-- name: InsertFarmer :one
-- A concurrent insert of the same phone returns no row; the caller re-reads it.
INSERT INTO farmers (
  id, phone, name, name_te, language, village_id, mandal_id, district_id,
  assigned_fa_id, source, enrolled_by_fa_id, photo_key, status, profile_completed_at, last_command_id
) VALUES (
  @id, @phone, sqlc.narg('name'), sqlc.narg('name_te'), @language, sqlc.narg('village_id'),
  sqlc.narg('mandal_id'), sqlc.narg('district_id'), sqlc.narg('assigned_fa_id'), @source,
  sqlc.narg('enrolled_by_fa_id'), sqlc.narg('photo_key'), @status, sqlc.narg('profile_completed_at'),
  sqlc.narg('last_command_id')
)
ON CONFLICT (phone) DO NOTHING
RETURNING *;

-- name: SaveFarmer :one
-- Writes every mutable field and bumps the version. The service loads the row
-- (FOR UPDATE), changes it and saves it back.
UPDATE farmers SET
  phone                = @phone,
  name                 = sqlc.narg('name'),
  name_te              = sqlc.narg('name_te'),
  language             = @language,
  village_id           = sqlc.narg('village_id'),
  mandal_id            = sqlc.narg('mandal_id'),
  district_id          = sqlc.narg('district_id'),
  assigned_fa_id       = sqlc.narg('assigned_fa_id'),
  enrolled_by_fa_id    = sqlc.narg('enrolled_by_fa_id'),
  photo_key            = sqlc.narg('photo_key'),
  plan                 = @plan,
  status               = @status,
  profile_completed_at = sqlc.narg('profile_completed_at'),
  last_command_id      = sqlc.narg('last_command_id'),
  version              = version + 1
WHERE id = @id
RETURNING *;

-- name: FarmerIDsAssignedTo :many
SELECT id FROM farmers WHERE assigned_fa_id = $1 AND status <> 'inactive' ORDER BY id;

-- name: TargetFarmerIDs :many
-- Active farmers whose current programme consent is granted. Every non-empty
-- filter narrows the audience (AND): plan, villages, mandals, districts and
-- crop of an active season. An empty list means "any".
SELECT f.id
FROM farmers f
WHERE f.status = 'active'
  AND (sqlc.narg('plan')::text IS NULL OR f.plan = sqlc.narg('plan'))
  AND (cardinality(@village_ids::uuid[]) = 0 OR f.village_id = ANY(@village_ids::uuid[]))
  AND (cardinality(@mandal_ids::uuid[]) = 0 OR f.mandal_id = ANY(@mandal_ids::uuid[]))
  AND (cardinality(@district_ids::uuid[]) = 0 OR f.district_id = ANY(@district_ids::uuid[]))
  AND (cardinality(@crop_ids::uuid[]) = 0 OR EXISTS (
        SELECT 1 FROM crop_seasons s
        WHERE s.farmer_id = f.id AND s.status = 'active' AND s.crop_id = ANY(@crop_ids::uuid[])))
  AND (SELECT c.granted FROM consents c
       WHERE c.farmer_id = f.id AND c.purpose = 'programme'
       ORDER BY c.created_at DESC, c.id DESC LIMIT 1) IS TRUE
ORDER BY f.id;

-- name: ListFarmersAdmin :many
-- HO farmer list, newest first, keyset on (created_at, id). Filters are
-- optional; scope_district_ids limits an HO user with an area scope.
SELECT f.*,
  COALESCE((SELECT array_agg(DISTINCT s.crop_id) FROM crop_seasons s
            WHERE s.farmer_id = f.id AND s.status = 'active'), '{}')::uuid[] AS active_crop_ids,
  COALESCE((SELECT sum(p.area_acres) FROM plots p
            WHERE p.farmer_id = f.id AND p.status = 'active'), 0)::float8 AS total_area_acres,
  (SELECT count(*) FROM plots p WHERE p.farmer_id = f.id AND p.status = 'active')::int AS plot_count
FROM farmers f
WHERE (cardinality(@scope_district_ids::uuid[]) = 0 OR f.district_id = ANY(@scope_district_ids::uuid[]))
  AND (sqlc.narg('district_id')::uuid IS NULL OR f.district_id = sqlc.narg('district_id'))
  AND (sqlc.narg('mandal_id')::uuid IS NULL OR f.mandal_id = sqlc.narg('mandal_id'))
  AND (sqlc.narg('village_id')::uuid IS NULL OR f.village_id = sqlc.narg('village_id'))
  AND (sqlc.narg('fa_id')::uuid IS NULL OR f.assigned_fa_id = sqlc.narg('fa_id'))
  AND (NOT @unassigned::bool OR f.assigned_fa_id IS NULL)
  AND (sqlc.narg('status')::text IS NULL OR f.status = sqlc.narg('status'))
  AND (sqlc.narg('plan')::text IS NULL OR f.plan = sqlc.narg('plan'))
  AND (sqlc.narg('crop_id')::uuid IS NULL OR EXISTS (
        SELECT 1 FROM crop_seasons s
        WHERE s.farmer_id = f.id AND s.status = 'active' AND s.crop_id = sqlc.narg('crop_id')))
  AND (sqlc.narg('name_like')::text IS NULL
       OR f.name ILIKE sqlc.narg('name_like') OR f.name_te ILIKE sqlc.narg('name_like')
       OR (sqlc.narg('phone_like')::text IS NOT NULL AND f.phone LIKE sqlc.narg('phone_like')))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (f.created_at, f.id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY f.created_at DESC, f.id DESC
LIMIT @row_limit;

-- name: ReassignFarmers :many
-- Moves the selected farmers (by ID or by village) to to_fa_id and returns
-- each moved farmer with its previous FA. Inactive farmers and farmers already
-- with to_fa_id are skipped; with from_fa_id only that FA's farmers move.
UPDATE farmers f
SET assigned_fa_id = @to_fa_id, version = f.version + 1
FROM (
  SELECT id, assigned_fa_id FROM farmers
  WHERE (id = ANY(@farmer_ids::uuid[]) OR village_id = ANY(@village_ids::uuid[]))
    AND status <> 'inactive'
    AND assigned_fa_id IS DISTINCT FROM @to_fa_id
    AND (sqlc.narg('from_fa_id')::uuid IS NULL OR assigned_fa_id = sqlc.narg('from_fa_id'))
    AND (cardinality(@scope_district_ids::uuid[]) = 0 OR district_id = ANY(@scope_district_ids::uuid[]))
  FOR UPDATE
) old
WHERE f.id = old.id
RETURNING f.id, old.assigned_fa_id AS previous_fa_id;

-- name: GetAlias :one
SELECT * FROM farmer_aliases WHERE alias_id = $1;

-- name: InsertAlias :exec
INSERT INTO farmer_aliases (alias_id, farmer_id, command_id, fa_id)
VALUES (@alias_id, @farmer_id, @command_id, sqlc.narg('fa_id'))
ON CONFLICT (alias_id) DO NOTHING;

-- name: GetEnrolment :one
SELECT * FROM farmer_enrolments WHERE command_id = $1;

-- name: InsertEnrolment :exec
INSERT INTO farmer_enrolments (command_id, farmer_id, phone_farmer_id, fa_id, consent_recorded)
VALUES (@command_id, @farmer_id, @phone_farmer_id, @fa_id, @consent_recorded);

-- name: GetFarmerByPhone :one
SELECT * FROM farmers WHERE phone = $1;

-- name: FarmerStats :one
-- HO overview numbers (ADM-01). total counts every farmer not deactivated;
-- consent_pending is a farmer not deactivated with no programme consent row
-- at all (an FA enrolment without a valid OTP proof, or a self sign-up that
-- has not answered yet).
SELECT
  count(*) FILTER (WHERE f.status <> 'inactive')::int AS total,
  count(*) FILTER (WHERE f.status = 'active')::int AS active,
  count(*) FILTER (WHERE f.status = 'pending_profile')::int AS pending_profile,
  count(*) FILTER (WHERE f.status = 'inactive')::int AS inactive,
  count(*) FILTER (WHERE f.status <> 'inactive' AND f.plan = 'premium')::int AS premium,
  count(*) FILTER (WHERE f.status <> 'inactive' AND NOT EXISTS (
    SELECT 1 FROM consents c WHERE c.farmer_id = f.id AND c.purpose = 'programme'))::int AS consent_pending,
  count(*) FILTER (WHERE f.status <> 'inactive' AND f.created_at >= @since::timestamptz)::int AS new_since,
  count(*) FILTER (WHERE f.status = 'active' AND f.assigned_fa_id IS NULL)::int AS unassigned
FROM farmers f
WHERE (cardinality(@scope_district_ids::uuid[]) = 0 OR f.district_id = ANY(@scope_district_ids::uuid[]))
  AND (sqlc.narg('district_id')::uuid IS NULL OR f.district_id = sqlc.narg('district_id'));
