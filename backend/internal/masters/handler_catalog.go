package masters

import "context"

// ---- salts ----

func (h *handler) ListSalts(ctx context.Context, req ListSaltsRequestObject) (ListSaltsResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListSalts(ctx, p.Active, p.Q, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	items, next := mapPage(page, toSaltView)
	return ListSalts200JSONResponse(SaltPage{Items: items, NextCursor: next}), nil
}

func (h *handler) CreateSalt(ctx context.Context, req CreateSaltRequestObject) (CreateSaltResponseObject, error) {
	s, err := h.svc.CreateSalt(ctx, req.Body.Name, req.Body.NameTe)
	if err != nil {
		return nil, err
	}
	return CreateSalt201JSONResponse(toSaltView(s)), nil
}

func (h *handler) UpdateSalt(ctx context.Context, req UpdateSaltRequestObject) (UpdateSaltResponseObject, error) {
	b := req.Body
	s, err := h.svc.UpdateSalt(ctx, req.SaltId, SaltPatch{Name: b.Name, NameTe: b.NameTe, Active: b.Active})
	if err != nil {
		return nil, err
	}
	return UpdateSalt200JSONResponse(toSaltView(s)), nil
}

func toSaltView(s Salt) SaltView {
	return SaltView{Id: s.ID, Name: s.Name, NameTe: s.NameTe, Active: s.Active, CreatedAt: s.CreatedAt}
}

// ---- SKUs ----

func (h *handler) ListSkus(ctx context.Context, req ListSkusRequestObject) (ListSkusResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListSKUs(ctx, p.SaltId, p.Active, p.Q, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	items, next := mapPage(page, toSkuView)
	return ListSkus200JSONResponse(SkuPage{Items: items, NextCursor: next}), nil
}

func (h *handler) CreateSku(ctx context.Context, req CreateSkuRequestObject) (CreateSkuResponseObject, error) {
	b := req.Body
	k, err := h.svc.CreateSKU(ctx, SKUInput{
		Code: b.Code, ProductName: b.ProductName, ProductNameTe: b.ProductNameTe, SaltID: b.SaltId,
		PackSize: b.PackSize, MRPPaise: b.MrpPaise, CashbackEligible: b.CashbackEligible,
	})
	if err != nil {
		return nil, err
	}
	return CreateSku201JSONResponse(toSkuView(k)), nil
}

func (h *handler) UpdateSku(ctx context.Context, req UpdateSkuRequestObject) (UpdateSkuResponseObject, error) {
	b := req.Body
	k, err := h.svc.UpdateSKU(ctx, req.SkuId, SKUPatch{
		ProductName: b.ProductName, ProductNameTe: b.ProductNameTe, SaltID: b.SaltId, PackSize: b.PackSize,
		MRPPaise: b.MrpPaise, CashbackEligible: b.CashbackEligible, Active: b.Active,
	})
	if err != nil {
		return nil, err
	}
	return UpdateSku200JSONResponse(toSkuView(k)), nil
}

func toSkuView(k SKU) SkuView {
	return SkuView{
		Id: k.ID, Code: k.Code, ProductName: k.ProductName, ProductNameTe: k.ProductNameTe, SaltId: k.SaltID,
		PackSize: k.PackSize, MrpPaise: k.MRPPaise, CashbackEligible: k.CashbackEligible, Active: k.Active,
		CreatedAt: k.CreatedAt, UpdatedAt: k.UpdatedAt,
	}
}

// ---- issues ----

func (h *handler) ListIssues(ctx context.Context, req ListIssuesRequestObject) (ListIssuesResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListIssues(ctx, p.CropId, (*string)(p.Type), p.Active, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	items, next := mapPage(page, toIssueView)
	return ListIssues200JSONResponse(IssuePage{Items: items, NextCursor: next}), nil
}

func (h *handler) CreateIssue(ctx context.Context, req CreateIssueRequestObject) (CreateIssueResponseObject, error) {
	b := req.Body
	i, err := h.svc.CreateIssue(ctx, IssueInput{CropID: b.CropId, Type: string(b.Type), Name: b.Name, NameTe: b.NameTe})
	if err != nil {
		return nil, err
	}
	return CreateIssue201JSONResponse(toIssueView(i)), nil
}

func (h *handler) UpdateIssue(ctx context.Context, req UpdateIssueRequestObject) (UpdateIssueResponseObject, error) {
	b := req.Body
	i, err := h.svc.UpdateIssue(ctx, req.IssueId, IssuePatch{Type: (*string)(b.Type), Name: b.Name, NameTe: b.NameTe, Active: b.Active})
	if err != nil {
		return nil, err
	}
	return UpdateIssue200JSONResponse(toIssueView(i)), nil
}

func toIssueView(i Issue) IssueView {
	return IssueView{
		Id: i.ID, CropId: i.CropID, Type: IssueType(i.Type), Name: i.Name, NameTe: i.NameTe,
		Active: i.Active, CreatedAt: i.CreatedAt,
	}
}
