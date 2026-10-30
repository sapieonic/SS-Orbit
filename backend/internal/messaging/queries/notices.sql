-- name: InsertAdvisoryNotices :many
-- One notice per farmer for an advisory. UNIQUE (advisory_id, farmer_id) makes
-- a retried batch a no-op; only newly created rows are returned.
INSERT INTO notices (id, farmer_id, advisory_id, kind, sender, title_te, body_te, title_en, body_en, audio_key)
SELECT unnest(@ids::uuid[]), unnest(@farmer_ids::uuid[]), @advisory_id, 'advisory', @sender, @title_te, @body_te,
       sqlc.narg('title_en'), sqlc.narg('body_en'), sqlc.narg('audio_key')
ON CONFLICT (advisory_id, farmer_id) DO NOTHING
RETURNING id, farmer_id;

-- name: InsertRefNotice :one
-- A notice about some record (welcome, FA change, visit advice). Returns no
-- rows when the farmer already has a notice for (ref_type, ref_id).
INSERT INTO notices (id, farmer_id, kind, sender, title_te, body_te, title_en, body_en, ref_type, ref_id)
VALUES (@id, @farmer_id, @kind, @sender, @title_te, @body_te, sqlc.narg('title_en'), sqlc.narg('body_en'),
        @ref_type, @ref_id)
ON CONFLICT (farmer_id, ref_type, ref_id) WHERE advisory_id IS NULL AND ref_id IS NOT NULL DO NOTHING
RETURNING *;

-- name: GetNotice :one
SELECT * FROM notices WHERE id = @id;

-- name: ListFarmerNotices :many
-- A farmer's inbox, newest first, keyset on (created_at, id).
SELECT *
FROM notices
WHERE farmer_id = @farmer_id
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg('row_limit');

-- name: CountUnreadNotices :one
SELECT count(*)::int FROM notices WHERE farmer_id = @farmer_id AND read_at IS NULL;

-- name: MarkNoticeRead :one
-- Returns no rows if the notice is not the farmer's or was already read.
UPDATE notices SET read_at = @at
WHERE id = @id AND farmer_id = @farmer_id AND read_at IS NULL
RETURNING id;

-- name: MarkNoticeListened :one
-- Listening implies reading. Returns no rows if not the farmer's or already listened.
UPDATE notices SET listened_at = @at, read_at = COALESCE(read_at, @at)
WHERE id = @id AND farmer_id = @farmer_id AND listened_at IS NULL
RETURNING id;

-- name: ListAdvisoryRecipients :many
-- Who received an advisory (FAR-13), with each channel's delivery status.
SELECT n.id, n.farmer_id, n.created_at, n.read_at, n.listened_at,
       COALESCE((SELECT jsonb_agg(jsonb_build_object(
                   'channel', d.channel, 'status', d.status, 'error', d.error,
                   'sent_at', d.sent_at, 'attempts', d.attempts) ORDER BY d.channel)
                 FROM deliveries d WHERE d.notice_id = n.id), '[]')::jsonb AS deliveries
FROM notices n
WHERE n.advisory_id = @advisory_id
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (n.created_at, n.id) > (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY n.created_at, n.id
LIMIT sqlc.arg('row_limit');
