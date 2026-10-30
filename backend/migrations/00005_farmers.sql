-- Farmers, consents, plots and crop seasons: the farmer -> plot -> season spine.
-- Every farm record elsewhere carries farmer_id + plot_id + season_id (SYS-03),
-- enforced with composite foreign keys.

-- +goose Up
CREATE TABLE farmers (
  id                   uuid PRIMARY KEY,
  phone                text NOT NULL UNIQUE,      -- E.164, +91XXXXXXXXXX; self sign-up and FA enrolment merge on this
  name                 text,
  name_te              text,
  language             text NOT NULL DEFAULT 'te' CHECK (language IN ('te', 'en')),
  village_id           uuid REFERENCES villages (id),
  assigned_fa_id       uuid REFERENCES field_assistants (id),
  source               text NOT NULL CHECK (source IN ('self', 'fa', 'ho')),
  enrolled_by_fa_id    uuid REFERENCES field_assistants (id),
  photo_key            text,
  plan                 text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'premium')),
  status               text NOT NULL DEFAULT 'pending_profile' CHECK (status IN ('pending_profile', 'active', 'inactive')),
  profile_completed_at timestamptz,
  version              integer NOT NULL DEFAULT 1,  -- optimistic concurrency for offline edits
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX farmers_village_idx ON farmers (village_id);
CREATE INDEX farmers_fa_idx ON farmers (assigned_fa_id);
CREATE INDEX farmers_name_trgm ON farmers USING gin (name gin_trgm_ops);
CREATE TRIGGER farmers_touch BEFORE UPDATE ON farmers FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- Consent history, per purpose and partner (FAR-04, INT-01). Latest row per purpose is current.
CREATE TABLE consents (
  id                uuid PRIMARY KEY,
  farmer_id         uuid NOT NULL REFERENCES farmers (id),
  purpose           text NOT NULL CHECK (purpose IN ('programme', 'soil_partner', 'schemes_finance', 'loyalty')),
  granted           boolean NOT NULL,
  method            text NOT NULL CHECK (method IN ('app', 'fa_otp', 'ho')),
  captured_by_fa_id uuid REFERENCES field_assistants (id),
  notice_version    text NOT NULL,
  language          text NOT NULL CHECK (language IN ('te', 'en')),
  audio_played      boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX consents_farmer_idx ON consents (farmer_id, purpose, created_at DESC);
CREATE TRIGGER consents_append_only BEFORE UPDATE OR DELETE ON consents
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE plots (
  id               uuid PRIMARY KEY,
  farmer_id        uuid NOT NULL REFERENCES farmers (id),
  label            text NOT NULL,             -- 'Plot 1'
  village_id       uuid REFERENCES villages (id),
  boundary         geography(Polygon, 4326),  -- walked with GPS
  pin              geography(Point, 4326),    -- fallback when GPS is poor
  area_acres       numeric(8, 3) NOT NULL CHECK (area_acres > 0),  -- 40 guntas = 1 acre
  area_source      text NOT NULL CHECK (area_source IN ('boundary', 'typed')),
  gps_accuracy_m   numeric(6, 1),
  status           text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  version          integer NOT NULL DEFAULT 1,
  created_by_fa_id uuid REFERENCES field_assistants (id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, farmer_id),
  CHECK (boundary IS NOT NULL OR pin IS NOT NULL)
);
CREATE INDEX plots_farmer_idx ON plots (farmer_id);
CREATE INDEX plots_boundary_idx ON plots USING gist (boundary);
CREATE INDEX plots_pin_idx ON plots USING gist (pin);
CREATE TRIGGER plots_touch BEFORE UPDATE ON plots FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE crop_seasons (
  id               uuid PRIMARY KEY,
  farmer_id        uuid NOT NULL,
  plot_id          uuid NOT NULL,
  season_code      text NOT NULL,             -- 'rabi-2026-27', 'kharif-2027'
  crop_id          uuid NOT NULL REFERENCES crops (id),
  sowing_date      date,
  previous_crop_id uuid REFERENCES crops (id),
  current_stage_id uuid REFERENCES crop_stages (id),
  stage_updated_at timestamptz,
  status           text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'harvested', 'abandoned')),
  version          integer NOT NULL DEFAULT 1,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (plot_id, farmer_id) REFERENCES plots (id, farmer_id),
  UNIQUE (id, plot_id, farmer_id)
);
CREATE UNIQUE INDEX crop_seasons_one_active ON crop_seasons (plot_id) WHERE status = 'active';
CREATE INDEX crop_seasons_farmer_idx ON crop_seasons (farmer_id);
CREATE TRIGGER crop_seasons_touch BEFORE UPDATE ON crop_seasons FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- +goose Down
DROP TABLE crop_seasons;
DROP TABLE plots;
DROP TABLE consents;
DROP TABLE farmers;
