package masters

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/masters/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// MaxMRPPaise caps a SKU's MRP at Rs 1,00,000 per pack. Cashback is capped at
// 5% of MRP x quantity, so an absurd MRP (a typo with extra zeros) would let an
// inflated bill pay out; the cap stops that at the source.
const MaxMRPPaise int64 = 1_00_000 * 100

// ---- salts ----

// ListSalts lists salts, oldest first.
func (s *Service) ListSalts(ctx context.Context, active *bool, q *string, limit *int, cursor *string) (paging.Page[Salt], error) {
	if err := requireRead(ctx); err != nil {
		return paging.Page[Salt]{}, err
	}
	cur, n, err := pageArgs(limit, cursor)
	if err != nil {
		return paging.Page[Salt]{}, err
	}
	rows, err := s.q.ListSalts(ctx, store.ListSaltsParams{
		Active: active, Q: q, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[Salt]{}, apperr.Internalf("masters: list salts: %w", err)
	}
	return paging.Map(paging.Build(rows, n, func(r store.Salt) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} }), toSalt), nil
}

// CreateSalt adds a salt.
func (s *Service) CreateSalt(ctx context.Context, name string, nameTe *string) (Salt, error) {
	if _, err := requireWrite(ctx); err != nil {
		return Salt{}, err
	}
	errs := map[string]string{}
	name = text("name", name, errs)
	nameTe = optText("name_te", nameTe, errs)
	if err := validationErr(errs); err != nil {
		return Salt{}, err
	}
	var out Salt
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		row, err := q.CreateSalt(ctx, store.CreateSaltParams{ID: ids.New(), Name: name, NameTe: nameTe})
		if err != nil {
			if dup := duplicate(err, "name"); dup != nil {
				return dup
			}
			return apperr.Internalf("masters: create salt: %w", err)
		}
		out = toSalt(row)
		return s.recordPublished(ctx, tx, q, "masters.salt_created", "salt", row.ID, nil, out)
	})
	return out, err
}

// UpdateSalt edits or (de)activates a salt. A salt still used by a live rule or
// an active SKU cannot be deactivated: the FA app would advise a salt it no
// longer lists.
func (s *Service) UpdateSalt(ctx context.Context, id uuid.UUID, p SaltPatch) (Salt, error) {
	if _, err := requireWrite(ctx); err != nil {
		return Salt{}, err
	}
	errs := map[string]string{}
	p.Name = optText("name", p.Name, errs)
	p.NameTe = optText("name_te", p.NameTe, errs)
	if err := validationErr(errs); err != nil {
		return Salt{}, err
	}
	var out Salt
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		before, err := q.GetSaltForUpdate(ctx, id)
		if err != nil {
			return notFound(err, "salt")
		}
		if p.Active != nil && !*p.Active && before.Active {
			keys, err := q.LiveRuleKeysUsingSalt(ctx, id)
			if err != nil {
				return apperr.Internalf("masters: salt usage: %w", err)
			}
			skus, err := q.ActiveSkuIDsForSalt(ctx, id)
			if err != nil {
				return apperr.Internalf("masters: salt usage: %w", err)
			}
			if len(keys) > 0 || len(skus) > 0 {
				return apperr.Conflict("in_use", map[string]any{"rule_keys": keys, "sku_ids": skus}).
					WithMessage("the salt is used by live rules or active SKUs; change those first")
			}
		}
		row, err := q.UpdateSalt(ctx, store.UpdateSaltParams{ID: id, Name: p.Name, NameTe: p.NameTe, Active: p.Active})
		if err != nil {
			if dup := duplicate(err, "name"); dup != nil {
				return dup
			}
			return apperr.Internalf("masters: update salt: %w", err)
		}
		out = toSalt(row)
		return s.recordPublished(ctx, tx, q, "masters.salt_updated", "salt", id, toSalt(before), out)
	})
	return out, err
}

func toSalt(r store.Salt) Salt {
	return Salt{ID: r.ID, Name: r.Name, NameTe: r.NameTe, Active: r.Active, CreatedAt: r.CreatedAt.UTC()}
}

// ---- SKUs ----

// ListSKUs lists SKUs, oldest first.
func (s *Service) ListSKUs(ctx context.Context, saltID *uuid.UUID, active *bool, q *string, limit *int, cursor *string) (paging.Page[SKU], error) {
	if err := requireRead(ctx); err != nil {
		return paging.Page[SKU]{}, err
	}
	cur, n, err := pageArgs(limit, cursor)
	if err != nil {
		return paging.Page[SKU]{}, err
	}
	rows, err := s.q.ListSkus(ctx, store.ListSkusParams{
		SaltID: nullUUID(saltID), Active: active, Q: q, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[SKU]{}, apperr.Internalf("masters: list skus: %w", err)
	}
	return paging.Map(paging.Build(rows, n, func(r store.Sku) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} }), toSKU), nil
}

// CreateSKU adds a Shanmukha SKU for an active salt.
func (s *Service) CreateSKU(ctx context.Context, in SKUInput) (SKU, error) {
	if _, err := requireWrite(ctx); err != nil {
		return SKU{}, err
	}
	errs := map[string]string{}
	in.ProductName = text("product_name", in.ProductName, errs)
	in.ProductNameTe = optText("product_name_te", in.ProductNameTe, errs)
	in.PackSize = text("pack_size", in.PackSize, errs)
	checkMRP(in.MRPPaise, errs)
	if err := validationErr(errs); err != nil {
		return SKU{}, err
	}
	eligible := true
	if in.CashbackEligible != nil {
		eligible = *in.CashbackEligible
	}
	var out SKU
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if err := requireActiveSalt(ctx, q, in.SaltID, "salt_id"); err != nil {
			return err
		}
		row, err := q.CreateSku(ctx, store.CreateSkuParams{
			ID: ids.New(), Code: in.Code, ProductName: in.ProductName, ProductNameTe: in.ProductNameTe,
			SaltID: in.SaltID, PackSize: in.PackSize, MrpPaise: in.MRPPaise, CashbackEligible: eligible,
		})
		if err != nil {
			if dup := duplicate(err, "code"); dup != nil {
				return dup
			}
			return apperr.Internalf("masters: create sku: %w", err)
		}
		out = toSKU(row)
		return s.recordPublished(ctx, tx, q, "masters.sku_created", "sku", row.ID, nil, out)
	})
	return out, err
}

// UpdateSKU edits or (de)activates a SKU. A SKU named by a live rule cannot be
// deactivated or moved to another salt; publish a new rule version first.
func (s *Service) UpdateSKU(ctx context.Context, id uuid.UUID, p SKUPatch) (SKU, error) {
	if _, err := requireWrite(ctx); err != nil {
		return SKU{}, err
	}
	errs := map[string]string{}
	p.ProductName = optText("product_name", p.ProductName, errs)
	p.ProductNameTe = optText("product_name_te", p.ProductNameTe, errs)
	p.PackSize = optText("pack_size", p.PackSize, errs)
	if p.MRPPaise != nil {
		checkMRP(*p.MRPPaise, errs)
	}
	if err := validationErr(errs); err != nil {
		return SKU{}, err
	}
	var out SKU
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		before, err := q.GetSkuForUpdate(ctx, id)
		if err != nil {
			return notFound(err, "sku")
		}
		saltChange := p.SaltID != nil && *p.SaltID != before.SaltID
		if saltChange {
			if err := requireActiveSalt(ctx, q, *p.SaltID, "salt_id"); err != nil {
				return err
			}
		}
		deactivate := p.Active != nil && !*p.Active && before.Active
		if saltChange || deactivate {
			keys, err := q.LiveRuleKeysUsingSku(ctx, id)
			if err != nil {
				return apperr.Internalf("masters: sku usage: %w", err)
			}
			if len(keys) > 0 {
				return apperr.Conflict("in_use", map[string]any{"rule_keys": keys}).
					WithMessage("the SKU is named by live rules; publish new rule versions first")
			}
		}
		row, err := q.UpdateSku(ctx, store.UpdateSkuParams{
			ID: id, ProductName: p.ProductName, ProductNameTe: p.ProductNameTe, SaltID: nullUUID(p.SaltID),
			PackSize: p.PackSize, MrpPaise: p.MRPPaise, CashbackEligible: p.CashbackEligible, Active: p.Active,
		})
		if err != nil {
			return apperr.Internalf("masters: update sku: %w", err)
		}
		out = toSKU(row)
		return s.recordPublished(ctx, tx, q, "masters.sku_updated", "sku", id, toSKU(before), out)
	})
	return out, err
}

func checkMRP(mrp int64, errs map[string]string) {
	if mrp <= 0 || mrp > MaxMRPPaise {
		errs["mrp_paise"] = "must be between 1 and 10000000 paise"
	}
}

func requireActiveSalt(ctx context.Context, q *store.Queries, id uuid.UUID, field string) error {
	salt, err := q.GetSalt(ctx, id)
	if err != nil {
		if db.IsNoRows(err) {
			return apperr.Validation(field, "unknown salt")
		}
		return apperr.Internalf("masters: load salt: %w", err)
	}
	if !salt.Active {
		return apperr.Validation(field, "salt is inactive")
	}
	return nil
}

func toSKU(r store.Sku) SKU {
	return SKU{
		ID: r.ID, Code: r.Code, ProductName: r.ProductName, ProductNameTe: r.ProductNameTe, SaltID: r.SaltID,
		PackSize: r.PackSize, MRPPaise: r.MrpPaise, CashbackEligible: r.CashbackEligible, Active: r.Active,
		CreatedAt: r.CreatedAt.UTC(), UpdatedAt: r.UpdatedAt.UTC(),
	}
}

// ---- issues ----

// ListIssues lists issues, oldest first.
func (s *Service) ListIssues(ctx context.Context, cropID *uuid.UUID, typ *string, active *bool, limit *int, cursor *string) (paging.Page[Issue], error) {
	if err := requireRead(ctx); err != nil {
		return paging.Page[Issue]{}, err
	}
	cur, n, err := pageArgs(limit, cursor)
	if err != nil {
		return paging.Page[Issue]{}, err
	}
	rows, err := s.q.ListIssues(ctx, store.ListIssuesParams{
		CropID: nullUUID(cropID), Type: typ, Active: active, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[Issue]{}, apperr.Internalf("masters: list issues: %w", err)
	}
	return paging.Map(paging.Build(rows, n, func(r store.Issue) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} }), toIssue), nil
}

// CreateIssue adds a pest, disease or deficiency to a crop.
func (s *Service) CreateIssue(ctx context.Context, in IssueInput) (Issue, error) {
	if _, err := requireWrite(ctx); err != nil {
		return Issue{}, err
	}
	errs := map[string]string{}
	in.Name = text("name", in.Name, errs)
	in.NameTe = text("name_te", in.NameTe, errs)
	if err := validationErr(errs); err != nil {
		return Issue{}, err
	}
	var out Issue
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if _, err := q.GetCrop(ctx, in.CropID); err != nil {
			if db.IsNoRows(err) {
				return apperr.Validation("crop_id", "unknown crop")
			}
			return apperr.Internalf("masters: load crop: %w", err)
		}
		row, err := q.CreateIssue(ctx, store.CreateIssueParams{
			ID: ids.New(), CropID: in.CropID, Type: in.Type, Name: in.Name, NameTe: in.NameTe,
		})
		if err != nil {
			if dup := duplicate(err, "name"); dup != nil {
				return dup
			}
			return apperr.Internalf("masters: create issue: %w", err)
		}
		out = toIssue(row)
		return s.recordPublished(ctx, tx, q, "masters.issue_created", "issue", row.ID, nil, out)
	})
	return out, err
}

// UpdateIssue edits or (de)activates an issue. An inactive issue drops out of
// the FA app's list; logged visits keep pointing at it.
func (s *Service) UpdateIssue(ctx context.Context, id uuid.UUID, p IssuePatch) (Issue, error) {
	if _, err := requireWrite(ctx); err != nil {
		return Issue{}, err
	}
	errs := map[string]string{}
	p.Name = optText("name", p.Name, errs)
	p.NameTe = optText("name_te", p.NameTe, errs)
	if err := validationErr(errs); err != nil {
		return Issue{}, err
	}
	var out Issue
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		before, err := q.GetIssueForUpdate(ctx, id)
		if err != nil {
			return notFound(err, "issue")
		}
		row, err := q.UpdateIssue(ctx, store.UpdateIssueParams{ID: id, Type: p.Type, Name: p.Name, NameTe: p.NameTe, Active: p.Active})
		if err != nil {
			if dup := duplicate(err, "name"); dup != nil {
				return dup
			}
			return apperr.Internalf("masters: update issue: %w", err)
		}
		out = toIssue(row)
		return s.recordPublished(ctx, tx, q, "masters.issue_updated", "issue", id, toIssue(before), out)
	})
	return out, err
}

func toIssue(r store.Issue) Issue {
	return Issue{ID: r.ID, CropID: r.CropID, Type: r.Type, Name: r.Name, NameTe: r.NameTe, Active: r.Active, CreatedAt: r.CreatedAt.UTC()}
}
