-- Masters: crops and stages, issues, salts, Shanmukha SKUs, the versioned
-- issue -> salt -> product rules, and dealers. Changes reach apps without a release (ADM-08).

-- +goose Up
CREATE TABLE crops (
  id            uuid PRIMARY KEY,
  code          text NOT NULL UNIQUE,     -- 'cotton', 'paddy', 'chilli'
  name          text NOT NULL,
  name_te       text NOT NULL,
  duration_days integer,
  active        boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE crop_stages (
  id        uuid PRIMARY KEY,
  crop_id   uuid NOT NULL REFERENCES crops (id),
  code      text NOT NULL,                -- 'seedling', 'square', 'flowering', 'boll', 'picking'
  name      text NOT NULL,
  name_te   text NOT NULL,
  seq       integer NOT NULL,
  start_day integer NOT NULL,             -- days after sowing
  end_day   integer NOT NULL,
  UNIQUE (crop_id, code),
  UNIQUE (crop_id, seq),
  CHECK (end_day >= start_day)
);

CREATE TABLE salts (
  id         uuid PRIMARY KEY,
  name       text NOT NULL UNIQUE,        -- active ingredient, e.g. 'Mancozeb 75% WP'
  name_te    text,
  active     boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Shanmukha products only. Competitor brands are never stored (FA-09).
CREATE TABLE skus (
  id                uuid PRIMARY KEY,
  code              text NOT NULL UNIQUE,  -- 'SH-EB-250'
  product_name      text NOT NULL,
  product_name_te   text,
  salt_id           uuid NOT NULL REFERENCES salts (id),
  pack_size         text NOT NULL,         -- '250 g'
  mrp_paise         bigint NOT NULL CHECK (mrp_paise > 0),
  cashback_eligible boolean NOT NULL DEFAULT true,
  active            boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER skus_touch BEFORE UPDATE ON skus FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE issues (
  id         uuid PRIMARY KEY,
  crop_id    uuid NOT NULL REFERENCES crops (id),
  type       text NOT NULL CHECK (type IN ('pest', 'disease', 'deficiency')),
  name       text NOT NULL,
  name_te    text NOT NULL,
  active     boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (crop_id, name)
);

-- Issue -> salt -> product rule. Every change is a new version; one approved
-- version per rule_key is live. Advice stores the exact version used (WF-02).
CREATE TABLE advisory_rules (
  id               uuid PRIMARY KEY,
  rule_key         uuid NOT NULL,          -- stable identity across versions
  version          integer NOT NULL,
  issue_id         uuid NOT NULL REFERENCES issues (id),
  salt_id          uuid NOT NULL REFERENCES salts (id),
  sku_id           uuid REFERENCES skus (id),  -- NULL means "salt only"
  dose_per_acre    text NOT NULL,
  dose_per_acre_te text NOT NULL,
  status           text NOT NULL CHECK (status IN ('draft', 'approved', 'superseded', 'rejected')),
  change_note      text,
  created_by       uuid NOT NULL REFERENCES ho_users (id),
  approved_by      uuid REFERENCES ho_users (id),
  approved_at      timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (rule_key, version),
  CHECK (status NOT IN ('approved', 'superseded') OR approved_by IS NOT NULL)
);
CREATE UNIQUE INDEX advisory_rules_one_live ON advisory_rules (rule_key) WHERE status = 'approved';
CREATE INDEX advisory_rules_issue_idx ON advisory_rules (issue_id) WHERE status = 'approved';

CREATE TABLE dealers (
  id         uuid PRIMARY KEY,
  name       text NOT NULL,
  name_te    text,
  phone      text,
  village_id uuid REFERENCES villages (id),
  location   geography(Point, 4326),
  status     text NOT NULL DEFAULT 'to_verify' CHECK (status IN ('active', 'to_verify', 'inactive')),
  source     text NOT NULL DEFAULT 'ho' CHECK (source IN ('ho', 'farmer_bill')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX dealers_location_idx ON dealers USING gist (location);
CREATE TRIGGER dealers_touch BEFORE UPDATE ON dealers FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE dealer_skus (
  dealer_id uuid NOT NULL REFERENCES dealers (id),
  sku_id    uuid NOT NULL REFERENCES skus (id),
  PRIMARY KEY (dealer_id, sku_id)
);

-- Version counter per master kind; part of the masters snapshot ETag and cache key.
CREATE TABLE master_versions (
  kind       text PRIMARY KEY,             -- 'all' is bumped on every publish
  version    bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO master_versions (kind, version) VALUES ('all', 1);

-- +goose Down
DROP TABLE master_versions;
DROP TABLE dealer_skus;
DROP TABLE dealers;
DROP TABLE advisory_rules;
DROP TABLE issues;
DROP TABLE skus;
DROP TABLE salts;
DROP TABLE crop_stages;
DROP TABLE crops;
