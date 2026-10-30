-- Farmers: a record of every applied EnrolFarmer command.
--
-- EnrolFarmer used to recognise a replay by the consent rows it wrote (their IDs
-- are derived from the command ID). An enrolment without a valid consent proof
-- (FAR-04) now writes no consent rows, so replays are recognised here instead.
-- phone_farmer_id is the farmer_id the FA phone minted; farmer_id is the farmer
-- it ended up as (the same ID, or the farmer it was merged into).

-- +goose Up
CREATE TABLE farmer_enrolments (
  command_id       uuid PRIMARY KEY,
  farmer_id        uuid NOT NULL REFERENCES farmers (id),
  phone_farmer_id  uuid NOT NULL,
  fa_id            uuid NOT NULL REFERENCES field_assistants (id),
  consent_recorded boolean NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX farmer_enrolments_farmer_idx ON farmer_enrolments (farmer_id);

-- +goose Down
DROP TABLE farmer_enrolments;
