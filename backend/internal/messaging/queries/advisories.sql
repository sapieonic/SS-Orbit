-- name: CreateAdvisory :one
INSERT INTO advisories (id, sender, title_te, body_te, title_en, body_en, audio_key, image_key,
                        names_product, class, target, channels, status, created_by)
VALUES (@id, @sender, @title_te, @body_te, sqlc.narg('title_en'), sqlc.narg('body_en'),
        sqlc.narg('audio_key'), sqlc.narg('image_key'), @names_product, @class, @target, @channels,
        'draft', @created_by)
RETURNING *;

-- name: GetAdvisory :one
SELECT * FROM advisories WHERE id = @id;

-- name: GetAdvisoryForUpdate :one
SELECT * FROM advisories WHERE id = @id FOR UPDATE;

-- name: UpdateAdvisoryContent :one
-- Edits a draft's content after the service checked it on a row read FOR UPDATE.
UPDATE advisories
SET sender        = @sender,
    title_te      = @title_te,
    body_te       = @body_te,
    title_en      = sqlc.narg('title_en'),
    body_en       = sqlc.narg('body_en'),
    audio_key     = sqlc.narg('audio_key'),
    image_key     = sqlc.narg('image_key'),
    names_product = @names_product,
    class         = @class,
    target        = @target,
    channels      = @channels,
    updated_by    = @updated_by
WHERE id = @id
RETURNING *;

-- name: UpdateAdvisoryState :one
-- Writes the workflow fields after the service changed them on a row read FOR UPDATE.
UPDATE advisories
SET status          = @status,
    scheduled_for   = sqlc.narg('scheduled_for'),
    sent_at         = sqlc.narg('sent_at'),
    recipient_count = sqlc.narg('recipient_count'),
    approved_by     = sqlc.narg('approved_by'),
    approved_at     = sqlc.narg('approved_at'),
    review_note     = sqlc.narg('review_note')
WHERE id = @id
RETURNING *;

-- name: ListAdvisories :many
-- Newest first, keyset on (created_at, id). scope_district_ids (an HO area
-- scope) keeps only advisories whose target names districts, all inside the scope.
SELECT *
FROM advisories
WHERE (sqlc.narg('status')::text IS NULL OR status = sqlc.narg('status'))
  AND (sqlc.narg('scope_district_ids')::uuid[] IS NULL
       OR (jsonb_typeof(target->'district_ids') = 'array'
           AND jsonb_array_length(target->'district_ids') > 0
           AND NOT EXISTS (
             SELECT 1 FROM jsonb_array_elements_text(target->'district_ids') AS d(id)
             WHERE d.id::uuid <> ALL (sqlc.narg('scope_district_ids')::uuid[]))))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (created_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg('row_limit');

-- name: AdvisoryStats :one
-- Reach of one advisory: notices created, read and listened, and deliveries by status.
SELECT
  (SELECT count(*) FROM notices n WHERE n.advisory_id = @id)::int                              AS notices,
  (SELECT count(*) FROM notices n WHERE n.advisory_id = @id AND n.read_at IS NOT NULL)::int     AS read,
  (SELECT count(*) FROM notices n WHERE n.advisory_id = @id AND n.listened_at IS NOT NULL)::int AS listened,
  COALESCE((SELECT jsonb_object_agg(k, c) FROM (
     SELECT d.channel || '.' || d.status AS k, count(*) AS c
     FROM deliveries d JOIN notices n ON n.id = d.notice_id
     WHERE n.advisory_id = @id
     GROUP BY d.channel, d.status) s), '{}')::jsonb                                             AS deliveries;
