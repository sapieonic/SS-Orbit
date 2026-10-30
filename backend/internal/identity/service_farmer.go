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
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
)

// OTP rules. Sends are limited hard because every Telugu SMS costs money
// (SMS-pumping fraud); the per-IP limits are loose because rural mobile
// networks put many farmers behind one carrier-NAT address.
const (
	otpLength          = 6
	otpMaxAttempts     = 5
	otpResendAfter     = 30 * time.Second
	otpSendsPerHour    = 5
	otpSendsPerIPHour  = 60
	otpVerifyPer15Min  = 10
	otpVerifyIPPer15   = 120
	otpChallengeMaxAge = 24 * time.Hour
)

func errOTPExpired() *apperr.Error {
	return apperr.BadRequest("otp_expired", "this code has expired; ask for a new one")
}

func errOTPInvalid(left int) *apperr.Error {
	return apperr.BadRequest("otp_invalid", "the code is wrong").WithDetail("attempts_left", left)
}

func normalizePhone(field, raw string) (string, error) {
	p, err := phone.Normalize(raw)
	if err != nil {
		return "", apperr.Validation(field, "must be a 10-digit Indian mobile number")
	}
	return p, nil
}

// otpSMS is the sign-in SMS in the farmer's language (Telugu default, FAR-02).
// With an app hash (OTP_SMS_APP_HASH) it uses the Android SMS Retriever format
// so the farmer app reads the code without a tap.
func otpSMS(code, language string, ttl time.Duration, appHash string) (body, templateID string) {
	vars := map[string]string{"code": code, "minutes": strconv.Itoa(int(ttl.Minutes()))}
	tpl := sms.LoginOTP.For(language)
	if appHash != "" {
		tpl = sms.LoginOTPRetriever.For(language)
		vars["app_hash"] = appHash
	}
	return tpl.Render(vars), tpl.ID
}

// RequestOTP sends a sign-in code to a farmer's phone. A new request replaces
// the previous code. It says nothing about whether the phone is registered.
func (s *Service) RequestOTP(ctx context.Context, rawPhone, language string) (OTPSent, error) {
	ph, err := normalizePhone("phone", rawPhone)
	if err != nil {
		return OTPSent{}, err
	}
	if err := s.allow(ctx, "otp:send:gap:"+ph, 1, otpResendAfter); err != nil {
		return OTPSent{}, err
	}
	if err := s.allow(ctx, "otp:send:"+ph, otpSendsPerHour, time.Hour); err != nil {
		return OTPSent{}, err
	}
	if err := s.allowIP(ctx, "otp:send", otpSendsPerIPHour, time.Hour); err != nil {
		return OTPSent{}, err
	}

	ttl := s.deps.Config.OTPTTL
	code, _, err := s.newOTPChallenge(ctx, ph, otpPurposeLogin, uuid.Nil, nil)
	if err != nil {
		return OTPSent{}, err
	}
	body, templateID := otpSMS(code, language, ttl, s.deps.Config.OTPSMSAppHash)
	if err := s.sendOTPSMS(ctx, ph, body, templateID); err != nil {
		return OTPSent{}, err
	}
	return OTPSent{PhoneMasked: phone.Mask(ph), ExpiresIn: ttl, ResendAfter: otpResendAfter}, nil
}

// VerifyOTP checks a sign-in code. On success, in one transaction, it uses
// the code up, finds or creates the farmer (self sign-up), registers the
// device and starts a session. A wrong code still commits the attempt count.
func (s *Service) VerifyOTP(ctx context.Context, rawPhone, code string, dev AppDevice) (FarmerLogin, error) {
	ph, err := normalizePhone("phone", rawPhone)
	if err != nil {
		return FarmerLogin{}, err
	}
	if err := s.allow(ctx, "otp:verify:"+ph, otpVerifyPer15Min, 15*time.Minute); err != nil {
		return FarmerLogin{}, err
	}
	if err := s.allowIP(ctx, "otp:verify", otpVerifyIPPer15, 15*time.Minute); err != nil {
		return FarmerLogin{}, err
	}
	if s.ports.Farmers == nil {
		return FarmerLogin{}, apperr.Internalf("identity: farmers port is not wired")
	}

	var out FarmerLogin
	var failure error // wrong/expired code: reported after the attempt count commits
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		var err error
		if _, failure, err = s.useOTPChallenge(ctx, q, ph, otpPurposeLogin, uuid.Nil, code); err != nil || failure != nil {
			return err
		}

		farmerID, created, err := s.ports.Farmers.FindOrCreateByPhone(ctx, tx, ph, "self")
		if err != nil {
			return err
		}
		d, err := s.registerDevice(ctx, q, SubjectFarmer, farmerID, dev)
		if err != nil {
			return err // rolls back: the code stays usable from a fresh install
		}
		p := auth.Principal{Kind: auth.KindFarmer, ID: farmerID, DeviceID: d.ID}
		tokens, err := s.startSession(ctx, q, p, uuid.Nil, time.Time{}, "")
		if err != nil {
			return err
		}
		out = FarmerLogin{Tokens: tokens, FarmerID: farmerID, DeviceID: d.ID, IsNew: created}
		return record(ctx, tx, &p, audit.Entry{Action: "identity.farmer_login_issued", EntityType: "farmer",
			EntityID: farmerID, FarmerID: farmerID, Meta: map[string]any{"is_new": created, "device_id": d.ID}})
	})
	if err != nil {
		return FarmerLogin{}, err
	}
	if failure != nil {
		return FarmerLogin{}, failure
	}
	out.FarmerStatus = s.farmerStatus(ctx, out.FarmerID, out.IsNew)
	return out, nil
}

// farmerStatus is the routing hint for the app. A brand-new farmer has no
// village yet; otherwise ask the farmers module (best effort).
func (s *Service) farmerStatus(ctx context.Context, id uuid.UUID, created bool) *string {
	if created {
		return sp("pending_profile")
	}
	sums, err := s.ports.Farmers.GetFarmerSummaries(ctx, []uuid.UUID{id})
	if err != nil || len(sums) == 0 {
		if err != nil {
			logx.From(ctx).WarnContext(ctx, "identity: farmer status hint", "err", err)
		}
		return nil
	}
	return sp(sums[0].Status)
}
