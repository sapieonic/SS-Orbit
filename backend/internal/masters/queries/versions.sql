-- name: GetMasterVersion :one
SELECT kind, version, updated_at FROM master_versions WHERE kind = $1;

-- name: BumpMasterVersion :one
-- Bumps the 'all' counter (created at 2 if the seed row is missing).
INSERT INTO master_versions (kind, version) VALUES ('all', 2)
ON CONFLICT (kind) DO UPDATE SET version = master_versions.version + 1, updated_at = now()
RETURNING kind, version, updated_at;
