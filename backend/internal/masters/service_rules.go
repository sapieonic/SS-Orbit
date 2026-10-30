package masters

import (
	"context"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/masters/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// Advisory rules: issue -> salt -> optional Shanmukha SKU, with a dose per
// acre in English and Telugu. Every change is a new version of the rule_key;
// one approved version per key is live. An issue may have several live rules,
// one per salt: the FA picks the salt and the app shows the matching
// Shanmukha product if there is one (FA-09).
//
// Workflow (maker-checker, ADM-08):
//
//	draft (author edits) --submit--> draft, submitted --approve--> approved (live)
//	                                                    --reject---> rejected
//
// Admin and agronomy draft. Only agronomy approves, and never their own draft.
// Approval supersedes the previous live version and bumps the masters version
// in the same transaction.

const (
	ruleDraft      = "draft"
	ruleApproved   = "approved"
	ruleSuperseded = "superseded"
)

// ListRules lists rule versions, oldest first.
func (s *Service) ListRules(ctx context.Context, f RuleFilter, limit *int, cursor *string) (paging.Page[Rule], error) {
	if err := requireRead(ctx); err != nil {
		return paging.Page[Rule]{}, err
	}
	cur, n, err := pageArgs(limit, cursor)
	if err != nil {
		return paging.Page[Rule]{}, err
	}
	rows, err := s.q.ListRuleViews(ctx, store.ListRuleViewsParams{
		RuleKey: nullUUID(f.RuleKey), IssueID: nullUUID(f.IssueID), CropID: nullUUID(f.CropID), Status: f.Status,
		CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[Rule]{}, apperr.Internalf("masters: list rules: %w", err)
	}
	return paging.Map(paging.Build(rows, n, func(r store.ListRuleViewsRow) paging.Cursor {
		return paging.Cursor{At: r.CreatedAt, ID: r.ID}
	}), toRule), nil
}

// GetRule returns one rule version.
func (s *Service) GetRule(ctx context.Context, id uuid.UUID) (Rule, error) {
	if err := requireRead(ctx); err != nil {
		return Rule{}, err
	}
	return loadRule(ctx, s.q, id)
}

// CreateRuleDraft starts a new rule (in.RuleKey nil) or drafts the next version
// of an existing one.
func (s *Service) CreateRuleDraft(ctx context.Context, in RuleInput) (Rule, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return Rule{}, err
	}
	errs := map[string]string{}
	in.Dose = text("dose_per_acre", in.Dose, errs)
	in.DoseTe = text("dose_per_acre_te", in.DoseTe, errs)
	in.ChangeNote = trimmedOrNil(in.ChangeNote)
	if err := validationErr(errs); err != nil {
		return Rule{}, err
	}

	var out Rule
	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		// Locking the issue serialises drafts for one issue, so two people
		// can't start two rules for it at once.
		issue, err := q.GetIssueForUpdate(ctx, in.IssueID)
		if err != nil {
			if db.IsNoRows(err) {
				return apperr.Validation("issue_id", "unknown issue")
			}
			return apperr.Internalf("masters: load issue: %w", err)
		}
		if !issue.Active {
			return apperr.Validation("issue_id", "issue is inactive")
		}
		if err := checkRuleTargets(ctx, q, in.SaltID, in.SKUID); err != nil {
			return err
		}

		key, version := ids.New(), int32(1)
		if in.RuleKey != nil {
			latest, err := q.GetLatestRuleVersionForUpdate(ctx, *in.RuleKey)
			if err != nil {
				if db.IsNoRows(err) {
					return apperr.Validation("rule_key", "unknown rule")
				}
				return apperr.Internalf("masters: load rule: %w", err)
			}
			if latest.IssueID != in.IssueID {
				return apperr.Validation("issue_id", "must be the rule's issue")
			}
			key, version = *in.RuleKey, latest.Version+1
		} else {
			keys, err := q.RuleKeysForIssueSalt(ctx, store.RuleKeysForIssueSaltParams{IssueID: in.IssueID, SaltID: in.SaltID})
			if err != nil {
				return apperr.Internalf("masters: rule for issue: %w", err)
			}
			if len(keys) > 0 {
				return apperr.Conflict("rule_exists", map[string]any{"rule_key": keys[0]}).
					WithMessage("this issue already has a rule for this salt; draft a new version of it")
			}
		}

		row, err := q.CreateRule(ctx, store.CreateRuleParams{
			ID: ids.New(), RuleKey: key, Version: version, IssueID: in.IssueID, SaltID: in.SaltID,
			SkuID: nullUUID(in.SKUID), DosePerAcre: in.Dose, DosePerAcreTe: in.DoseTe,
			ChangeNote: in.ChangeNote, CreatedBy: p.ID,
		})
		if err != nil {
			if db.IsUniqueViolation(err, "") {
				return apperr.Conflict("draft_exists", map[string]any{"rule_key": key}).
					WithMessage("this rule already has an open draft")
			}
			return apperr.Internalf("masters: create rule: %w", err)
		}
		if out, err = loadRule(ctx, q, row.ID); err != nil {
			return err
		}
		return record(ctx, tx, "masters.rule_drafted", "advisory_rule", row.ID, nil, out, nil)
	})
	return out, err
}

// UpdateRuleDraft rewrites a draft. Only its author can, and only until it is
// submitted: what the checker approves must be exactly what the maker wrote.
func (s *Service) UpdateRuleDraft(ctx context.Context, id uuid.UUID, d RuleDraft) (Rule, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return Rule{}, err
	}
	errs := map[string]string{}
	d.Dose = text("dose_per_acre", d.Dose, errs)
	d.DoseTe = text("dose_per_acre_te", d.DoseTe, errs)
	d.ChangeNote = trimmedOrNil(d.ChangeNote)
	if err := validationErr(errs); err != nil {
		return Rule{}, err
	}
	var out Rule
	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		cur, err := lockOpenDraft(ctx, q, id)
		if err != nil {
			return err
		}
		if err := authorOnly(p, cur); err != nil {
			return err
		}
		if cur.SubmittedAt != nil {
			return apperr.Conflict("already_submitted", nil).WithMessage("a submitted draft cannot be edited")
		}
		if err := checkRuleTargets(ctx, q, d.SaltID, d.SKUID); err != nil {
			return err
		}
		before, err := loadRule(ctx, q, id)
		if err != nil {
			return err
		}
		if _, err := q.UpdateDraftRule(ctx, store.UpdateDraftRuleParams{
			ID: id, SaltID: d.SaltID, SkuID: nullUUID(d.SKUID), DosePerAcre: d.Dose, DosePerAcreTe: d.DoseTe,
			ChangeNote: d.ChangeNote,
		}); err != nil {
			return apperr.Internalf("masters: update draft: %w", err)
		}
		if out, err = loadRule(ctx, q, id); err != nil {
			return err
		}
		return record(ctx, tx, "masters.rule_draft_updated", "advisory_rule", id, before, out, nil)
	})
	return out, err
}

// SubmitRule sends the author's draft to Agronomy for approval.
func (s *Service) SubmitRule(ctx context.Context, id uuid.UUID) (Rule, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return Rule{}, err
	}
	var out Rule
	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		cur, err := lockOpenDraft(ctx, q, id)
		if err != nil {
			return err
		}
		if err := authorOnly(p, cur); err != nil {
			return err
		}
		if cur.SubmittedAt != nil {
			return apperr.Conflict("already_submitted", nil).WithMessage("the draft is already waiting for approval")
		}
		if _, err := q.SubmitRule(ctx, store.SubmitRuleParams{ID: id, SubmittedAt: s.deps.Clock.Now(), SubmittedBy: p.ID}); err != nil {
			return apperr.Internalf("masters: submit rule: %w", err)
		}
		if out, err = loadRule(ctx, q, id); err != nil {
			return err
		}
		return record(ctx, tx, "masters.rule_submitted", "advisory_rule", id, nil, out, nil)
	})
	return out, err
}

// ApproveRule makes a submitted draft live: Agronomy only, never the author.
// In one transaction it supersedes the previous live version, approves the
// draft, bumps the masters version and publishes masters.published.
func (s *Service) ApproveRule(ctx context.Context, id uuid.UUID, note *string) (Rule, error) {
	p, err := auth.RequireRole(ctx, auth.RoleAgronomy)
	if err != nil {
		return Rule{}, onlyAgronomy(ctx, err)
	}
	note = trimmedOrNil(note)
	var out Rule
	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		cur, err := lockOpenDraft(ctx, q, id)
		if err != nil {
			return err
		}
		if cur.SubmittedAt == nil {
			return apperr.Conflict("not_submitted", nil).WithMessage("the author has not submitted this draft yet")
		}
		if cur.CreatedBy == p.ID {
			return apperr.Forbidden("you cannot approve your own draft; another Agronomy user must approve it")
		}
		// Masters may have changed since the draft was written.
		if err := checkRuleTargets(ctx, q, cur.SaltID, uuidPtr(cur.SkuID)); err != nil {
			return err
		}
		var previous any // the version this approval supersedes, if any
		superseded, err := q.SupersedeLiveRule(ctx, cur.RuleKey)
		if err != nil {
			return apperr.Internalf("masters: supersede: %w", err)
		}
		if len(superseded) > 0 {
			prev, err := loadRule(ctx, q, superseded[0].ID)
			if err != nil {
				return err
			}
			previous = prev
		}
		if _, err := q.ApproveRule(ctx, store.ApproveRuleParams{
			ID: id, ApprovedBy: p.ID, ApprovedAt: s.deps.Clock.Now(), ReviewNote: note,
		}); err != nil {
			if db.IsUniqueViolation(err, "advisory_rules_one_live_per_issue_salt") {
				return apperr.Conflict("issue_has_live_rule", nil).
					WithMessage("another rule is already live for this issue and salt")
			}
			return apperr.Internalf("masters: approve rule: %w", err)
		}
		if out, err = loadRule(ctx, q, id); err != nil {
			return err
		}
		return s.recordPublished(ctx, tx, q, "masters.rule_approved", "advisory_rule", id, previous, out)
	})
	return out, err
}

// RejectRule closes a draft (submitted or not) with a note for the author.
// Agronomy only; an Agronomy author may reject (withdraw) their own draft.
func (s *Service) RejectRule(ctx context.Context, id uuid.UUID, note string) (Rule, error) {
	p, err := auth.RequireRole(ctx, auth.RoleAgronomy)
	if err != nil {
		return Rule{}, onlyAgronomy(ctx, err)
	}
	errs := map[string]string{}
	note = text("note", note, errs)
	if err := validationErr(errs); err != nil {
		return Rule{}, err
	}
	var out Rule
	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if _, err := lockOpenDraft(ctx, q, id); err != nil {
			return err
		}
		if _, err := q.RejectRule(ctx, store.RejectRuleParams{
			ID: id, RejectedBy: p.ID, RejectedAt: s.deps.Clock.Now(), ReviewNote: &note,
		}); err != nil {
			return apperr.Internalf("masters: reject rule: %w", err)
		}
		if out, err = loadRule(ctx, q, id); err != nil {
			return err
		}
		return record(ctx, tx, "masters.rule_rejected", "advisory_rule", id, nil, out, nil)
	})
	return out, err
}

// checkRuleTargets: the salt is active; the SKU, if any, is active and
// contains that salt (advice names a Shanmukha product or the salt only).
func checkRuleTargets(ctx context.Context, q *store.Queries, saltID uuid.UUID, skuID *uuid.UUID) error {
	if err := requireActiveSalt(ctx, q, saltID, "salt_id"); err != nil {
		return err
	}
	if skuID == nil {
		return nil
	}
	sku, err := q.GetSku(ctx, *skuID)
	if err != nil {
		if db.IsNoRows(err) {
			return apperr.Validation("sku_id", "unknown SKU")
		}
		return apperr.Internalf("masters: load sku: %w", err)
	}
	if !sku.Active {
		return apperr.Validation("sku_id", "SKU is inactive")
	}
	if sku.SaltID != saltID {
		return apperr.Validation("sku_id", "SKU does not contain this salt")
	}
	return nil
}

// lockOpenDraft locks a rule and checks it is still a draft.
func lockOpenDraft(ctx context.Context, q *store.Queries, id uuid.UUID) (store.AdvisoryRule, error) {
	r, err := q.GetRuleForUpdate(ctx, id)
	if err != nil {
		return store.AdvisoryRule{}, notFound(err, "rule")
	}
	if r.Status != ruleDraft {
		return store.AdvisoryRule{}, apperr.Conflict("not_draft", map[string]any{"status": r.Status}).
			WithMessage("only a draft can be changed; draft a new version instead")
	}
	return r, nil
}

func authorOnly(p auth.Principal, r store.AdvisoryRule) error {
	if r.CreatedBy != p.ID {
		return apperr.Forbidden("only the author can edit or submit this draft")
	}
	return nil
}

// onlyAgronomy rewords the role error for HO users who are not Agronomy
// (the wireframe's "Only Agronomy can approve dose and product changes").
func onlyAgronomy(ctx context.Context, err error) error {
	if p, ok := auth.FromContext(ctx); ok && p.IsHO() && apperr.Is(err, apperr.KindForbidden) {
		return apperr.Forbidden("only Agronomy can approve or reject dose and product changes")
	}
	return err
}

func loadRule(ctx context.Context, q *store.Queries, id uuid.UUID) (Rule, error) {
	rows, err := q.ListRuleViews(ctx, store.ListRuleViewsParams{RuleID: uuid.NullUUID{UUID: id, Valid: true}, RowLimit: 1})
	if err != nil {
		return Rule{}, apperr.Internalf("masters: load rule: %w", err)
	}
	if len(rows) == 0 {
		return Rule{}, apperr.NotFound("rule")
	}
	return toRule(rows[0]), nil
}

func toRule(r store.ListRuleViewsRow) Rule {
	return Rule{
		ID: r.ID, RuleKey: r.RuleKey, Version: r.Version, IssueID: r.IssueID, CropID: r.CropID,
		IssueType: r.IssueType, IssueName: r.IssueName, IssueNameTe: r.IssueNameTe,
		SaltID: r.SaltID, SaltName: r.SaltName, SaltNameTe: r.SaltNameTe,
		SKUID: uuidPtr(r.SkuID), SKUCode: r.SkuCode, ProductName: r.ProductName, ProductNameTe: r.ProductNameTe,
		Dose: r.DosePerAcre, DoseTe: r.DosePerAcreTe, Status: r.Status, ChangeNote: r.ChangeNote,
		CreatedBy: r.CreatedBy, CreatedAt: r.CreatedAt.UTC(),
		SubmittedBy: uuidPtr(r.SubmittedBy), SubmittedAt: utcPtr(r.SubmittedAt),
		ApprovedBy: uuidPtr(r.ApprovedBy), ApprovedAt: utcPtr(r.ApprovedAt),
		RejectedBy: uuidPtr(r.RejectedBy), RejectedAt: utcPtr(r.RejectedAt), ReviewNote: r.ReviewNote,
	}
}

func trimmedOrNil(s *string) *string {
	if s == nil {
		return nil
	}
	t := strings.TrimSpace(*s)
	if t == "" {
		return nil
	}
	return &t
}
