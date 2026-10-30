-- name: InsertDeliveries :many
-- Delivery rows for notices, one per channel. UNIQUE (notice_id, channel)
-- makes retries no-ops; only new rows are returned (their jobs get enqueued).
-- Empty titles are stored as NULL.
INSERT INTO deliveries (id, notice_id, farmer_id, channel, scheduled_for, title, body, template_id)
SELECT d.id, d.notice_id, d.farmer_id, d.channel, d.scheduled_for, NULLIF(d.title, ''), d.body, NULLIF(d.template_id, '')
FROM (SELECT unnest(@ids::uuid[])                  AS id,
             unnest(@notice_ids::uuid[])           AS notice_id,
             unnest(@farmer_ids::uuid[])           AS farmer_id,
             unnest(@channels::text[])             AS channel,
             unnest(@scheduled_fors::timestamptz[]) AS scheduled_for,
             unnest(@titles::text[])               AS title,
             unnest(@bodies::text[])               AS body,
             unnest(@template_ids::text[])         AS template_id) AS d
ON CONFLICT (notice_id, channel) DO NOTHING
RETURNING id, scheduled_for;

-- name: GetDelivery :one
SELECT * FROM deliveries WHERE id = @id;

-- name: UpdateDeliveryResult :exec
UPDATE deliveries
SET status       = @status,
    attempts     = @attempts,
    provider_ref = sqlc.narg('provider_ref'),
    error        = sqlc.narg('error'),
    sent_at      = sqlc.narg('sent_at')
WHERE id = @id;

-- name: GetDeliveryClass :one
-- The message class of a delivery: its advisory's class, or service for
-- system and visit notices.
SELECT COALESCE(a.class, 'service')::text AS class
FROM deliveries d
LEFT JOIN notices n ON n.id = d.notice_id
LEFT JOIN advisories a ON a.id = n.advisory_id
WHERE d.id = @id;
