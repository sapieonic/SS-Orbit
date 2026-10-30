package identity

import (
	"context"
	"crypto/hmac"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
)

// OTP challenge purposes (otp_challenges.purpose). A code is only good for the
// purpose it was sent for.
const (
	otpPurposeLogin   = "login"   // farmer sign-in
	otpPurposeConsent = "consent" // farmer agrees to join, read out to an FA (FAR-04)
)

// newOTPChallenge stores a new code for (phone, purpose), replacing older
// ones, and returns the code to send. faID is the FA asking (consent only).
// inTx, if set, runs in the same transaction (audit).
func (s *Service) newOTPChallenge(ctx context.Context, ph, purpose string, faID uuid.UUID, inTx func(tx pgx.Tx, id uuid.UUID) error) (string, uuid.UUID, error) {
	code := s.deps.Config.FixedOTP() // dev only; "" elsewhere
	if code == "" {
		code = auth.RandomDigits(otpLength)
	}
	now := s.now()
	id := ids.New()
	err := s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if err := q.DeleteOldOTPChallenges(ctx, store.DeleteOldOTPChallengesParams{Phone: ph, Before: now.Add(-otpChallengeMaxAge)}); err != nil {
			return apperr.Internalf("identity: purge otp: %w", err)
		}
		if err := q.CreateOTPChallenge(ctx, store.CreateOTPChallengeParams{
			ID: id, Phone: ph, Purpose: purpose, FaID: nullUUID(faID), CodeHash: s.otpHash(id, code),
			MaxAttempts: otpMaxAttempts, ExpiresAt: now.Add(s.deps.Config.OTPTTL), Ip: ipAddr(ctx),
		}); err != nil {
			return apperr.Internalf("identity: create otp: %w", err)
		}
		if inTx != nil {
			return inTx(tx, id)
		}
		return nil
	})
	if err != nil {
		return "", uuid.Nil, err
	}
	return code, id, nil
}

// sendOTPSMS sends a code SMS. The code never reaches the logs.
func (s *Service) sendOTPSMS(ctx context.Context, ph, body, templateID string) error {
	if _, err := s.deps.SMS.Send(ctx, sms.Message{To: ph, Body: body, TemplateID: templateID}); err != nil {
		logx.From(ctx).ErrorContext(ctx, "identity: otp sms failed", "to", phone.Mask(ph), "template", templateID, "err", err)
		return apperr.Unavailable("could not send the SMS; please try again")
	}
	return nil
}

// useOTPChallenge checks code against the newest challenge for (phone,
// purpose) inside the caller's transaction and uses it up on success. For
// consent codes the challenge must have been asked for by faID. failure is
// the user-facing error (wrong or expired code); the caller still commits so
// the attempt count sticks. err is an infrastructure error.
func (s *Service) useOTPChallenge(ctx context.Context, q *store.Queries, ph, purpose string, faID uuid.UUID, code string) (ch store.OtpChallenge, failure, err error) {
	ch, err = q.LatestOTPChallengeForUpdate(ctx, store.LatestOTPChallengeForUpdateParams{Phone: ph, Purpose: purpose})
	if db.IsNoRows(err) {
		return ch, errOTPExpired(), nil
	}
	if err != nil {
		return ch, nil, apperr.Internalf("identity: load otp: %w", err)
	}
	now := s.now()
	if ch.ConsumedAt != nil || !now.Before(ch.ExpiresAt) || ch.Attempts >= ch.MaxAttempts {
		return ch, errOTPExpired(), nil
	}
	if purpose == otpPurposeConsent && ch.FaID.UUID != faID {
		// Another FA's code for this phone: as if there were none.
		return ch, errOTPExpired(), nil
	}
	if !hmac.Equal(s.otpHash(ch.ID, code), ch.CodeHash) { // constant time
		n, err := q.IncrementOTPAttempts(ctx, ch.ID)
		if err != nil {
			return ch, nil, apperr.Internalf("identity: count otp attempt: %w", err)
		}
		return ch, errOTPInvalid(int(max(ch.MaxAttempts-n, 0))), nil
	}
	if err := q.ConsumeOTPChallenge(ctx, store.ConsumeOTPChallengeParams{ConsumedAt: tp(now), ID: ch.ID}); err != nil {
		return ch, nil, apperr.Internalf("identity: consume otp: %w", err)
	}
	return ch, nil, nil
}
