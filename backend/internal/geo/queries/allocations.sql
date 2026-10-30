-- name: GetAllocationDetail :one
SELECT * FROM allocation_details WHERE id = $1;

-- name: GetAllocationDetails :many
SELECT * FROM allocation_details WHERE id = ANY(@ids::uuid[]) ORDER BY created_at, id;

-- name: ListAllocations :many
-- Newest first, keyset on (created_at, id). district_id / mandal_id match
-- allocations at or below that area (allocation_details resolves both).
SELECT * FROM allocation_details
WHERE (sqlc.narg('fa_id')::uuid IS NULL OR fa_id = sqlc.narg('fa_id'))
  AND (sqlc.narg('district_id')::uuid IS NULL OR district_id = sqlc.narg('district_id'))
  AND (sqlc.narg('mandal_id')::uuid IS NULL OR mandal_id = sqlc.narg('mandal_id'))
  AND (sqlc.narg('village_id')::uuid IS NULL OR village_id = sqlc.narg('village_id'))
  AND (cardinality(@district_scope::uuid[]) = 0 OR district_id = ANY(@district_scope::uuid[]))
  AND (@include_ended::bool OR valid_to IS NULL)
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg('row_limit');

-- name: InsertAllocation :one
-- created_by is kept only if it names a real HO user (dev tokens carry random
-- IDs); this reads ho_users solely to satisfy the foreign key.
INSERT INTO fa_allocations (id, fa_id, level, village_id, mandal_id, district_id, is_lead, valid_from, created_by)
VALUES (@id, @fa_id, @level, sqlc.narg('village_id'), sqlc.narg('mandal_id'), sqlc.narg('district_id'), @is_lead, @valid_from,
        (SELECT h.id FROM ho_users h WHERE h.id = sqlc.narg('created_by')::uuid))
RETURNING *;

-- name: CurrentAllocationOnArea :one
-- An FA's current allocation on one area, if any.
SELECT * FROM fa_allocations
WHERE fa_id = @fa_id AND level = @level AND valid_to IS NULL
  AND COALESCE(village_id, mandal_id, district_id) = @area_id::uuid;

-- name: CurrentLeadOnArea :one
SELECT * FROM fa_allocations
WHERE level = @level AND is_lead AND valid_to IS NULL
  AND COALESCE(village_id, mandal_id, district_id) = @area_id::uuid;

-- name: LockCurrentAllocationsForFA :many
-- Locks the FA's current allocations for a hand-over.
SELECT * FROM fa_allocations
WHERE fa_id = @fa_id AND valid_to IS NULL
ORDER BY created_at, id
FOR UPDATE;

-- name: GetAllocationForUpdate :one
SELECT * FROM fa_allocations WHERE id = $1 FOR UPDATE;

-- name: EndAllocation :exec
UPDATE fa_allocations SET valid_to = @valid_to WHERE id = @id AND valid_to IS NULL;

-- name: FAsCoveringVillage :many
-- Current allocations covering a village: most specific level first, leads
-- first within a level, then the longest-serving.
SELECT a.fa_id, a.level, a.is_lead
FROM villages v
JOIN mandals m ON m.id = v.mandal_id
JOIN fa_allocations a ON a.valid_to IS NULL AND (
       (a.level = 'village' AND a.village_id = v.id)
    OR (a.level = 'mandal' AND a.mandal_id = v.mandal_id)
    OR (a.level = 'district' AND a.district_id = m.district_id))
WHERE v.id = @village_id
ORDER BY CASE a.level WHEN 'village' THEN 0 WHEN 'mandal' THEN 1 ELSE 2 END, a.is_lead DESC, a.valid_from, a.id;

-- name: VillageIDsForFA :many
-- Every village an FA's current allocations cover, mandal and district
-- allocations expanded.
SELECT v.id FROM villages v
WHERE v.id IN (SELECT a.village_id FROM fa_allocations a
               WHERE a.fa_id = @fa_id AND a.valid_to IS NULL AND a.level = 'village')
   OR v.mandal_id IN (SELECT a.mandal_id FROM fa_allocations a
                      WHERE a.fa_id = @fa_id AND a.valid_to IS NULL AND a.level = 'mandal')
   OR v.mandal_id IN (SELECT m.id FROM mandals m JOIN fa_allocations a ON a.district_id = m.district_id
                      WHERE a.fa_id = @fa_id AND a.valid_to IS NULL AND a.level = 'district')
ORDER BY v.id;

-- name: FAIDsCoveringMandals :many
-- FAs whose current allocations touch any village of the mandals (village,
-- mandal or district level). Used to bump territory versions after edits.
SELECT DISTINCT a.fa_id FROM fa_allocations a
WHERE a.valid_to IS NULL AND (
       (a.level = 'mandal' AND a.mandal_id = ANY(@mandal_ids::uuid[]))
    OR (a.level = 'district' AND a.district_id IN (SELECT m.district_id FROM mandals m WHERE m.id = ANY(@mandal_ids::uuid[])))
    OR (a.level = 'village' AND a.village_id IN (SELECT v.id FROM villages v WHERE v.mandal_id = ANY(@mandal_ids::uuid[]))));

-- name: FAIDsCoveringDistrict :many
-- FAs whose current allocations are anywhere in the district.
SELECT DISTINCT a.fa_id FROM allocation_details a
WHERE a.valid_to IS NULL AND a.district_id = @district_id;

-- name: DistrictIDsForFAs :many
-- The districts of each FA's current allocations (village and mandal
-- allocations resolved to their district).
SELECT DISTINCT fa_id, district_id FROM allocation_details
WHERE valid_to IS NULL AND fa_id = ANY(@fa_ids::uuid[])
ORDER BY fa_id, district_id;
