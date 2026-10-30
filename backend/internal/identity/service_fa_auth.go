package identity

import (
	"context"
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

// Password sign-in limits (FA and HO). Every attempt counts, so a login ID is
// locked for the rest of the window after a burst of tries.
const (
	loginPerAccount15Min = 10
	loginPerIP15Min      = 100
	passwordChangePer15  = 5
)

// FALogin signs an FA in with their HO-issued login ID and password and
// registers the device. Any failure gives the same error.
func (s *Service) FALogin(ctx context.Context, code, password string, dev AppDevice) (FASignIn, error) {
	code = strings.ToUpper(strings.TrimSpace(code))
	if err := s.allow(ctx, "login:fa:"+code, loginPerAccount15Min, 15*time.Minute); err != nil {
		return FASignIn{}, err
	}
	if err := s.allowIP(ctx, "login", loginPerIP15Min, 15*time.Minute); err != nil {
		return FASignIn{}, err
	}
	fa, err := s.q.GetFieldAssistantByCode(ctx, code)
	if db.IsNoRows(err) {
		burnPasswordCheck(password)
		return FASignIn{}, errBadFALogin
	}
	if err != nil {
		return FASignIn{}, apperr.Internalf("identity: load fa: %w", err)
	}
	ok, err := auth.VerifyPassword(fa.PasswordHash, password)
	if err != nil {
		return FASignIn{}, apperr.Internalf("identity: verify fa password: %w", err)
	}
	if !ok || fa.Status == FAInactive {
		reason := "bad_password"
		if ok {
			reason = "inactive"
		}
		s.recordLoginFailure(ctx, "field_assistant", fa.ID, reason)
		return FASignIn{}, errBadFALogin
	}
	// Only after a correct password, so this says nothing to a guesser.
	if tempPasswordExpired(fa.MustChangePassword, fa.TempPasswordExpiresAt, s.now()) {
		s.recordLoginFailure(ctx, "field_assistant", fa.ID, "temp_password_expired")
		return FASignIn{}, errTempPasswordExpired()
	}

	var out FASignIn
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		d, err := s.registerDevice(ctx, q, SubjectFA, fa.ID, dev)
		if err != nil {
			return err
		}
		now := s.now()
		if err := q.TouchFieldAssistantLogin(ctx, store.TouchFieldAssistantLoginParams{At: tp(now), ID: fa.ID}); err != nil {
			return apperr.Internalf("identity: touch fa login: %w", err)
		}
		p := auth.Principal{Kind: auth.KindFA, ID: fa.ID, DeviceID: d.ID, MustChangePassword: fa.MustChangePassword}
		tokens, err := s.startSession(ctx, q, p, uuid.Nil, time.Time{}, "")
		if err != nil {
			return err
		}
		fa.LastLoginAt = tp(now)
		out = FASignIn{Tokens: tokens, DeviceID: d.ID, FA: toFA(fa, nil), OfflineRules: faOfflinePolicy}
		return record(ctx, tx, &p, audit.Entry{Action: "identity.fa_login_issued", EntityType: "field_assistant", EntityID: fa.ID,
			Meta: map[string]any{"device_id": d.ID, "must_change_password": fa.MustChangePassword}})
	})
	if err != nil {
		return FASignIn{}, err
	}
	return out, nil
}

// ChangeFAPassword lets a signed-in FA set a new password (required after a
// temporary one). Their other sessions are signed out. The current access
// token still carries the must-change flag; the app refreshes to drop it.
func (s *Service) ChangeFAPassword(ctx context.Context, current, next string) error {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return err
	}
	if err := s.allow(ctx, "pwchange:fa:"+p.ID.String(), passwordChangePer15, 15*time.Minute); err != nil {
		return err
	}
	fa, err := s.q.GetFieldAssistant(ctx, p.ID)
	if db.IsNoRows(err) {
		return apperr.Unauthorized("")
	}
	if err != nil {
		return apperr.Internalf("identity: load fa: %w", err)
	}
	if ok, err := auth.VerifyPassword(fa.PasswordHash, current); err != nil {
		return apperr.Internalf("identity: verify fa password: %w", err)
	} else if !ok {
		return apperr.Validation("current_password", "is not correct")
	}
	if tempPasswordExpired(fa.MustChangePassword, fa.TempPasswordExpiresAt, s.now()) {
		return errTempPasswordExpired()
	}
	if err := validateNewPassword(next, current, fa.Code); err != nil {
		return err
	}
	hash, err := auth.HashPassword(next)
	if err != nil {
		return apperr.Internalf("identity: hash password: %w", err)
	}
	var revoked []uuid.UUID
	defer func() { s.forgetSessions(ctx, revoked...) }()
	return s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if err := q.SetFieldAssistantPassword(ctx, store.SetFieldAssistantPasswordParams{PasswordHash: hash, ID: fa.ID}); err != nil {
			return apperr.Internalf("identity: set fa password: %w", err)
		}
		var err error
		if revoked, err = s.revokeSubjectSessions(ctx, q, SubjectFA, fa.ID, s.currentFamily(ctx, q, p)); err != nil {
			return err
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.password_changed", EntityType: "field_assistant", EntityID: fa.ID,
			Meta: map[string]any{"other_sessions_revoked": len(revoked)}})
	})
}

func toFA(r store.FieldAssistant, appVersion *string) FA {
	langs := r.Languages
	if langs == nil {
		langs = []string{}
	}
	return FA{
		ID: r.ID, Code: r.Code, Name: r.Name, NameTe: r.NameTe, Phone: r.Phone, Level: r.Level, Languages: langs,
		WorkingHours: r.WorkingHours, PhotoKey: r.PhotoKey, Status: r.Status, MustChangePassword: r.MustChangePassword,
		LastLoginAt: utcPtr(r.LastLoginAt), LastSyncAt: utcPtr(r.LastSyncAt), AppVersion: appVersion,
		CreatedAt: r.CreatedAt.UTC(), UpdatedAt: r.UpdatedAt.UTC(),
	}
}
