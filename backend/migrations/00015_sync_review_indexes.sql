-- +goose Up
-- HO review of stored sync commands (GET /v1/admin/sync/commands) lists newest
-- first across all FAs, usually narrowed to conflicts and rejections.
CREATE INDEX sync_commands_received_idx ON sync_commands (received_at DESC, id DESC);
CREATE INDEX sync_commands_review_idx ON sync_commands (status, received_at DESC, id DESC)
  WHERE status IN ('conflict', 'rejected');

-- +goose Down
DROP INDEX sync_commands_review_idx;
DROP INDEX sync_commands_received_idx;
