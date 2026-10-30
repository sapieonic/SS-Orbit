package identity

import (
	"context"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
)

// Consent OTP (FAR-04). When an FA enrols a farmer, the farmer gets an SMS
// that says what they are agreeing to, with a code; reading the code out to
// the FA is their consent. The FA app verifies it while online and gets a
// signed proof (auth.ConsentProof, bound to the FA and the phone) that the
// EnrolFarmer / RecordConsent sync commands carry, possibly days later.
const (
	consentProofTTL         = 7 * 24 * time.Hour
	consentSendsPerFAHour   = 20
	consentVerifyPerFA15Min = 30
)

// ConsentOTPVerified is the result of a verified consent code.
type ConsentOTPVerified struct {
	Phone      string // E.164
	Proof      string // auth.ConsentProof token
	VerifiedAt time.Time
	ExpiresAt  time.Time
}

// consentSMS explains the consent in the farmer's language (Telugu default).
func consentSMS(code, language string, ttl time.Duration) (body, templateID string) {
	tpl := sms.ConsentOTP.For(language)
	return tpl.Render(map[string]string{"code": code, "minutes": strconv.Itoa(int(ttl.Minutes()))}), tpl.ID
}

// RequestConsentOTP sends the consent SMS to a farmer's phone for the calling
// FA. A new request replaces the previous code for that phone. Limited per
// phone (as sign-in codes) and per FA.
func (s *Service) RequestConsentOTP(ctx context.Context, rawPhone, language string) (OTPSent, error) {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return OTPSent{}, err
	}
	ph, err := normalizePhone("phone", rawPhone)
	if err != nil {
		return OTPSent{}, err
	}
	if err := s.allow(ctx, "consent:send:gap:"+ph, 1, otpResendAfter); err != nil {
		return OTPSent{}, err
	}
	if err := s.allow(ctx, "consent:send:"+ph, otpSendsPerHour, time.Hour); err != nil {
		return OTPSent{}, err
	}
	if err := s.allow(ctx, "consent:send:fa:"+p.ID.String(), consentSendsPerFAHour, time.Hour); err != nil {
		return OTPSent{}, err
	}
	ttl := s.deps.Config.OTPTTL
	code, _, err := s.newOTPChallenge(ctx, ph, otpPurposeConsent, p.ID, func(tx pgx.Tx, id uuid.UUID) error {
		return record(ctx, tx, nil, audit.Entry{Action: "identity.consent_otp_sent", EntityType: "otp_challenge", EntityID: id,
			Meta: map[string]any{"phone": ph, "language": language}})
	})
	if err != nil {
		return OTPSent{}, err
	}
	body, templateID := consentSMS(code, language, ttl)
	if err := s.sendOTPSMS(ctx, ph, body, templateID); err != nil {
		return OTPSent{}, err
	}
	return OTPSent{PhoneMasked: phone.Mask(ph), ExpiresIn: ttl, ResendAfter: otpResendAfter}, nil
}

// VerifyConsentOTP checks the code the farmer read out and returns a consent
// proof for the calling FA and that phone. Only the FA who asked for the code
// can use it, and only once.
func (s *Service) VerifyConsentOTP(ctx context.Context, rawPhone, code string) (ConsentOTPVerified, error) {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return ConsentOTPVerified{}, err
	}
	ph, err := normalizePhone("phone", rawPhone)
	if err != nil {
		return ConsentOTPVerified{}, err
	}
	if err := s.allow(ctx, "consent:verify:"+ph, otpVerifyPer15Min, 15*time.Minute); err != nil {
		return ConsentOTPVerified{}, err
	}
	if err := s.allow(ctx, "consent:verify:fa:"+p.ID.String(), consentVerifyPerFA15Min, 15*time.Minute); err != nil {
		return ConsentOTPVerified{}, err
	}
	var out ConsentOTPVerified
	var failure error // wrong/expired code: reported after the attempt count commits
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		ch, fail, err := s.useOTPChallenge(ctx, q, ph, otpPurposeConsent, p.ID, code)
		if err != nil || fail != nil {
			failure = fail
			return err
		}
		now := s.now()
		proof, err := s.deps.Tokens.IssueConsentProof(auth.ConsentProof{FAID: p.ID, Phone: ph, VerifiedAt: now}, consentProofTTL)
		if err != nil {
			return apperr.Internalf("identity: issue consent proof: %w", err)
		}
		out = ConsentOTPVerified{Phone: ph, Proof: proof, VerifiedAt: now, ExpiresAt: now.Add(consentProofTTL)}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.consent_otp_verified", EntityType: "otp_challenge", EntityID: ch.ID,
			Meta: map[string]any{"phone": ph, "proof_expires_at": out.ExpiresAt}})
	})
	if err != nil {
		return ConsentOTPVerified{}, err
	}
	if failure != nil {
		return ConsentOTPVerified{}, failure
	}
	return out, nil
}
