-- HO portal reads. Dates are IST calendar days (visit_details.visit_date).
-- scope_district_ids limits an HO user with an area scope (empty = all).

-- name: AdminListVisits :many
-- Newest first, keyset on (event_at, id). Every filter is optional.
SELECT *
FROM visit_details
WHERE (sqlc.narg('fa_id')::uuid IS NULL OR fa_id = sqlc.narg('fa_id'))
  AND (cardinality(sqlc.arg('scope_district_ids')::uuid[]) = 0 OR district_id = ANY (sqlc.arg('scope_district_ids')::uuid[]))
  AND (sqlc.narg('farmer_id')::uuid IS NULL OR farmer_id = sqlc.narg('farmer_id'))
  AND (sqlc.narg('status')::text IS NULL OR status = sqlc.narg('status'))
  AND (sqlc.narg('from_date')::date IS NULL OR visit_date >= sqlc.narg('from_date'))
  AND (sqlc.narg('to_date')::date IS NULL OR visit_date <= sqlc.narg('to_date'))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (event_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY event_at DESC, id DESC
LIMIT sqlc.arg('row_limit');

-- name: AdminListOverdue :many
-- Planned visits whose day has passed (missed, or still planned before the
-- nightly job ran). Most recent day first.
SELECT *
FROM visit_details
WHERE (status = 'missed' OR (status = 'planned' AND planned_for < sqlc.arg('today')::date))
  AND (cardinality(sqlc.arg('scope_district_ids')::uuid[]) = 0 OR district_id = ANY (sqlc.arg('scope_district_ids')::uuid[]))
  AND (sqlc.narg('fa_id')::uuid IS NULL OR fa_id = sqlc.narg('fa_id'))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (event_at, id) < (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY event_at DESC, id DESC
LIMIT sqlc.arg('row_limit');

-- name: SampleDoneVisits :many
-- A uniform random sample of logged visits for QA review.
SELECT *
FROM visit_details
WHERE status = 'done'
  AND (cardinality(sqlc.arg('scope_district_ids')::uuid[]) = 0 OR district_id = ANY (sqlc.arg('scope_district_ids')::uuid[]))
  AND visit_date BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date
  AND (sqlc.narg('fa_id')::uuid IS NULL OR fa_id = sqlc.narg('fa_id'))
ORDER BY random()
LIMIT sqlc.arg('size');

-- name: VisitCountsByFA :many
-- planned: visits scheduled for a day in the range (not cancelled).
-- done: visits logged on a day in the range. missed: scheduled in the range
-- and the day passed without a log. farmers_visited: distinct farmers in done.
SELECT fa_id,
       count(*) FILTER (WHERE status <> 'cancelled'
                          AND planned_for BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date)::integer AS planned,
       count(*) FILTER (WHERE status = 'done'
                          AND visit_date BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date)::integer AS done,
       count(*) FILTER (WHERE planned_for BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date
                          AND (status = 'missed' OR (status = 'planned' AND planned_for < sqlc.arg('today')::date)))::integer AS missed,
       count(DISTINCT farmer_id) FILTER (WHERE status = 'done'
                          AND visit_date BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date)::integer AS farmers_visited
FROM visit_details
WHERE (sqlc.narg('fa_id')::uuid IS NULL OR fa_id = sqlc.narg('fa_id'))
  AND (cardinality(sqlc.arg('scope_district_ids')::uuid[]) = 0 OR district_id = ANY (sqlc.arg('scope_district_ids')::uuid[]))
  AND (sqlc.narg('district_id')::uuid IS NULL OR district_id = sqlc.narg('district_id'))
  AND (planned_for BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date
       OR visit_date BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date)
GROUP BY fa_id
ORDER BY fa_id;

-- name: VisitCountsByDay :many
-- The overview chart: per day of [from_date, to_date] (every day, zero-filled),
-- summed over the matching FAs. Same definitions as VisitCountsByFA: planned
-- and missed by planned_for, done by visit_date.
WITH v AS (
  SELECT status, planned_for, visit_date FROM visit_details
  WHERE (sqlc.narg('fa_id')::uuid IS NULL OR fa_id = sqlc.narg('fa_id'))
    AND (cardinality(sqlc.arg('scope_district_ids')::uuid[]) = 0 OR district_id = ANY (sqlc.arg('scope_district_ids')::uuid[]))
    AND (sqlc.narg('district_id')::uuid IS NULL OR district_id = sqlc.narg('district_id'))
    AND (planned_for BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date
         OR visit_date BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date)
), p AS (
  SELECT planned_for AS day,
         count(*) FILTER (WHERE status <> 'cancelled') AS planned,
         count(*) FILTER (WHERE status = 'missed' OR (status = 'planned' AND planned_for < sqlc.arg('today')::date)) AS missed
  FROM v WHERE planned_for BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date
  GROUP BY planned_for
), d AS (
  SELECT visit_date AS day, count(*) AS done
  FROM v WHERE status = 'done' AND visit_date BETWEEN sqlc.arg('from_date')::date AND sqlc.arg('to_date')::date
  GROUP BY visit_date
)
SELECT g.day::date AS day,
       COALESCE(p.planned, 0)::integer AS planned,
       COALESCE(d.done, 0)::integer AS done,
       COALESCE(p.missed, 0)::integer AS missed
FROM generate_series(sqlc.arg('from_date')::date, sqlc.arg('to_date')::date, interval '1 day') AS g(day)
LEFT JOIN p ON p.day = g.day::date
LEFT JOIN d ON d.day = g.day::date
ORDER BY g.day;
