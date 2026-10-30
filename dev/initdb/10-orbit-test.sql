-- Runs once, on first start of an empty data volume.
-- The postgis image already installs PostGIS into the main `orbit` database
-- (and template_postgis); add the other extensions there and create `orbit_test`
-- for integration tests (TEST_DATABASE_URL).
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE DATABASE orbit_test OWNER orbit;
\connect orbit_test
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
