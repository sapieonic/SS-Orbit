package identity

import (
	"context"

	"github.com/google/uuid"
)

// ---- FA logins ----

func (h *handler) ListFieldAssistants(ctx context.Context, req ListFieldAssistantsRequestObject) (ListFieldAssistantsResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListFAs(ctx, FAFilter{Q: p.Q, Status: strPtr(p.Status), NotSyncedSince: p.NotSyncedSince}, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	return ListFieldAssistants200JSONResponse(faPageDTO(page)), nil
}

func (h *handler) GetFieldAssistantStats(ctx context.Context, _ GetFieldAssistantStatsRequestObject) (GetFieldAssistantStatsResponseObject, error) {
	c, err := h.svc.FAStats(ctx)
	if err != nil {
		return nil, err
	}
	return GetFieldAssistantStats200JSONResponse{Active: c.Active, Leaving: c.Leaving, Inactive: c.Inactive, SyncedLast24h: c.SyncedLast24h}, nil
}

func (h *handler) CreateFieldAssistant(ctx context.Context, req CreateFieldAssistantRequestObject) (CreateFieldAssistantResponseObject, error) {
	b := req.Body
	in := FACreate{Code: b.Code, AreaCode: b.AreaCode, Name: b.Name, NameTe: b.NameTe, Phone: b.Phone,
		Level: string(b.Level), WorkingHours: b.WorkingHours, PhotoKey: b.PhotoKey}
	if b.Languages != nil {
		in.Languages = *b.Languages
	}
	fa, temp, err := h.svc.CreateFA(ctx, in)
	if err != nil {
		return nil, err
	}
	return CreateFieldAssistant201JSONResponse{FieldAssistant: faDTO(fa), TempPassword: temp}, nil
}

func (h *handler) GetFieldAssistant(ctx context.Context, req GetFieldAssistantRequestObject) (GetFieldAssistantResponseObject, error) {
	fa, err := h.svc.GetFA(ctx, req.FaId)
	if err != nil {
		return nil, err
	}
	return GetFieldAssistant200JSONResponse(faDTO(fa)), nil
}

func (h *handler) UpdateFieldAssistant(ctx context.Context, req UpdateFieldAssistantRequestObject) (UpdateFieldAssistantResponseObject, error) {
	b := req.Body
	fa, err := h.svc.UpdateFA(ctx, req.FaId, FAPatch{Name: b.Name, NameTe: b.NameTe, Phone: b.Phone, Level: strPtr(b.Level),
		Languages: b.Languages, WorkingHours: b.WorkingHours, PhotoKey: b.PhotoKey})
	if err != nil {
		return nil, err
	}
	return UpdateFieldAssistant200JSONResponse(faDTO(fa)), nil
}

func (h *handler) SetFieldAssistantStatus(ctx context.Context, req SetFieldAssistantStatusRequestObject) (SetFieldAssistantStatusResponseObject, error) {
	fa, err := h.svc.SetFAStatus(ctx, req.FaId, string(req.Body.Status))
	if err != nil {
		return nil, err
	}
	return SetFieldAssistantStatus200JSONResponse(faDTO(fa)), nil
}

func (h *handler) ResetFieldAssistantPassword(ctx context.Context, req ResetFieldAssistantPasswordRequestObject) (ResetFieldAssistantPasswordResponseObject, error) {
	temp, err := h.svc.ResetFAPassword(ctx, req.FaId)
	if err != nil {
		return nil, err
	}
	return ResetFieldAssistantPassword200JSONResponse{TempPassword: temp}, nil
}

func (h *handler) SignOutFieldAssistant(ctx context.Context, req SignOutFieldAssistantRequestObject) (SignOutFieldAssistantResponseObject, error) {
	if err := h.svc.SignOutFA(ctx, req.FaId); err != nil {
		return nil, err
	}
	return SignOutFieldAssistant204Response{}, nil
}

// ---- HO users ----

func (h *handler) ListHOUsers(ctx context.Context, req ListHOUsersRequestObject) (ListHOUsersResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListHOAccounts(ctx, HOFilter{Q: p.Q, Role: strPtr(p.Role), Status: strPtr(p.Status)}, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	return ListHOUsers200JSONResponse(hoPageDTO(page)), nil
}

func (h *handler) GetHOUserDirectory(ctx context.Context, _ GetHOUserDirectoryRequestObject) (GetHOUserDirectoryResponseObject, error) {
	list, err := h.svc.HODirectory(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]HOUserDirectoryEntry, len(list))
	for i, u := range list {
		items[i] = HOUserDirectoryEntry{Id: u.ID, Name: u.Name, Role: HORole(u.Role), Status: HOStatus(u.Status)}
	}
	return GetHOUserDirectory200JSONResponse{Items: items}, nil
}

func (h *handler) CreateHOUser(ctx context.Context, req CreateHOUserRequestObject) (CreateHOUserResponseObject, error) {
	b := req.Body
	in := NewHOAccount{Email: b.Email, Name: b.Name, Role: string(b.Role)}
	if b.DistrictIds != nil {
		in.DistrictIDs = *b.DistrictIds
	}
	u, temp, err := h.svc.CreateHOAccount(ctx, in)
	if err != nil {
		return nil, err
	}
	return CreateHOUser201JSONResponse{User: hoDTO(u), TempPassword: temp}, nil
}

func (h *handler) GetHOUser(ctx context.Context, req GetHOUserRequestObject) (GetHOUserResponseObject, error) {
	u, err := h.svc.GetHOAccount(ctx, req.UserId)
	if err != nil {
		return nil, err
	}
	return GetHOUser200JSONResponse(hoDTO(u)), nil
}

func (h *handler) UpdateHOUser(ctx context.Context, req UpdateHOUserRequestObject) (UpdateHOUserResponseObject, error) {
	b := req.Body
	var districts *[]uuid.UUID
	if b.DistrictIds != nil {
		d := *b.DistrictIds
		districts = &d
	}
	u, err := h.svc.UpdateHOAccount(ctx, req.UserId, HOAccountPatch{Name: b.Name, Role: strPtr(b.Role), DistrictIDs: districts})
	if err != nil {
		return nil, err
	}
	return UpdateHOUser200JSONResponse(hoDTO(u)), nil
}

func (h *handler) SetHOUserStatus(ctx context.Context, req SetHOUserStatusRequestObject) (SetHOUserStatusResponseObject, error) {
	u, err := h.svc.SetHOAccountStatus(ctx, req.UserId, string(req.Body.Status))
	if err != nil {
		return nil, err
	}
	return SetHOUserStatus200JSONResponse(hoDTO(u)), nil
}

func (h *handler) ResetHOUserPassword(ctx context.Context, req ResetHOUserPasswordRequestObject) (ResetHOUserPasswordResponseObject, error) {
	temp, err := h.svc.ResetHOPassword(ctx, req.UserId)
	if err != nil {
		return nil, err
	}
	return ResetHOUserPassword200JSONResponse{TempPassword: temp}, nil
}

func (h *handler) ResetHOUserTotp(ctx context.Context, req ResetHOUserTotpRequestObject) (ResetHOUserTotpResponseObject, error) {
	if err := h.svc.ResetHOTOTP(ctx, req.UserId); err != nil {
		return nil, err
	}
	return ResetHOUserTotp204Response{}, nil
}
