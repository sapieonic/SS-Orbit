-- Platform tables shared by every module: audit log, rate-limit fallback,
-- FA territory versions (snapshot cache keys).

-- +goose Up
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- +goose StatementBegin
CREATE FUNCTION forbid_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME;
END
$$;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE FUNCTION touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END
$$;
-- +goose StatementEnd

-- Who did what, when, on which record (WF-01, NFR-07). Never updated or deleted.
CREATE TABLE audit_log (
  id           uuid PRIMARY KEY,
  occurred_at  timestamptz NOT NULL DEFAULT now(),
  actor_kind   text NOT NULL CHECK (actor_kind IN ('farmer', 'fa', 'ho', 'system')),
  actor_id     uuid,
  on_behalf_of uuid,                -- assisted mode: the farmer an FA acted for
  action       text NOT NULL,       -- '<module>.<verb>', e.g. 'farmers.enrolled'
  entity_type  text NOT NULL,
  entity_id    uuid,
  farmer_id    uuid,
  plot_id      uuid,
  season_id    uuid,
  before       jsonb,
  after        jsonb,
  meta         jsonb,
  ip           inet,
  device_id    text,
  request_id   text
);
CREATE INDEX audit_log_entity_idx ON audit_log (entity_type, entity_id, occurred_at DESC);
CREATE INDEX audit_log_actor_idx ON audit_log (actor_id, occurred_at DESC);
CREATE INDEX audit_log_farmer_idx ON audit_log (farmer_id, occurred_at DESC);
CREATE INDEX audit_log_time_idx ON audit_log (occurred_at DESC);
CREATE TRIGGER audit_log_append_only BEFORE UPDATE OR DELETE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- Fallback counters for rate limits when Redis is unavailable.
CREATE TABLE rate_limit_counters (
  key          text NOT NULL,
  window_start timestamptz NOT NULL,
  count        integer NOT NULL DEFAULT 0,
  PRIMARY KEY (key, window_start)
);

-- Bumped whenever data inside an FA's territory changes; part of the
-- territory snapshot cache key. No FK so any module can bump it.
CREATE TABLE territory_versions (
  fa_id      uuid PRIMARY KEY,
  version    bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE territory_versions;
DROP TABLE rate_limit_counters;
DROP TABLE audit_log;
DROP FUNCTION touch_updated_at();
DROP FUNCTION forbid_mutation();
