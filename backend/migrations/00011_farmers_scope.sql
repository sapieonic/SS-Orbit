-- Farmers module additions (farmers owns every table touched here).
--
-- * farmers.mandal_id / district_id: copied from geo when the village is set, so
--   area filters, advisory targeting and the HO district scope are answered from
--   the farmers tables without reading geo's tables.
-- * last_command_id: the sync command that last wrote the row, so a replayed
--   command is recognised and answered without writing twice.
-- * farmer_aliases: an FA enrolment made offline carries a phone-generated
--   farmer_id. When the phone number already belongs to a farmer the enrolment
--   is merged, and the phone's ID is kept here so the SavePlot/StartSeason
--   commands that follow it in the same batch still find the farmer.

-- +goose Up
ALTER TABLE farmers
  ADD COLUMN mandal_id       uuid REFERENCES mandals (id),
  ADD COLUMN district_id     uuid REFERENCES districts (id),
  ADD COLUMN last_command_id uuid;
CREATE INDEX farmers_list_idx ON farmers (created_at DESC, id DESC);
CREATE INDEX farmers_district_idx ON farmers (district_id);
CREATE INDEX farmers_mandal_idx ON farmers (mandal_id);

ALTER TABLE plots ADD COLUMN last_command_id uuid;

ALTER TABLE crop_seasons ADD COLUMN last_command_id uuid;
CREATE INDEX crop_seasons_code_active_idx ON crop_seasons (season_code) WHERE status = 'active';

CREATE TABLE farmer_aliases (
  alias_id   uuid PRIMARY KEY,                       -- the farmer_id the FA phone generated
  farmer_id  uuid NOT NULL REFERENCES farmers (id),  -- the farmer it was merged into
  command_id uuid NOT NULL,                          -- the EnrolFarmer command that merged it
  fa_id      uuid REFERENCES field_assistants (id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX farmer_aliases_farmer_idx ON farmer_aliases (farmer_id);

-- +goose Down
DROP TABLE farmer_aliases;
DROP INDEX crop_seasons_code_active_idx;
ALTER TABLE crop_seasons DROP COLUMN last_command_id;
ALTER TABLE plots DROP COLUMN last_command_id;
DROP INDEX farmers_mandal_idx;
DROP INDEX farmers_district_idx;
DROP INDEX farmers_list_idx;
ALTER TABLE farmers
  DROP COLUMN last_command_id,
  DROP COLUMN district_id,
  DROP COLUMN mandal_id;
