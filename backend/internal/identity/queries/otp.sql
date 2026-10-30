-- name: CreateOTPChallenge :exec
-- purpose 'login' (farmer sign-in) or 'consent' (FAR-04, fa_id = the FA asking).
INSERT INTO otp_challenges (id, phone, purpose, fa_id, code_hash, max_attempts, expires_at, ip)
VALUES (@id, @phone, @purpose, sqlc.narg('fa_id'), @code_hash, @max_attempts, @expires_at, sqlc.narg('ip'));

-- name: LatestOTPChallengeForUpdate :one
-- Only the newest challenge for a phone and purpose counts: a resend
-- invalidates older codes.
SELECT *
FROM otp_challenges
WHERE phone = @phone AND purpose = @purpose
ORDER BY created_at DESC, id DESC
LIMIT 1
FOR UPDATE;

-- name: IncrementOTPAttempts :one
UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = @id
RETURNING attempts;

-- name: ConsumeOTPChallenge :exec
UPDATE otp_challenges SET consumed_at = @consumed_at WHERE id = @id AND consumed_at IS NULL;

-- name: DeleteOldOTPChallenges :exec
-- Housekeeping on each send: old challenges for this phone are no longer useful.
DELETE FROM otp_challenges WHERE phone = @phone AND created_at < @before;

-- name: PurgeOTPChallenges :execrows
-- Retention (maintenance job): codes are worthless after a day.
DELETE FROM otp_challenges WHERE created_at < @before;
