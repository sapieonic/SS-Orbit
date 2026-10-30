-- fa_offline HO alerts have no farmer, so the (kind, farmer_id) key from 00014
-- does not apply to them. alert_day (IST date) keys them: one alert per FA per
-- day, so the hourly check is idempotent.

-- +goose Up
ALTER TABLE ho_alerts ADD COLUMN alert_day date;
CREATE UNIQUE INDEX ho_alerts_fa_day_key ON ho_alerts (fa_id, alert_day)
  WHERE kind = 'fa_offline';
ALTER TABLE ho_alerts ADD CONSTRAINT ho_alerts_fa_offline_shape
  CHECK (kind <> 'fa_offline' OR (fa_id IS NOT NULL AND alert_day IS NOT NULL));

-- +goose Down
ALTER TABLE ho_alerts DROP CONSTRAINT ho_alerts_fa_offline_shape;
DROP INDEX ho_alerts_fa_day_key;
ALTER TABLE ho_alerts DROP COLUMN alert_day;
