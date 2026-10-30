package masters

import "context"

func (h *handler) ListRules(ctx context.Context, req ListRulesRequestObject) (ListRulesResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListRules(ctx, RuleFilter{
		RuleKey: p.RuleKey, IssueID: p.IssueId, CropID: p.CropId, Status: (*string)(p.Status),
	}, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	items, next := mapPage(page, toRuleView)
	return ListRules200JSONResponse(RulePage{Items: items, NextCursor: next}), nil
}

func (h *handler) CreateRuleDraft(ctx context.Context, req CreateRuleDraftRequestObject) (CreateRuleDraftResponseObject, error) {
	b := req.Body
	r, err := h.svc.CreateRuleDraft(ctx, RuleInput{
		RuleKey: b.RuleKey, IssueID: b.IssueId, SaltID: b.SaltId, SKUID: b.SkuId,
		Dose: b.DosePerAcre, DoseTe: b.DosePerAcreTe, ChangeNote: b.ChangeNote,
	})
	if err != nil {
		return nil, err
	}
	return CreateRuleDraft201JSONResponse(toRuleView(r)), nil
}

func (h *handler) GetRule(ctx context.Context, req GetRuleRequestObject) (GetRuleResponseObject, error) {
	r, err := h.svc.GetRule(ctx, req.RuleId)
	if err != nil {
		return nil, err
	}
	return GetRule200JSONResponse(toRuleView(r)), nil
}

func (h *handler) UpdateRuleDraft(ctx context.Context, req UpdateRuleDraftRequestObject) (UpdateRuleDraftResponseObject, error) {
	b := req.Body
	r, err := h.svc.UpdateRuleDraft(ctx, req.RuleId, RuleDraft{
		SaltID: b.SaltId, SKUID: b.SkuId, Dose: b.DosePerAcre, DoseTe: b.DosePerAcreTe, ChangeNote: b.ChangeNote,
	})
	if err != nil {
		return nil, err
	}
	return UpdateRuleDraft200JSONResponse(toRuleView(r)), nil
}

func (h *handler) SubmitRule(ctx context.Context, req SubmitRuleRequestObject) (SubmitRuleResponseObject, error) {
	r, err := h.svc.SubmitRule(ctx, req.RuleId)
	if err != nil {
		return nil, err
	}
	return SubmitRule200JSONResponse(toRuleView(r)), nil
}

func (h *handler) ApproveRule(ctx context.Context, req ApproveRuleRequestObject) (ApproveRuleResponseObject, error) {
	var note *string
	if req.Body != nil {
		note = req.Body.Note
	}
	r, err := h.svc.ApproveRule(ctx, req.RuleId, note)
	if err != nil {
		return nil, err
	}
	return ApproveRule200JSONResponse(toRuleView(r)), nil
}

func (h *handler) RejectRule(ctx context.Context, req RejectRuleRequestObject) (RejectRuleResponseObject, error) {
	r, err := h.svc.RejectRule(ctx, req.RuleId, req.Body.Note)
	if err != nil {
		return nil, err
	}
	return RejectRule200JSONResponse(toRuleView(r)), nil
}

func toRuleView(r Rule) RuleView {
	return RuleView{
		Id: r.ID, RuleKey: r.RuleKey, Version: r.Version, IssueId: r.IssueID, CropId: r.CropID,
		IssueType: IssueType(r.IssueType), IssueName: r.IssueName, IssueNameTe: r.IssueNameTe,
		SaltId: r.SaltID, SaltName: r.SaltName, SaltNameTe: r.SaltNameTe,
		SkuId: r.SKUID, SkuCode: r.SKUCode, ProductName: r.ProductName, ProductNameTe: r.ProductNameTe,
		DosePerAcre: r.Dose, DosePerAcreTe: r.DoseTe, Status: RuleStatus(r.Status), ChangeNote: r.ChangeNote,
		CreatedBy: r.CreatedBy, CreatedAt: r.CreatedAt, SubmittedBy: r.SubmittedBy, SubmittedAt: r.SubmittedAt,
		ApprovedBy: r.ApprovedBy, ApprovedAt: r.ApprovedAt, RejectedBy: r.RejectedBy, RejectedAt: r.RejectedAt,
		ReviewNote: r.ReviewNote,
	}
}
