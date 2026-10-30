package identity

import (
	"context"
	"net/mail"
	"slices"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// HO roles are fixed in code at launch (admin, agronomy, finance, ops).
var hoRoles = []string{string(auth.RoleAdmin), string(auth.RoleAgronomy), string(auth.RoleFinance), string(auth.RoleOps)}

// authorizeAdmin: only admins manage HO users and roles.
func authorizeAdmin(ctx context.Context) (auth.Principal, error) {
	return auth.RequireRole(ctx, auth.RoleAdmin)
}

func hoAudit(u store.HoUser) map[string]any {
	return map[string]any{"email": u.Email, "name": u.Name, "role": u.Role, "district_ids": u.DistrictIds, "status": u.Status}
}

// ListHOAccounts searches HO users, newest first.
func (s *Service) ListHOAccounts(ctx context.Context, f HOFilter, limit *int, cursor *string) (paging.Page[HOAccount], error) {
	if _, err := authorizeAdmin(ctx); err != nil {
		return paging.Page[HOAccount]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[HOAccount]{}, err
	}
	n := paging.Limit(limit, listDefaultLimit, listMaxLimit)
	rows, err := s.q.ListHOUsers(ctx, store.ListHOUsersParams{
		Status: f.Status, Role: f.Role, Q: optText(f.Q), CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[HOAccount]{}, apperr.Internalf("identity: list ho users: %w", err)
	}
	return paging.Map(paging.Build(rows, n, func(u store.HoUser) paging.Cursor {
		return paging.Cursor{At: u.CreatedAt, ID: u.ID}
	}), toHOAccount), nil
}

// HODirectory lists every HO user's name, role and status, sorted by name,
// so any HO role can show who made, approved or changed something (rules,
// advisories, audit rows). Emails and area scopes stay admin-only.
func (s *Service) HODirectory(ctx context.Context) ([]HODirectoryEntry, error) {
	if _, err := auth.RequireRole(ctx, auth.RoleAdmin, auth.RoleAgronomy, auth.RoleFinance, auth.RoleOps); err != nil {
		return nil, err
	}
	rows, err := s.q.ListHOUserDirectory(ctx)
	if err != nil {
		return nil, apperr.Internalf("identity: ho directory: %w", err)
	}
	out := make([]HODirectoryEntry, len(rows))
	for i, r := range rows {
		out[i] = HODirectoryEntry{ID: r.ID, Name: r.Name, Role: r.Role, Status: r.Status}
	}
	return out, nil
}

// GetHOAccount returns one HO user.
func (s *Service) GetHOAccount(ctx context.Context, id uuid.UUID) (HOAccount, error) {
	if _, err := authorizeAdmin(ctx); err != nil {
		return HOAccount{}, err
	}
	u, err := s.q.GetHOUser(ctx, id)
	if db.IsNoRows(err) {
		return HOAccount{}, apperr.NotFound("HO user")
	}
	if err != nil {
		return HOAccount{}, apperr.Internalf("identity: get ho user: %w", err)
	}
	return toHOAccount(u), nil
}

// CreateHOAccount invites an HO user with a temporary password (returned once).
// They set up TOTP and change the password at first sign-in.
func (s *Service) CreateHOAccount(ctx context.Context, in NewHOAccount) (HOAccount, string, error) {
	if _, err := authorizeAdmin(ctx); err != nil {
		return HOAccount{}, "", err
	}
	bad := map[string]string{}
	email := normalizeEmail(in.Email)
	if a, err := mail.ParseAddress(email); err != nil || a.Address != email {
		bad["email"] = "must be a valid email address"
	}
	name := clip(in.Name, 100)
	if name == "" {
		bad["name"] = "is required"
	}
	if !slices.Contains(hoRoles, in.Role) {
		bad["role"] = "must be admin, agronomy, finance or ops"
	}
	if len(bad) > 0 {
		return HOAccount{}, "", apperr.ValidationFields(bad)
	}
	temp := newTempPassword()
	hash, err := auth.HashPassword(temp)
	if err != nil {
		return HOAccount{}, "", apperr.Internalf("identity: hash password: %w", err)
	}
	var out store.HoUser
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		var err error
		out, err = q.CreateHOUser(ctx, store.CreateHOUserParams{ID: ids.New(), Email: email, Name: name,
			PasswordHash: hash, Role: in.Role, DistrictIds: dedupeUUIDs(in.DistrictIDs),
			TempPasswordExpiresAt: tp(s.now().Add(tempPasswordTTL))})
		if db.IsUniqueViolation(err, "") {
			return apperr.Conflict("email_taken", nil)
		}
		if err != nil {
			return apperr.Internalf("identity: create ho user: %w", err)
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.ho_user_created", EntityType: "ho_user", EntityID: out.ID, After: hoAudit(out)})
	})
	if err != nil {
		return HOAccount{}, "", err
	}
	return toHOAccount(out), temp, nil
}

// lockHOUser loads an HO user for update.
func lockHOUser(ctx context.Context, q *store.Queries, id uuid.UUID) (store.HoUser, error) {
	u, err := q.GetHOUserForUpdate(ctx, id)
	if db.IsNoRows(err) {
		return u, apperr.NotFound("HO user")
	}
	if err != nil {
		return u, apperr.Internalf("identity: load ho user: %w", err)
	}
	return u, nil
}

// ensureOtherAdmin refuses to leave the organisation without an admin who can
// sign in (an invited admin who never finished set-up does not count).
func ensureOtherAdmin(ctx context.Context, q *store.Queries, u store.HoUser) error {
	if u.Role != string(auth.RoleAdmin) || u.Status == HODisabled {
		return nil
	}
	n, err := q.CountOtherActiveAdmins(ctx, u.ID)
	if err != nil {
		return apperr.Internalf("identity: count admins: %w", err)
	}
	if n == 0 {
		return apperr.Conflict("last_admin", nil).WithMessage("there must be at least one active admin")
	}
	return nil
}

// UpdateHOAccount changes an HO user's name, role or districts. Nobody can
// change their own role or area scope. Role and area changes reach the
// user's token at their next refresh (within the access-token lifetime).
func (s *Service) UpdateHOAccount(ctx context.Context, id uuid.UUID, patch HOAccountPatch) (HOAccount, error) {
	p, err := authorizeAdmin(ctx)
	if err != nil {
		return HOAccount{}, err
	}
	var out store.HoUser
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		cur, err := lockHOUser(ctx, q, id)
		if err != nil {
			return err
		}
		params := store.UpdateHOUserParams{ID: id, Name: cur.Name, Role: cur.Role, DistrictIds: cur.DistrictIds}
		if patch.Name != nil {
			if params.Name = clip(*patch.Name, 100); params.Name == "" {
				return apperr.Validation("name", "must not be blank")
			}
		}
		if patch.Role != nil {
			if !slices.Contains(hoRoles, *patch.Role) {
				return apperr.Validation("role", "must be admin, agronomy, finance or ops")
			}
			params.Role = *patch.Role
		}
		if patch.DistrictIDs != nil {
			params.DistrictIds = dedupeUUIDs(*patch.DistrictIDs)
		}
		roleChanged := params.Role != cur.Role
		areaChanged := !sameUUIDSet(params.DistrictIds, cur.DistrictIds)
		if id == p.ID && (roleChanged || areaChanged) {
			return apperr.Forbidden("you cannot change your own role or area")
		}
		if roleChanged {
			if err := ensureOtherAdmin(ctx, q, cur); err != nil {
				return err
			}
		}
		if out, err = q.UpdateHOUser(ctx, params); err != nil {
			return apperr.Internalf("identity: update ho user: %w", err)
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.ho_user_updated", EntityType: "ho_user", EntityID: id,
			Before: hoAudit(cur), After: hoAudit(out)})
	})
	if err != nil {
		return HOAccount{}, err
	}
	return toHOAccount(out), nil
}

// SetHOAccountStatus disables an HO user (signing them out everywhere) or
// reactivates them. Not for your own account; the last admin stays.
func (s *Service) SetHOAccountStatus(ctx context.Context, id uuid.UUID, status string) (HOAccount, error) {
	p, err := authorizeAdmin(ctx)
	if err != nil {
		return HOAccount{}, err
	}
	if status != HOActive && status != HODisabled {
		return HOAccount{}, apperr.Validation("status", "must be active or disabled")
	}
	if id == p.ID {
		return HOAccount{}, apperr.Forbidden("you cannot change your own status")
	}
	var out store.HoUser
	var revoked []uuid.UUID
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		cur, err := lockHOUser(ctx, q, id)
		if err != nil {
			return err
		}
		target := status
		if status == HOActive && cur.LastLoginAt == nil {
			target = HOInvited // never signed in: back to invited
		}
		if cur.Status == target || (status == HOActive && cur.Status != HODisabled) {
			out = cur
			return nil
		}
		meta := map[string]any{}
		if status == HODisabled {
			if err := ensureOtherAdmin(ctx, q, cur); err != nil {
				return err
			}
			if revoked, err = s.revokeSubjectSessions(ctx, q, SubjectHO, id, uuid.Nil); err != nil {
				return err
			}
			meta["sessions_revoked"] = len(revoked)
		}
		if out, err = q.SetHOUserStatus(ctx, store.SetHOUserStatusParams{Status: target, ID: id}); err != nil {
			return apperr.Internalf("identity: set ho status: %w", err)
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.ho_user_status_changed", EntityType: "ho_user", EntityID: id,
			Before: map[string]any{"status": cur.Status}, After: map[string]any{"status": target}, Meta: meta})
	})
	if err != nil {
		return HOAccount{}, err
	}
	s.forgetSessions(ctx, revoked...)
	return toHOAccount(out), nil
}

// ResetHOPassword gives another HO user a new temporary password (returned
// once) and signs them out everywhere.
func (s *Service) ResetHOPassword(ctx context.Context, id uuid.UUID) (string, error) {
	p, err := authorizeAdmin(ctx)
	if err != nil {
		return "", err
	}
	if id == p.ID {
		return "", apperr.Forbidden("change your own password from your profile")
	}
	temp := newTempPassword()
	hash, err := auth.HashPassword(temp)
	if err != nil {
		return "", apperr.Internalf("identity: hash password: %w", err)
	}
	var revoked []uuid.UUID
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if _, err := lockHOUser(ctx, q, id); err != nil {
			return err
		}
		if err := q.SetHOUserPassword(ctx, store.SetHOUserPasswordParams{PasswordHash: hash, MustChangePassword: true,
			TempPasswordExpiresAt: tp(s.now().Add(tempPasswordTTL)), ID: id}); err != nil {
			return apperr.Internalf("identity: set ho password: %w", err)
		}
		var err error
		if revoked, err = s.revokeSubjectSessions(ctx, q, SubjectHO, id, uuid.Nil); err != nil {
			return err
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.password_reset", EntityType: "ho_user", EntityID: id,
			Meta: map[string]any{"sessions_revoked": len(revoked)}})
	})
	if err != nil {
		return "", err
	}
	s.forgetSessions(ctx, revoked...)
	return temp, nil
}

// ResetHOTOTP clears another HO user's TOTP (lost phone) and signs them out;
// they set it up again at next sign-in.
func (s *Service) ResetHOTOTP(ctx context.Context, id uuid.UUID) error {
	p, err := authorizeAdmin(ctx)
	if err != nil {
		return err
	}
	if id == p.ID {
		return apperr.Forbidden("another admin must reset your two-step sign-in")
	}
	var revoked []uuid.UUID
	defer func() { s.forgetSessions(ctx, revoked...) }()
	return s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if _, err := lockHOUser(ctx, q, id); err != nil {
			return err
		}
		if err := q.SetHOUserTOTP(ctx, store.SetHOUserTOTPParams{TotpSecret: nil, TotpEnabled: false, ID: id}); err != nil {
			return apperr.Internalf("identity: reset totp: %w", err)
		}
		var err error
		if revoked, err = s.revokeSubjectSessions(ctx, q, SubjectHO, id, uuid.Nil); err != nil {
			return err
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.totp_reset", EntityType: "ho_user", EntityID: id,
			Meta: map[string]any{"sessions_revoked": len(revoked)}})
	})
}

func sameUUIDSet(a, b []uuid.UUID) bool {
	if len(a) != len(b) {
		return false
	}
	for _, id := range a {
		if !slices.Contains(b, id) {
			return false
		}
	}
	return true
}
