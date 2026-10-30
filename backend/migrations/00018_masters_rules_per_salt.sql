-- Masters: several live advisory rules per issue, one per salt (FA-09).
--
-- FAs pick a salt from the approved list for an issue, and the app shows the
-- matching Shanmukha product if one exists. 00012 allowed one live rule per
-- issue; this allows one live rule per (issue, salt).
--
-- Down, read before rolling back:
-- * Issues with several live rules keep only the most recently approved one;
--   the others are marked superseded (visits keep pointing at them).
-- * 00012's Down re-adds UNIQUE (crop_id, seq) on crop_stages, which fails when
--   an inactive stage shares a seq with an active one. So this Down first moves
--   every inactive stage to a seq after the crop's highest seq (order kept).
--   Inactive stages are never shown, so only their seq numbers change.

-- +goose Up
DROP INDEX advisory_rules_one_live_per_issue;
CREATE UNIQUE INDEX advisory_rules_one_live_per_issue_salt ON advisory_rules (issue_id, salt_id) WHERE status = 'approved';

-- +goose Down
UPDATE advisory_rules r SET status = 'superseded'
WHERE r.status = 'approved'
  AND EXISTS (SELECT 1 FROM advisory_rules o
              WHERE o.issue_id = r.issue_id AND o.status = 'approved'
                AND (o.approved_at, o.id) > (r.approved_at, r.id));
DROP INDEX advisory_rules_one_live_per_issue_salt;
CREATE UNIQUE INDEX advisory_rules_one_live_per_issue ON advisory_rules (issue_id) WHERE status = 'approved';

UPDATE crop_stages s SET seq = n.new_seq
FROM (SELECT c.id,
             (SELECT max(a.seq) FROM crop_stages a WHERE a.crop_id = c.crop_id)
               + row_number() OVER (PARTITION BY c.crop_id ORDER BY c.seq, c.id) AS new_seq
      FROM crop_stages c
      WHERE NOT c.active) n
WHERE s.id = n.id;
