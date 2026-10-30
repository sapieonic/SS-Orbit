-- Visits: snapshot the advice text given on a visit, plus a read view.
--
-- visit_issues already keeps the exact rule, salt and SKU IDs (WF-02). The
-- farmer's visit history, the HO detail page and the visit.logged notice must
-- show what was said in Telugu and English without reading masters tables, and
-- must keep showing it after the rule is superseded, so the names and doses are
-- copied here at log time. visits gets the stage name for the same reason.

-- +goose Up
ALTER TABLE visits
  ADD COLUMN stage_name    text,
  ADD COLUMN stage_name_te text;

ALTER TABLE visit_issues
  ADD COLUMN rule_version     integer,
  ADD COLUMN issue_name       text,
  ADD COLUMN issue_name_te    text,
  ADD COLUMN salt_name        text,
  ADD COLUMN salt_name_te     text,
  ADD COLUMN product_name     text,  -- Shanmukha product only; NULL = salt only
  ADD COLUMN product_name_te  text,
  ADD COLUMN dose_per_acre_te text;

-- Planned visits by date: the missed-visit job and the HO overdue view.
CREATE INDEX visits_planned_idx ON visits (planned_for) WHERE status = 'planned';
-- Logged visits by time: HO sampling and per-FA counts.
CREATE INDEX visits_done_idx ON visits (visited_at) WHERE status = 'done';

-- visit_details is visits as the service reads it: location as GeoJSON text
-- (sqlc cannot map geography), the visit's calendar day in IST and a sort key.
--   visit_date: day it was visited (IST) or, if not visited, the planned day.
--   event_at:   visited_at, or IST midnight of planned_for.
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

-- +goose Down
DROP VIEW visit_details;
DROP INDEX visits_done_idx;
DROP INDEX visits_planned_idx;
ALTER TABLE visit_issues
  DROP COLUMN dose_per_acre_te,
  DROP COLUMN product_name_te,
  DROP COLUMN product_name,
  DROP COLUMN salt_name_te,
  DROP COLUMN salt_name,
  DROP COLUMN issue_name_te,
  DROP COLUMN issue_name,
  DROP COLUMN rule_version;
ALTER TABLE visits
  DROP COLUMN stage_name_te,
  DROP COLUMN stage_name;
