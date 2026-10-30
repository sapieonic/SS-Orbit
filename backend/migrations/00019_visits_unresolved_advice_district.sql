-- Visits: advice the server could not confirm, and the farmer's district.
--
-- * LogVisit stores the rule the FA picked offline (issues[].advisory_rule_id).
--   If that rule does not check out (unknown, never approved, or for another
--   issue) the visit is still kept: the issue is stored with advice_status
--   'unresolved', no salt/rule, the ID the FA sent (requested_rule_id) and why,
--   and the HO visit detail shows it. A visit is never rejected over advice.
-- * visits.district_id is the farmer's district when the visit was written, so
--   HO users with an area scope see only visits in their districts.
--   Existing rows are filled from farmers.district_id (a read of the farmers
--   table; only visits is changed).

-- +goose Up
ALTER TABLE visits ADD COLUMN district_id uuid REFERENCES districts (id);
UPDATE visits v SET district_id = f.district_id FROM farmers f WHERE f.id = v.farmer_id;
CREATE INDEX visits_district_idx ON visits (district_id);

ALTER TABLE visit_issues
  ALTER COLUMN salt_id DROP NOT NULL,
  ADD COLUMN advice_status     text NOT NULL DEFAULT 'given' CHECK (advice_status IN ('given', 'unresolved')),
  ADD COLUMN requested_rule_id uuid,
  ADD COLUMN unresolved_reason text,
  ADD CONSTRAINT visit_issues_advice_given CHECK (advice_status = 'unresolved' OR salt_id IS NOT NULL);

CREATE OR REPLACE VIEW visit_details AS
SELECT v.id,
       v.farmer_id,
       v.plot_id,
       v.season_id,
       v.fa_id,
       v.status,
       v.planned_for,
       v.planned_slot,
       v.purpose,
       v.visited_at,
       (COALESCE(ST_AsGeoJSON(v.location), ''))::text AS location_geojson,
       v.farmer_present,
       v.stage_id,
       v.stage_name,
       v.stage_name_te,
       v.notes,
       v.client_created_at,
       v.created_at,
       v.updated_at,
       COALESCE((v.visited_at AT TIME ZONE 'Asia/Kolkata')::date, v.planned_for)::date AS visit_date,
       COALESCE(v.visited_at, v.planned_for::timestamp AT TIME ZONE 'Asia/Kolkata')::timestamptz AS event_at,
       (SELECT count(*) FROM visit_photos p WHERE p.visit_id = v.id)::integer AS photo_count,
       v.district_id
FROM visits v;

-- +goose Down
-- Unresolved issues have no salt and cannot go back under NOT NULL: they are deleted.
DROP VIEW visit_details;
CREATE VIEW visit_details AS
SELECT v.id,
       v.farmer_id,
       v.plot_id,
       v.season_id,
       v.fa_id,
       v.status,
       v.planned_for,
       v.planned_slot,
       v.purpose,
       v.visited_at,
       (COALESCE(ST_AsGeoJSON(v.location), ''))::text AS location_geojson,
       v.farmer_present,
       v.stage_id,
       v.stage_name,
       v.stage_name_te,
       v.notes,
       v.client_created_at,
       v.created_at,
       v.updated_at,
       COALESCE((v.visited_at AT TIME ZONE 'Asia/Kolkata')::date, v.planned_for)::date AS visit_date,
       COALESCE(v.visited_at, v.planned_for::timestamp AT TIME ZONE 'Asia/Kolkata')::timestamptz AS event_at,
       (SELECT count(*) FROM visit_photos p WHERE p.visit_id = v.id)::integer AS photo_count
FROM visits v;

DELETE FROM visit_issues WHERE advice_status = 'unresolved';
ALTER TABLE visit_issues
  DROP CONSTRAINT visit_issues_advice_given,
  DROP COLUMN unresolved_reason,
  DROP COLUMN requested_rule_id,
  DROP COLUMN advice_status,
  ALTER COLUMN salt_id SET NOT NULL;

DROP INDEX visits_district_idx;
ALTER TABLE visits DROP COLUMN district_id;
