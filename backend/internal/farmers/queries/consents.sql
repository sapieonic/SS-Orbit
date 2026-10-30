-- name: InsertConsent :exec
-- Consents are append-only. IDs derived from a sync command make a replay a no-op.
INSERT INTO consents (id, farmer_id, purpose, granted, method, captured_by_fa_id, notice_version, language, audio_played, created_at)
VALUES (@id, @farmer_id, @purpose, @granted, @method, sqlc.narg('captured_by_fa_id'), @notice_version, @language, @audio_played, @created_at)
ON CONFLICT (id) DO NOTHING;

-- name: GetConsent :one
SELECT * FROM consents WHERE id = $1;

-- name: CurrentConsents :many
-- The latest row per farmer and purpose is the current consent.
SELECT DISTINCT ON (farmer_id, purpose) *
FROM consents
WHERE farmer_id = ANY(@farmer_ids::uuid[])
ORDER BY farmer_id, purpose, created_at DESC, id DESC;

-- name: ConsentHistory :many
SELECT * FROM consents WHERE farmer_id = $1 ORDER BY created_at DESC, id DESC;
