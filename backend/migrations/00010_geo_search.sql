-- Geo: indexes for the village picker (Telugu search) and FA allocation lookups,
-- plus a guard against allocating the same FA to the same area twice.

-- +goose Up
-- "Pick your village" searches name and name_te; 00003 indexed only name.
CREATE INDEX villages_name_te_trgm ON villages USING gin (name_te gin_trgm_ops);

-- FAsCoveringVillage / VillageIDsForFA / allocation filters look up current
-- allocations by area at every level, leads or not.
CREATE INDEX fa_allocations_village_current ON fa_allocations (village_id) WHERE valid_to IS NULL AND level = 'village';
CREATE INDEX fa_allocations_mandal_current ON fa_allocations (mandal_id) WHERE valid_to IS NULL AND level = 'mandal';
CREATE INDEX fa_allocations_district_current ON fa_allocations (district_id) WHERE valid_to IS NULL AND level = 'district';

-- One current allocation per FA per area (lead or not).
CREATE UNIQUE INDEX fa_allocations_fa_area_current ON fa_allocations (fa_id, level, COALESCE(village_id, mandal_id, district_id))
  WHERE valid_to IS NULL;

-- A village with its mandal and district names, the shape every reader wants.
-- The centroid is exposed as plain numbers (0 when has_centroid is false)
-- because sqlc cannot map geography or infer nullability through casts.
CREATE VIEW village_details AS
SELECT v.id, v.name, v.name_te, v.lgd_code,
       (v.centroid IS NOT NULL)::bool AS has_centroid,
       COALESCE(ST_Y(v.centroid::geometry), 0)::float8 AS lat,
       COALESCE(ST_X(v.centroid::geometry), 0)::float8 AS lng,
       m.id AS mandal_id, m.name AS mandal_name, m.name_te AS mandal_name_te,
       d.id AS district_id, d.name AS district_name, d.name_te AS district_name_te,
       v.created_at
FROM villages v
JOIN mandals m ON m.id = v.mandal_id
JOIN districts d ON d.id = m.district_id;

-- An allocation with its area resolved: mandal_* is the village's mandal for a
-- village-level allocation (NULL for district level); district_* is always set.
CREATE VIEW allocation_details AS
SELECT a.id, a.fa_id, a.level, a.is_lead, a.valid_from, a.valid_to, a.created_by, a.created_at,
       a.village_id, v.name AS village_name, v.name_te AS village_name_te,
       m.id AS mandal_id, m.name AS mandal_name, m.name_te AS mandal_name_te,
       d.id AS district_id, d.name AS district_name, d.name_te AS district_name_te
FROM fa_allocations a
LEFT JOIN villages v ON v.id = a.village_id
LEFT JOIN mandals m ON m.id = COALESCE(a.mandal_id, v.mandal_id)
JOIN districts d ON d.id = COALESCE(a.district_id, m.district_id);

-- +goose Down
DROP VIEW allocation_details;
DROP VIEW village_details;
DROP INDEX fa_allocations_fa_area_current;
DROP INDEX fa_allocations_district_current;
DROP INDEX fa_allocations_mandal_current;
DROP INDEX fa_allocations_village_current;
DROP INDEX villages_name_te_trgm;
