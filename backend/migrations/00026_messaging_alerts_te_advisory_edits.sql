-- FA alerts in Telugu, and who last edited an advisory draft.
--
-- fa_alerts.title_te/body_te: the FA app shows (and pushes) alerts in the FA's
-- first language; title/body stay the English text. NULL for alerts created
-- before this migration and for HO notes written in one language only.
--
-- advisories.updated_by: the HO user who last edited the draft. The approver
-- must be neither the author nor the last editor (maker-checker), so editing
-- someone else's draft does not let you approve it yourself.

-- +goose Up
ALTER TABLE fa_alerts ADD COLUMN title_te text, ADD COLUMN body_te text;
ALTER TABLE advisories ADD COLUMN updated_by uuid REFERENCES ho_users (id);

-- +goose Down
ALTER TABLE advisories DROP COLUMN updated_by;
ALTER TABLE fa_alerts DROP COLUMN title_te, DROP COLUMN body_te;
