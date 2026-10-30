-- Advisories, the farmer inbox ("My Crop Advisory"), per-channel deliveries,
-- FA alerts and HO alerts.

-- +goose Up
CREATE TABLE advisories (
  id              uuid PRIMARY KEY,
  sender          text NOT NULL CHECK (sender IN ('ho', 'civ')),
  title_te        text NOT NULL,
  body_te         text NOT NULL,
  title_en        text,
  body_en         text,
  audio_key       text,
  image_key       text,
  names_product   boolean NOT NULL DEFAULT false,   -- true needs Agronomy approval and is promotional
  class           text NOT NULL CHECK (class IN ('service', 'promotional')),
  target          jsonb NOT NULL,   -- {crop_ids, district_ids, mandal_ids, village_ids, stage_codes, plan}
  channels        text[] NOT NULL,  -- subset of push, sms, whatsapp, in_app
  status          text NOT NULL CHECK (status IN ('draft', 'pending_approval', 'scheduled', 'sending', 'sent', 'cancelled')),
  scheduled_for   timestamptz,
  sent_at         timestamptz,
  recipient_count integer,
  created_by      uuid NOT NULL REFERENCES ho_users (id),
  approved_by     uuid REFERENCES ho_users (id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER advisories_touch BEFORE UPDATE ON advisories FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- One row per farmer per notice; tagged to the farmer ID (FAR-12, FAR-13).
CREATE TABLE notices (
  id           uuid PRIMARY KEY,
  farmer_id    uuid NOT NULL REFERENCES farmers (id),
  advisory_id  uuid REFERENCES advisories (id),
  kind         text NOT NULL CHECK (kind IN ('advisory', 'visit_advice', 'system')),
  sender       text NOT NULL CHECK (sender IN ('ho', 'civ', 'fa', 'system')),
  title_te     text NOT NULL,
  body_te      text NOT NULL,
  title_en     text,
  body_en      text,
  audio_key    text,
  ref_type     text,
  ref_id       uuid,
  pinned       boolean NOT NULL DEFAULT false,
  read_at      timestamptz,
  listened_at  timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (advisory_id, farmer_id)
);
CREATE INDEX notices_farmer_idx ON notices (farmer_id, created_at DESC);

CREATE TABLE deliveries (
  id            uuid PRIMARY KEY,
  notice_id     uuid REFERENCES notices (id),
  farmer_id     uuid NOT NULL REFERENCES farmers (id),
  channel       text NOT NULL CHECK (channel IN ('push', 'sms', 'whatsapp')),
  status        text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'sent', 'delivered', 'failed', 'skipped')),
  provider_ref  text,
  error         text,
  attempts      integer NOT NULL DEFAULT 0,
  scheduled_for timestamptz,
  sent_at       timestamptz,
  delivered_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX deliveries_notice_idx ON deliveries (notice_id);
CREATE INDEX deliveries_status_idx ON deliveries (status, scheduled_for);
CREATE TRIGGER deliveries_touch BEFORE UPDATE ON deliveries FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- FA app "Alerts" tab: new farmer, call me back, invoice to check, HO note.
CREATE TABLE fa_alerts (
  id              uuid PRIMARY KEY,
  fa_id           uuid NOT NULL REFERENCES field_assistants (id),
  kind            text NOT NULL CHECK (kind IN ('new_farmer', 'callback', 'invoice_check', 'ho_note')),
  farmer_id       uuid REFERENCES farmers (id),
  ref_id          uuid,
  title           text NOT NULL,
  body            text,
  status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'closed')),
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  closed_at       timestamptz
);
CREATE INDEX fa_alerts_fa_idx ON fa_alerts (fa_id, created_at DESC) WHERE status <> 'closed';

-- HO overview "New farmers" and other HO-facing alerts (ADM-02).
CREATE TABLE ho_alerts (
  id          uuid PRIMARY KEY,
  kind        text NOT NULL CHECK (kind IN ('new_farmer', 'farmer_without_fa', 'fa_offline')),
  farmer_id   uuid REFERENCES farmers (id),
  fa_id       uuid REFERENCES field_assistants (id),
  district_id uuid REFERENCES districts (id),
  payload     jsonb NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ho_alerts_time_idx ON ho_alerts (created_at DESC);

-- +goose Down
DROP TABLE ho_alerts;
DROP TABLE fa_alerts;
DROP TABLE deliveries;
DROP TABLE notices;
DROP TABLE advisories;
