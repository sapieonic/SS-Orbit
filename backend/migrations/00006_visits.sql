-- Visits (planned and logged), issues found with the advice given, photos,
-- and farmer call-me-back requests.

-- +goose Up
CREATE TABLE visits (
  id                uuid PRIMARY KEY,           -- minted on the FA phone (UUIDv7)
  farmer_id         uuid NOT NULL,
  plot_id           uuid NOT NULL,
  season_id         uuid NOT NULL,
  fa_id             uuid NOT NULL REFERENCES field_assistants (id),
  status            text NOT NULL CHECK (status IN ('planned', 'done', 'cancelled', 'missed')),
  planned_for       date,
  planned_slot      text CHECK (planned_slot IN ('morning', 'afternoon', 'any')),
  purpose           text,
  visited_at        timestamptz,
  location          geography(Point, 4326),
  farmer_present    boolean,
  stage_id          uuid REFERENCES crop_stages (id),
  notes             text,
  client_created_at timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (season_id, plot_id, farmer_id) REFERENCES crop_seasons (id, plot_id, farmer_id),
  CHECK (status <> 'planned' OR planned_for IS NOT NULL),
  CHECK (status <> 'done' OR visited_at IS NOT NULL)
);
CREATE INDEX visits_fa_day_idx ON visits (fa_id, planned_for);
CREATE INDEX visits_farmer_idx ON visits (farmer_id, visited_at DESC);
CREATE INDEX visits_season_idx ON visits (season_id);
CREATE TRIGGER visits_touch BEFORE UPDATE ON visits FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- One row per issue found on a visit, with the salt-first advice (FA-08, FA-09).
CREATE TABLE visit_issues (
  id               uuid PRIMARY KEY,
  visit_id         uuid NOT NULL REFERENCES visits (id),
  farmer_id        uuid NOT NULL,
  plot_id          uuid NOT NULL,
  season_id        uuid NOT NULL,
  issue_id         uuid NOT NULL REFERENCES issues (id),
  severity         text NOT NULL CHECK (severity IN ('low', 'moderate', 'high')),
  advisory_rule_id uuid REFERENCES advisory_rules (id),  -- exact master version used (WF-02)
  salt_id          uuid NOT NULL REFERENCES salts (id),
  sku_id           uuid REFERENCES skus (id),            -- NULL = salt only, never a competitor brand
  dose_per_acre    text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (season_id, plot_id, farmer_id) REFERENCES crop_seasons (id, plot_id, farmer_id)
);
CREATE INDEX visit_issues_visit_idx ON visit_issues (visit_id);
CREATE INDEX visit_issues_farmer_idx ON visit_issues (farmer_id, created_at DESC);

CREATE TABLE visit_photos (
  id           uuid PRIMARY KEY,
  visit_id     uuid NOT NULL REFERENCES visits (id),
  storage_key  text NOT NULL UNIQUE,
  content_type text NOT NULL,
  bytes        integer,
  sha256       text,
  uploaded_at  timestamptz,        -- NULL until the phone has uploaded it
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX visit_photos_visit_idx ON visit_photos (visit_id);

-- "Ask your FA to call you back" (F3). Closes when the FA logs the call or a visit.
CREATE TABLE callback_requests (
  id           uuid PRIMARY KEY,
  farmer_id    uuid NOT NULL REFERENCES farmers (id),
  fa_id        uuid NOT NULL REFERENCES field_assistants (id),
  status       text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'cancelled')),
  note         text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  closed_at    timestamptz,
  closed_by    uuid
);
CREATE INDEX callback_requests_fa_idx ON callback_requests (fa_id) WHERE status = 'open';
CREATE UNIQUE INDEX callback_requests_one_open ON callback_requests (farmer_id) WHERE status = 'open';

-- +goose Down
DROP TABLE callback_requests;
DROP TABLE visit_photos;
DROP TABLE visit_issues;
DROP TABLE visits;
