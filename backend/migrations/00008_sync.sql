-- FA offline sync: every command the phone sends is stored once, keyed by the
-- command ID minted on the phone, so retries return the stored result.

-- +goose Up
CREATE TABLE sync_commands (
  id                uuid PRIMARY KEY,   -- client command ID = idempotency key
  fa_id             uuid NOT NULL REFERENCES field_assistants (id),
  device_id         uuid REFERENCES devices (id),
  type              text NOT NULL,
  payload           jsonb NOT NULL,
  status            text NOT NULL CHECK (status IN ('applied', 'merged', 'conflict', 'rejected')),
  result            jsonb NOT NULL,
  client_created_at timestamptz,
  received_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sync_commands_fa_idx ON sync_commands (fa_id, received_at DESC);

-- +goose Down
DROP TABLE sync_commands;
