package identity

import (
	"context"
	"fmt"
	"regexp"
	"slices"
	"strings"

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

var (
	faCodePattern   = regexp.MustCompile(`^FA-[A-Z]{2,5}-[0-9]{3,4}$`)
	areaCodePattern = regexp.MustCompile(`^[A-Z]{2,5}$`)
	languagePattern = regexp.MustCompile(`^[a-z]{2}$`)
	faLevels        = []string{"village", "mandal", "district"}
)

// faAudit is the FA snapshot written to the audit log (no secrets).
func faAudit(f store.FieldAssistant) map[string]any {
	return map[string]any{
		"code": f.Code, "name": f.Name, "name_te": f.NameTe, "phone": f.Phone, "level": f.Level,
		"languages": f.Languages, "working_hours": f.WorkingHours, "photo_key": f.PhotoKey, "status": f.Status,
	}
}

func cleanLanguages(in []string) ([]string, error) {
	out := make([]string, 0, len(in))
	for _, l := range in {
		l = strings.ToLower(strings.TrimSpace(l))
		if !languagePattern.MatchString(l) {
			return nil, apperr.Validation("languages", "must be 2-letter language codes")
		}
		if !slices.Contains(out, l) {
			out = append(out, l)
		}
	}
	if len(out) == 0 {
		return nil, apperr.Validation("languages", "must not be empty")
	}
	return out, nil
}

// ListFAs searches FA logins, newest first, within the caller's area scope.
func (s *Service) ListFAs(ctx context.Context, f FAFilter, limit *int, cursor *string) (paging.Page[FA], error) {
	p, err := authorizeManage(ctx)
	if err != nil {
		return paging.Page[FA]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[FA]{}, err
	}
	scope, err := s.scopedFAIDs(ctx, p)
	if err != nil {
		return paging.Page[FA]{}, err
	}
	n := paging.Limit(limit, listDefaultLimit, listMaxLimit)
	rows, err := s.q.ListFieldAssistants(ctx, store.ListFieldAssistantsParams{
		Status: f.Status, Ids: scope, Q: optText(f.Q), NotSyncedSince: f.NotSyncedSince,
		CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[FA]{}, apperr.Internalf("identity: list fas: %w", err)
	}
	page := paging.Build(rows, n, func(r store.ListFieldAssistantsRow) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} })
	return paging.Map(page, func(r store.ListFieldAssistantsRow) FA {
		return toFA(store.FieldAssistant{
			ID: r.ID, Code: r.Code, Name: r.Name, NameTe: r.NameTe, Phone: r.Phone, MustChangePassword: r.MustChangePassword,
			Level: r.Level, Languages: r.Languages, WorkingHours: r.WorkingHours, PhotoKey: r.PhotoKey, Status: r.Status,
			LastLoginAt: r.LastLoginAt, LastSyncAt: r.LastSyncAt, CreatedAt: r.CreatedAt, UpdatedAt: r.UpdatedAt,
		}, optText(&r.AppVersion))
	}), nil
}

// GetFA returns one FA.
func (s *Service) GetFA(ctx context.Context, id uuid.UUID) (FA, error) {
	if err := s.authorizeManageFA(ctx, id); err != nil {
		return FA{}, err
	}
	r, err := s.q.GetFieldAssistant(ctx, id)
	if db.IsNoRows(err) {
		return FA{}, apperr.NotFound("field assistant")
	}
	if err != nil {
		return FA{}, apperr.Internalf("identity: get fa: %w", err)
	}
	return toFA(r, nil), nil
}

// CreateFA issues a login to a new FA (one login per person; FAs cannot sign
// themselves up). The login ID is taken from the request or generated as
// FA-<AREA>-<next number>. Returns the temporary password, shown once.
func (s *Service) CreateFA(ctx context.Context, in FACreate) (FA, string, error) {
	p, err := authorizeManage(ctx)
	if err != nil {
		return FA{}, "", err
	}
	params, err := validateFACreate(in)
	if err != nil {
		return FA{}, "", err
	}
	temp := newTempPassword()
	if params.PasswordHash, err = auth.HashPassword(temp); err != nil {
		return FA{}, "", apperr.Internalf("identity: hash password: %w", err)
	}
	params.CreatedBy = nullUUID(p.ID)
	params.TempPasswordExpiresAt = tp(s.now().Add(tempPasswordTTL))

	var created store.FieldAssistant
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if params.Code != "" {
			created, err = s.insertFA(ctx, tx, params)
			if db.IsUniqueViolation(err, "") {
				return apperr.Conflict("code_taken", map[string]any{"code": params.Code})
			}
		} else {
			created, err = s.insertFAWithNextCode(ctx, tx, q, strings.TrimSpace(*in.AreaCode), params)
		}
		if err != nil {
			return err
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.fa_created", EntityType: "field_assistant",
			EntityID: created.ID, After: faAudit(created)})
	})
	if err != nil {
		return FA{}, "", err
	}
	return toFA(created, nil), temp, nil
}

// insertFA inserts inside a savepoint so a duplicate code can be retried
// without aborting the outer transaction.
func (s *Service) insertFA(ctx context.Context, tx pgx.Tx, params store.CreateFieldAssistantParams) (store.FieldAssistant, error) {
	var out store.FieldAssistant
	err := db.WithTx(ctx, tx, func(sp pgx.Tx) error {
		var err error
		out, err = store.New(sp).CreateFieldAssistant(ctx, params)
		return err
	})
	if err != nil && !db.IsUniqueViolation(err, "") {
		return out, apperr.Internalf("identity: create fa: %w", err)
	}
	return out, err
}

// insertFAWithNextCode picks the next free number for an area, retrying if
// another admin took it at the same moment.
func (s *Service) insertFAWithNextCode(ctx context.Context, tx pgx.Tx, q *store.Queries, area string, params store.CreateFieldAssistantParams) (store.FieldAssistant, error) {
	prefix := "FA-" + area + "-"
	for range 5 {
		seq, err := q.MaxFACodeSeq(ctx, prefix)
		if err != nil {
			return store.FieldAssistant{}, apperr.Internalf("identity: next fa code: %w", err)
		}
		if seq >= 9999 {
			return store.FieldAssistant{}, apperr.Conflict("code_space_full", map[string]any{"area_code": area})
		}
		params.Code = fmt.Sprintf("%s%03d", prefix, seq+1)
		out, err := s.insertFA(ctx, tx, params)
		if !db.IsUniqueViolation(err, "") {
			return out, err
		}
	}
	return store.FieldAssistant{}, apperr.Conflict("code_taken", map[string]any{"area_code": area})
}

func validateFACreate(in FACreate) (store.CreateFieldAssistantParams, error) {
	bad := map[string]string{}
	params := store.CreateFieldAssistantParams{ID: ids.New(), NameTe: optText(in.NameTe),
		WorkingHours: optText(in.WorkingHours), PhotoKey: optText(in.PhotoKey), Level: in.Level}
	switch {
	case in.Code != nil && in.AreaCode != nil:
		bad["code"] = "give code or area_code, not both"
	case in.Code != nil:
		params.Code = strings.ToUpper(strings.TrimSpace(*in.Code))
		if !faCodePattern.MatchString(params.Code) {
			bad["code"] = "must look like FA-KDP-014"
		}
	case in.AreaCode != nil:
		if !areaCodePattern.MatchString(strings.TrimSpace(*in.AreaCode)) {
			bad["area_code"] = "must be 2-5 capital letters"
		}
	default:
		bad["code"] = "give code or area_code"
	}
	if params.Name = clip(in.Name, 100); params.Name == "" {
		bad["name"] = "is required"
	}
	if ph, err := normalizePhone("phone", in.Phone); err != nil {
		bad["phone"] = "must be a 10-digit Indian mobile number"
	} else {
		params.Phone = ph
	}
	if !slices.Contains(faLevels, in.Level) {
		bad["level"] = "must be village, mandal or district"
	}
	langs := in.Languages
	if langs == nil {
		langs = []string{"te"}
	}
	if l, err := cleanLanguages(langs); err != nil {
		bad["languages"] = "must be 2-letter language codes"
	} else {
		params.Languages = l
	}
	if len(bad) > 0 {
		return params, apperr.ValidationFields(bad)
	}
	return params, nil
}

// UpdateFA changes an FA's profile. The login ID never changes.
func (s *Service) UpdateFA(ctx context.Context, id uuid.UUID, patch FAPatch) (FA, error) {
	if err := s.authorizeManageFA(ctx, id); err != nil {
		return FA{}, err
	}
	var out store.FieldAssistant
	err := s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		cur, err := q.GetFieldAssistantForUpdate(ctx, id)
		if db.IsNoRows(err) {
			return apperr.NotFound("field assistant")
		}
		if err != nil {
			return apperr.Internalf("identity: load fa: %w", err)
		}
		params, err := applyFAPatch(cur, patch)
		if err != nil {
			return err
		}
		out, err = q.UpdateFieldAssistantProfile(ctx, params)
		if err != nil {
			return apperr.Internalf("identity: update fa: %w", err)
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.fa_updated", EntityType: "field_assistant",
			EntityID: id, Before: faAudit(cur), After: faAudit(out)})
	})
	if err != nil {
		return FA{}, err
	}
	return toFA(out, nil), nil
}

func applyFAPatch(cur store.FieldAssistant, p FAPatch) (store.UpdateFieldAssistantProfileParams, error) {
	out := store.UpdateFieldAssistantProfileParams{ID: cur.ID, Name: cur.Name, NameTe: cur.NameTe, Phone: cur.Phone,
		Level: cur.Level, Languages: cur.Languages, WorkingHours: cur.WorkingHours, PhotoKey: cur.PhotoKey}
	if p.Name != nil {
		if out.Name = clip(*p.Name, 100); out.Name == "" {
			return out, apperr.Validation("name", "must not be blank")
		}
	}
	if p.NameTe != nil {
		out.NameTe = optText(p.NameTe)
	}
	if p.WorkingHours != nil {
		out.WorkingHours = optText(p.WorkingHours)
	}
	if p.PhotoKey != nil {
		out.PhotoKey = optText(p.PhotoKey)
	}
	if p.Phone != nil {
		ph, err := normalizePhone("phone", *p.Phone)
		if err != nil {
			return out, err
		}
		out.Phone = ph
	}
	if p.Level != nil {
		if !slices.Contains(faLevels, *p.Level) {
			return out, apperr.Validation("level", "must be village, mandal or district")
		}
		out.Level = *p.Level
	}
	if p.Languages != nil {
		l, err := cleanLanguages(*p.Languages)
		if err != nil {
			return out, err
		}
		out.Languages = l
	}
	return out, nil
}

// SetFAStatus moves an FA between active, leaving and inactive. Making an FA
// inactive signs them out and revokes their devices, so the app wipes the
// offline data at its next contact (hand-over: the old login stops working).
func (s *Service) SetFAStatus(ctx context.Context, id uuid.UUID, status string) (FA, error) {
	if err := s.authorizeManageFA(ctx, id); err != nil {
		return FA{}, err
	}
	if status != FAActive && status != FALeaving && status != FAInactive {
		return FA{}, apperr.Validation("status", "must be active, leaving or inactive")
	}
	var out store.FieldAssistant
	var revoked []uuid.UUID
	err := s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		cur, err := q.GetFieldAssistantForUpdate(ctx, id)
		if db.IsNoRows(err) {
			return apperr.NotFound("field assistant")
		}
		if err != nil {
			return apperr.Internalf("identity: load fa: %w", err)
		}
		if cur.Status == status {
			out = cur
			return nil
		}
		if out, err = q.SetFieldAssistantStatus(ctx, store.SetFieldAssistantStatusParams{Status: status, ID: id}); err != nil {
			return apperr.Internalf("identity: set fa status: %w", err)
		}
		meta := map[string]any{}
		if status == FAInactive {
			sessions, err := s.revokeSubjectSessions(ctx, q, SubjectFA, id, uuid.Nil)
			if err != nil {
				return err
			}
			if revoked, err = s.revokeSubjectDevices(ctx, tx, q, SubjectFA, id, "fa_deactivated"); err != nil {
				return err
			}
			meta["sessions_revoked"], meta["devices_revoked"] = len(sessions), len(revoked)
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.fa_status_changed", EntityType: "field_assistant", EntityID: id,
			Before: map[string]any{"status": cur.Status}, After: map[string]any{"status": status}, Meta: meta})
	})
	if err != nil {
		return FA{}, err
	}
	s.forgetRevocation(ctx, revoked...)
	return toFA(out, nil), nil
}

// ResetFAPassword gives an FA a new temporary password and signs them out
// everywhere. Their devices stay registered.
func (s *Service) ResetFAPassword(ctx context.Context, id uuid.UUID) (string, error) {
	if err := s.authorizeManageFA(ctx, id); err != nil {
		return "", err
	}
	temp := newTempPassword()
	hash, err := auth.HashPassword(temp)
	if err != nil {
		return "", apperr.Internalf("identity: hash password: %w", err)
	}
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if _, err := q.GetFieldAssistantForUpdate(ctx, id); db.IsNoRows(err) {
			return apperr.NotFound("field assistant")
		} else if err != nil {
			return apperr.Internalf("identity: load fa: %w", err)
		}
		if err := q.SetFieldAssistantPassword(ctx, store.SetFieldAssistantPasswordParams{PasswordHash: hash, MustChangePassword: true,
			TempPasswordExpiresAt: tp(s.now().Add(tempPasswordTTL)), ID: id}); err != nil {
			return apperr.Internalf("identity: set fa password: %w", err)
		}
		n, err := s.revokeSubjectSessions(ctx, q, SubjectFA, id, uuid.Nil)
		if err != nil {
			return err
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.password_reset", EntityType: "field_assistant", EntityID: id,
			Meta: map[string]any{"sessions_revoked": len(n)}})
	})
	if err != nil {
		return "", err
	}
	return temp, nil
}

// SignOutFA ends every session of an FA ("sign out all devices").
func (s *Service) SignOutFA(ctx context.Context, id uuid.UUID) error {
	if err := s.authorizeManageFA(ctx, id); err != nil {
		return err
	}
	return s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if _, err := q.GetFieldAssistant(ctx, id); db.IsNoRows(err) {
			return apperr.NotFound("field assistant")
		} else if err != nil {
			return apperr.Internalf("identity: load fa: %w", err)
		}
		n, err := s.revokeSubjectSessions(ctx, q, SubjectFA, id, uuid.Nil)
		if err != nil {
			return err
		}
		return record(ctx, tx, nil, audit.Entry{Action: "identity.fa_signed_out", EntityType: "field_assistant", EntityID: id,
			Meta: map[string]any{"sessions_revoked": len(n)}})
	})
}
