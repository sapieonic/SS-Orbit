-- name: CreateRule :one
INSERT INTO advisory_rules (id, rule_key, version, issue_id, salt_id, sku_id, dose_per_acre, dose_per_acre_te,
                            status, change_note, created_by)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'draft', $9, $10)
RETURNING *;

-- name: GetRuleForUpdate :one
SELECT * FROM advisory_rules WHERE id = $1 FOR UPDATE;

-- name: GetLatestRuleVersionForUpdate :one
-- Latest version of a rule key, locked so concurrent drafts of one key queue up.
SELECT * FROM advisory_rules WHERE rule_key = $1 ORDER BY version DESC LIMIT 1 FOR UPDATE;

-- name: RuleKeysForIssueSalt :many
-- The rule key already used for an issue and salt (rejected-only keys don't count).
SELECT DISTINCT rule_key FROM advisory_rules
WHERE issue_id = sqlc.arg('issue_id') AND salt_id = sqlc.arg('salt_id') AND status <> 'rejected';

-- name: UpdateDraftRule :one
UPDATE advisory_rules SET
  salt_id = $2, sku_id = $3, dose_per_acre = $4, dose_per_acre_te = $5, change_note = $6
WHERE id = $1 AND status = 'draft'
RETURNING *;

-- name: SubmitRule :one
UPDATE advisory_rules SET submitted_at = sqlc.arg('submitted_at')::timestamptz, submitted_by = sqlc.arg('submitted_by')::uuid
WHERE id = sqlc.arg('id') AND status = 'draft'
RETURNING *;

-- name: SupersedeLiveRule :many
UPDATE advisory_rules SET status = 'superseded'
WHERE rule_key = $1 AND status = 'approved'
RETURNING id, version;

-- name: ApproveRule :one
UPDATE advisory_rules SET status = 'approved', approved_by = sqlc.arg('approved_by')::uuid,
  approved_at = sqlc.arg('approved_at')::timestamptz, review_note = sqlc.narg('review_note')
WHERE id = sqlc.arg('id') AND status = 'draft'
RETURNING *;

-- name: RejectRule :one
UPDATE advisory_rules SET status = 'rejected', rejected_by = sqlc.arg('rejected_by')::uuid,
  rejected_at = sqlc.arg('rejected_at')::timestamptz, review_note = sqlc.narg('review_note')
WHERE id = sqlc.arg('id') AND status = 'draft'
RETURNING *;

-- name: LiveRuleKeysUsingSalt :many
SELECT rule_key FROM advisory_rules WHERE salt_id = $1 AND status = 'approved';

-- name: LiveRuleKeysUsingSku :many
SELECT rule_key FROM advisory_rules WHERE sku_id = sqlc.arg('sku_id')::uuid AND status = 'approved';

-- name: ListRuleViews :many
-- Rules with issue, salt and product names. Every filter is optional; oldest
-- first, keyset on (created_at, id). Also used for one rule (rule_id) and for
-- every live rule (status = 'approved').
SELECT r.id, r.rule_key, r.version, r.issue_id, i.crop_id, i.type AS issue_type,
       i.name AS issue_name, i.name_te AS issue_name_te,
       r.salt_id, s.name AS salt_name, s.name_te AS salt_name_te,
       r.sku_id, k.code AS sku_code, k.product_name, k.product_name_te,
       r.dose_per_acre, r.dose_per_acre_te, r.status, r.change_note,
       r.created_by, r.created_at, r.submitted_by, r.submitted_at,
       r.approved_by, r.approved_at, r.rejected_by, r.rejected_at, r.review_note
FROM advisory_rules r
JOIN issues i ON i.id = r.issue_id
JOIN salts s ON s.id = r.salt_id
LEFT JOIN skus k ON k.id = r.sku_id
WHERE (sqlc.narg('rule_id')::uuid IS NULL OR r.id = sqlc.narg('rule_id'))
  AND (sqlc.narg('rule_key')::uuid IS NULL OR r.rule_key = sqlc.narg('rule_key'))
  AND (sqlc.narg('issue_id')::uuid IS NULL OR r.issue_id = sqlc.narg('issue_id'))
  AND (sqlc.narg('crop_id')::uuid IS NULL OR i.crop_id = sqlc.narg('crop_id'))
  AND (sqlc.narg('status')::text IS NULL OR r.status = sqlc.narg('status'))
  AND (sqlc.narg('cursor_at')::timestamptz IS NULL
       OR (r.created_at, r.id) > (sqlc.narg('cursor_at'), sqlc.narg('cursor_id')::uuid))
ORDER BY r.created_at, r.id
LIMIT sqlc.arg('row_limit');
