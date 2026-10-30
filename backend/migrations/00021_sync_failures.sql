-- Sync dead-letter: infrastructure failures per command ID. A command that
-- keeps failing on the server (not the phone's fault, but not fixable by a
-- retry either) is stored as rejected after a few attempts so the FA's queue
-- moves on instead of blocking forever behind it.

-- +goose Up
CREATE TABLE sync_command_failures (
  id         uuid PRIMARY KEY,   -- the command ID (not yet in sync_commands)
  fa_id      uuid NOT NULL REFERENCES field_assistants (id),
  type       text NOT NULL,
  attempts   int NOT NULL CHECK (attempts > 0),
  last_error text NOT NULL,
  first_at   timestamptz NOT NULL,
  last_at    timestamptz NOT NULL
);
CREATE INDEX sync_command_failures_last_idx ON sync_command_failures (last_at);

-- +goose Down
DROP TABLE sync_command_failures;
