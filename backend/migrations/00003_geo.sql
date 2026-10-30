-- Geo hierarchy (district -> mandal -> village, LGD codes) and FA allocation.
-- Allocation drives "Look for FAs", "Farmers near me" and new-farmer alert routing (ADM-04).

-- +goose Up
CREATE TABLE districts (
  id         uuid PRIMARY KEY,
  lgd_code   text UNIQUE,
  name       text NOT NULL UNIQUE,
  name_te    text,
  state      text NOT NULL DEFAULT 'Telangana',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE mandals (
  id          uuid PRIMARY KEY,
  district_id uuid NOT NULL REFERENCES districts (id),
  lgd_code    text UNIQUE,
  name        text NOT NULL,
  name_te     text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (district_id, name)
);

CREATE TABLE villages (
  id         uuid PRIMARY KEY,
  mandal_id  uuid NOT NULL REFERENCES mandals (id),
  lgd_code   text UNIQUE,
  name       text NOT NULL,
  name_te    text,
  centroid   geography(Point, 4326),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (mandal_id, name)
);
CREATE INDEX villages_mandal_idx ON villages (mandal_id);
CREATE INDEX villages_name_trgm ON villages USING gin (name gin_trgm_ops);

-- An FA covers an area at one level. valid_to IS NULL means current.
CREATE TABLE fa_allocations (
  id          uuid PRIMARY KEY,
  fa_id       uuid NOT NULL REFERENCES field_assistants (id),
  level       text NOT NULL CHECK (level IN ('village', 'mandal', 'district')),
  village_id  uuid REFERENCES villages (id),
  mandal_id   uuid REFERENCES mandals (id),
  district_id uuid REFERENCES districts (id),
  is_lead     boolean NOT NULL DEFAULT true,
  valid_from  timestamptz NOT NULL DEFAULT now(),
  valid_to    timestamptz,
  created_by  uuid REFERENCES ho_users (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (level = 'village'  AND village_id IS NOT NULL AND mandal_id IS NULL AND district_id IS NULL) OR
    (level = 'mandal'   AND mandal_id IS NOT NULL AND village_id IS NULL AND district_id IS NULL) OR
    (level = 'district' AND district_id IS NOT NULL AND village_id IS NULL AND mandal_id IS NULL)
  )
);
CREATE INDEX fa_allocations_fa_idx ON fa_allocations (fa_id) WHERE valid_to IS NULL;
CREATE UNIQUE INDEX fa_allocations_village_lead ON fa_allocations (village_id) WHERE valid_to IS NULL AND is_lead AND level = 'village';
CREATE UNIQUE INDEX fa_allocations_mandal_lead ON fa_allocations (mandal_id) WHERE valid_to IS NULL AND is_lead AND level = 'mandal';
CREATE UNIQUE INDEX fa_allocations_district_lead ON fa_allocations (district_id) WHERE valid_to IS NULL AND is_lead AND level = 'district';

-- +goose Down
DROP TABLE fa_allocations;
DROP TABLE villages;
DROP TABLE mandals;
DROP TABLE districts;
