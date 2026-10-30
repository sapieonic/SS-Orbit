-- Masters: rule review workflow and stage history.
--
-- * Advisory rules get an explicit "submitted for approval" step and a record of
--   who rejected a draft and why (maker-checker, ADM-08).
-- * At most one open draft per rule_key, and at most one live rule per issue, so
--   ResolveAdvice(issue) has exactly one answer.
-- * Crop stages are never deleted (visits and seasons reference them): a stage
--   dropped from a crop's calendar is deactivated. seq is unique among active
--   stages only, so an inactive stage keeps its old seq.

-- +goose Up
ALTER TABLE advisory_rules
  ADD COLUMN submitted_at timestamptz,
  ADD COLUMN submitted_by uuid REFERENCES ho_users (id),
  ADD COLUMN rejected_at  timestamptz,
  ADD COLUMN rejected_by  uuid REFERENCES ho_users (id),
  ADD COLUMN review_note  text;
CREATE UNIQUE INDEX advisory_rules_one_draft ON advisory_rules (rule_key) WHERE status = 'draft';
CREATE UNIQUE INDEX advisory_rules_one_live_per_issue ON advisory_rules (issue_id) WHERE status = 'approved';

ALTER TABLE crop_stages ADD COLUMN active boolean NOT NULL DEFAULT true;
ALTER TABLE crop_stages DROP CONSTRAINT crop_stages_crop_id_seq_key;
CREATE UNIQUE INDEX crop_stages_active_seq ON crop_stages (crop_id, seq) WHERE active;

-- +goose Down
DROP INDEX crop_stages_active_seq;
ALTER TABLE crop_stages ADD CONSTRAINT crop_stages_crop_id_seq_key UNIQUE (crop_id, seq);
ALTER TABLE crop_stages DROP COLUMN active;

DROP INDEX advisory_rules_one_live_per_issue;
DROP INDEX advisory_rules_one_draft;
ALTER TABLE advisory_rules
  DROP COLUMN review_note,
  DROP COLUMN rejected_by,
  DROP COLUMN rejected_at,
  DROP COLUMN submitted_by,
  DROP COLUMN submitted_at;
