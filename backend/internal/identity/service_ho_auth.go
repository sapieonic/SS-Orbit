package identity

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
)

// totpIssuer is the name shown in the authenticator app.
const totpIssuer = "Orbit Shifting HO"

func normalizeEmail(e string) string { return strings.ToLower(strings.TrimSpace(e)) }

// checkHOPassword is the first factor for every HO sign-in step. It rate
// limits, hides whether the account exists, and refuses disabled users.
func (s *Service) checkHOPassword(ctx context.Context, email, password string) (store.HoUser, error) {
	email = normalizeEmail(email)
	if err := s.allow(ctx, "login:ho:"+email, loginPerAccount15Min, 15*time.Minute); err != nil {
		return store.HoUser{}, err
	}
	if err := s.allowIP(ctx, "login", loginPerIP15Min, 15*time.Minute); err != nil {
		return store.HoUser{}, err
	}
	u, err := s.q.GetHOUserByEmail(ctx, email)
	if db.IsNoRows(err) {
		burnPasswordCheck(password)
		return store.HoUser{}, errBadHOLogin
	}
	if err != nil {
		return store.HoUser{}, apperr.Internalf("identity: load ho user: %w", err)
	}
	ok, err := auth.VerifyPassword(u.PasswordHash, password)
	if err != nil {
		return store.HoUser{}, apperr.Internalf("identity: verify ho password: %w", err)
	}
	if !ok || u.Status == HODisabled {
		reason := "bad_password"
		if ok {
			reason = "disabled"
		}
		s.recordLoginFailure(ctx, "ho_user", u.ID, reason)
		return store.HoUser{}, errBadHOLogin
	}
	// Only after a correct password, so this says nothing to a guesser.
	if tempPasswordExpired(u.MustChangePassword, u.TempPasswordExpiresAt, s.now()) {
		s.recordLoginFailure(ctx, "ho_user", u.ID, "temp_password_expired")
		return store.HoUser{}, errTempPasswordExpired()
	}
	return u, nil
}

// checkTOTP validates a code and makes sure it is used only once: a code
// stays valid for about 90 seconds, so without this a code seen over someone's
// shoulder could be replayed. The limiter works as a "seen" set and falls back
// to Postgres when Redis is down.
func (s *Service) checkTOTP(ctx context.Context, u store.HoUser, secret, code string) error {
	if !auth.ValidateTOTP(code, secret, s.now()) {
		return errBadHOLogin
	}
	sum := sha256.Sum256([]byte(code)) // keep even used codes out of keys and logs
	ok, err := s.deps.Limiter.Allow(ctx, "totp:used:"+u.ID.String()+":"+hex.EncodeToString(sum[:8]), 1, 2*time.Minute)
	if err != nil {
		return apperr.Unavailable("please try again shortly").Wrap(err)
	}
	if !ok {
		return errBadHOLogin
	}
	return nil
}

// HOLogin signs an HO user in with email, password and a TOTP code. Users who
// have not set up TOTP get totp_enrolment_required (only after a correct
// password).
func (s *Service) HOLogin(ctx context.Context, email, password string, totpCode *string) (HOSignIn, error) {
	u, err := s.checkHOPassword(ctx, email, password)
	if err != nil {
		return HOSignIn{}, err
	}
	if !u.TotpEnabled || u.TotpSecret == nil {
		return HOSignIn{}, unauthorizedCode("totp_enrolment_required", "set up two-step sign-in to continue")
	}
	if totpCode == nil {
		s.recordLoginFailure(ctx, "ho_user", u.ID, "missing_totp")
		return HOSignIn{}, errBadHOLogin
	}
	secret, legacy, err := s.openTOTP(u.ID, *u.TotpSecret)
	if err != nil {
		return HOSignIn{}, err
	}
	if err := s.checkTOTP(ctx, u, secret, *totpCode); err != nil {
		if apperr.Is(err, apperr.KindUnauthorized) {
			s.recordLoginFailure(ctx, "ho_user", u.ID, "bad_totp")
		}
		return HOSignIn{}, err
	}
	var out HOSignIn
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if legacy { // written before secrets were encrypted: seal it now
			if err := s.sealLegacyTOTP(ctx, q, u.ID, secret); err != nil {
				return err
			}
		}
		var err error
		out, err = s.completeHOLogin(ctx, tx, q, u)
		return err
	})
	return out, err
}

// completeHOLogin marks the sign-in, starts the session and audits it.
func (s *Service) completeHOLogin(ctx context.Context, tx pgx.Tx, q *store.Queries, u store.HoUser) (HOSignIn, error) {
	now := s.now()
	if err := q.TouchHOUserLogin(ctx, store.TouchHOUserLoginParams{At: tp(now), ID: u.ID}); err != nil {
		return HOSignIn{}, apperr.Internalf("identity: touch ho login: %w", err)
	}
	if u.Status == HOInvited {
		u.Status = HOActive
	}
	u.LastLoginAt = tp(now)
	p := auth.Principal{Kind: auth.KindHO, ID: u.ID, Role: auth.Role(u.Role), DistrictIDs: u.DistrictIds,
		MustChangePassword: u.MustChangePassword}
	tokens, err := s.startSession(ctx, q, p, uuid.Nil, time.Time{}, "")
	if err != nil {
		return HOSignIn{}, err
	}
	if err := record(ctx, tx, &p, audit.Entry{Action: "identity.ho_login_issued", EntityType: "ho_user", EntityID: u.ID,
		Meta: map[string]any{"role": u.Role, "must_change_password": u.MustChangePassword}}); err != nil {
		return HOSignIn{}, err
	}
	return HOSignIn{Tokens: tokens, User: toHOAccount(u)}, nil
}

// StartTOTPEnrolment checks the password and stores a new pending TOTP secret.
// Refused once TOTP is enabled; an admin must reset it first.
func (s *Service) StartTOTPEnrolment(ctx context.Context, email, password string) (TOTPEnrolment, error) {
	u, err := s.checkHOPassword(ctx, email, password)
	if err != nil {
		return TOTPEnrolment{}, err
	}
	if u.TotpEnabled {
		return TOTPEnrolment{}, apperr.Conflict("totp_already_enabled", nil)
	}
	secret, url, err := auth.GenerateTOTP(totpIssuer, u.Email)
	if err != nil {
		return TOTPEnrolment{}, apperr.Internalf("identity: generate totp: %w", err)
	}
	sealed, err := s.sealTOTP(u.ID, secret)
	if err != nil {
		return TOTPEnrolment{}, err
	}
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if err := q.SetHOUserTOTP(ctx, store.SetHOUserTOTPParams{TotpSecret: &sealed, TotpEnabled: false, ID: u.ID}); err != nil {
			return apperr.Internalf("identity: store totp: %w", err)
		}
		return record(ctx, tx, &auth.Principal{Kind: auth.KindHO, ID: u.ID}, audit.Entry{
			Action: "identity.totp_enrolment_started", EntityType: "ho_user", EntityID: u.ID})
	})
	if err != nil {
		return TOTPEnrolment{}, err
	}
	return TOTPEnrolment{URL: url, Secret: secret}, nil
}

// ConfirmTOTPEnrolment enables the pending secret once the user proves their
// authenticator produces valid codes, and signs them in.
func (s *Service) ConfirmTOTPEnrolment(ctx context.Context, email, password, code string) (HOSignIn, error) {
	u, err := s.checkHOPassword(ctx, email, password)
	if err != nil {
		return HOSignIn{}, err
	}
	if u.TotpEnabled {
		return HOSignIn{}, apperr.Conflict("totp_already_enabled", nil)
	}
	if u.TotpSecret == nil {
		return HOSignIn{}, apperr.BadRequest("totp_not_started", "start two-step set-up first")
	}
	secret, _, err := s.openTOTP(u.ID, *u.TotpSecret)
	if err != nil {
		return HOSignIn{}, err
	}
	sealed, err := s.sealTOTP(u.ID, secret) // also seals a legacy pending secret
	if err != nil {
		return HOSignIn{}, err
	}
	if err := s.checkTOTP(ctx, u, secret, code); err != nil {
		if apperr.Is(err, apperr.KindUnauthorized) {
			return HOSignIn{}, apperr.BadRequest("totp_invalid", "the code is wrong; check the phone's clock and try again")
		}
		return HOSignIn{}, err
	}
	var out HOSignIn
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if err := q.SetHOUserTOTP(ctx, store.SetHOUserTOTPParams{TotpSecret: &sealed, TotpEnabled: true, ID: u.ID}); err != nil {
			return apperr.Internalf("identity: enable totp: %w", err)
		}
		u.TotpEnabled = true
		if err := record(ctx, tx, &auth.Principal{Kind: auth.KindHO, ID: u.ID}, audit.Entry{
			Action: "identity.totp_enrolled", EntityType: "ho_user", EntityID: u.ID}); err != nil {
			return err
		}
		var err error
		out, err = s.completeHOLogin(ctx, tx, q, u)
		return err
	})
	return out, err
}

// Me returns the signed-in HO user.
func (s *Service) Me(ctx context.Context) (HOAccount, error) {
	p, err := auth.RequireKind(ctx, auth.KindHO)
	if err != nil {
		return HOAccount{}, err
	}
	u, err := s.q.GetHOUser(ctx, p.ID)
	if db.IsNoRows(err) {
		return HOAccount{}, apperr.Unauthorized("")
	}
	if err != nil {
		return HOAccount{}, apperr.Internalf("identity: load ho user: %w", err)
	}
	return toHOAccount(u), nil
}

// ChangeHOPassword lets a signed-in HO user set a new password. Their other
// sessions are signed out. The current access token still carries the
// must-change flag; the portal refreshes to drop it.
func (s *Service) ChangeHOPassword(ctx context.Context, current, next string) error {
	p, err := auth.RequireKind(ctx, auth.KindHO)
	if err != nil {
		return err
	}
	if err := s.allow(ctx, "pwchange:ho:"+p.ID.String(), passwordChangePer15, 15*time.Minute); err != nil {
		return err
	}
	u, err := s.q.GetHOUser(ctx, p.ID)
	if db.IsNoRows(err) {
		return apperr.Unauthorized("")
	}
	if err != nil {
		return apperr.Internalf("identity: load ho user: %w", err)
	}
	if ok, err := auth.VerifyPassword(u.PasswordHash, current); err != nil {
		return apperr.Internalf("identity: verify ho password: %w", err)
	} else if !ok {
		return apperr.Validation("current_password", "is not correct")
	}
	if tempPasswordExpired(u.MustChangePassword, u.TempPasswordExpiresAt, s.now()) {
		return errTempPasswordExpired()
	}
	local, _, _ := strings.Cut(u.Email, "@")
	if err := validateNewPassword(next, current, local); err != nil {
		return err
	}
	hash, err := auth.HashPassword(next)
	if err != nil {
		return apperr.Internalf("identity: hash password: %w", err)
	}
	var revoked []uuid.UUID
	defer func() { s.forgetSessions(ctx, revoked...) }()
	return s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if err := q.SetHOUserPassword(ctx, store.SetHOUserPasswordParams{PasswordHash: hash, ID: u.ID}); err != nil {
			return apperr.Internalf("identity: set ho password: %w", err)
		}
		var err error
		if revoked, err = s.revokeSubjectSessions(ctx, q, SubjectHO, u.ID, s.currentFamily(ctx, q, p)); err != nil {
			return err
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.password_changed", EntityType: "ho_user", EntityID: u.ID,
			Meta: map[string]any{"other_sessions_revoked": len(revoked)}})
	})
}

func toHOAccount(u store.HoUser) HOAccount {
	districts := u.DistrictIds
	if districts == nil {
		districts = []uuid.UUID{}
	}
	return HOAccount{
		ID: u.ID, Email: u.Email, Name: u.Name, Role: u.Role, DistrictIDs: districts, Status: u.Status,
		TOTPEnabled: u.TotpEnabled, MustChangePassword: u.MustChangePassword, LastLoginAt: utcPtr(u.LastLoginAt),
		CreatedAt: u.CreatedAt.UTC(), UpdatedAt: u.UpdatedAt.UTC(),
	}
}
