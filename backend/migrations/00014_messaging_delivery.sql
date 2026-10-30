-- Messaging additions on top of 00007:
--  * deliveries carry the exact text sent (rendered once, in the farmer's
--    language, at fan-out) and its DLT template, so the worker needs no
--    re-rendering and HO can see what went out.
--  * unique keys that make event subscribers idempotent (at-least-once delivery).
--  * advisory review fields.

-- +goose Up
ALTER TABLE advisories
  ADD COLUMN approved_at timestamptz,
  ADD COLUMN review_note text;

ALTER TABLE deliveries
  ADD COLUMN title       text,
  ADD COLUMN body        text NOT NULL DEFAULT '',
  ADD COLUMN template_id text,
  ADD CONSTRAINT deliveries_notice_channel_key UNIQUE (notice_id, channel);

-- System and visit notices (no advisory) are deduplicated by what they refer to.
CREATE UNIQUE INDEX notices_ref_key ON notices (farmer_id, ref_type, ref_id)
  WHERE advisory_id IS NULL AND ref_id IS NOT NULL;
CREATE INDEX notices_unread_idx ON notices (farmer_id) WHERE read_at IS NULL;

-- One alert per FA per kind per referenced record (farmer, callback, ...).
CREATE UNIQUE INDEX fa_alerts_ref_key ON fa_alerts (fa_id, kind, ref_id) WHERE ref_id IS NOT NULL;

-- One HO alert per kind per farmer.
CREATE UNIQUE INDEX ho_alerts_farmer_key ON ho_alerts (kind, farmer_id) WHERE farmer_id IS NOT NULL;
CREATE INDEX ho_alerts_district_idx ON ho_alerts (district_id, created_at DESC);

CREATE INDEX advisories_created_idx ON advisories (created_at DESC);

-- +goose Down
DROP INDEX advisories_created_idx;
DROP INDEX ho_alerts_district_idx;
DROP INDEX ho_alerts_farmer_key;
DROP INDEX fa_alerts_ref_key;
DROP INDEX notices_unread_idx;
DROP INDEX notices_ref_key;
ALTER TABLE deliveries
  DROP CONSTRAINT deliveries_notice_channel_key,
  DROP COLUMN template_id,
  DROP COLUMN body,
  DROP COLUMN title;
ALTER TABLE advisories
  DROP COLUMN review_note,
  DROP COLUMN approved_at;
