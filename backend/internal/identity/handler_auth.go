package identity

import "context"

// The spec marks every request body below as required, so request
// validation guarantees Body is non-nil before these run.

func (h *handler) RequestOtp(ctx context.Context, req RequestOtpRequestObject) (RequestOtpResponseObject, error) {
	lang := "te"
	if req.Body.Language != nil {
		lang = string(*req.Body.Language)
	}
	out, err := h.svc.RequestOTP(ctx, req.Body.Phone, lang)
	if err != nil {
		return nil, err
	}
	return RequestOtp200JSONResponse{PhoneMasked: out.PhoneMasked, ExpiresInSeconds: int(out.ExpiresIn.Seconds()),
		ResendAfterSeconds: int(out.ResendAfter.Seconds())}, nil
}

func (h *handler) VerifyOtp(ctx context.Context, req VerifyOtpRequestObject) (VerifyOtpResponseObject, error) {
	out, err := h.svc.VerifyOTP(ctx, req.Body.Phone, req.Body.Code, appDevice(req.Body.Device))
	if err != nil {
		return nil, err
	}
	var status *FarmerSessionFarmerStatus
	if out.FarmerStatus != nil {
		s := FarmerSessionFarmerStatus(*out.FarmerStatus)
		status = &s
	}
	return VerifyOtp200JSONResponse{Tokens: tokensDTO(out.Tokens), FarmerId: out.FarmerID, DeviceId: out.DeviceID,
		IsNew: out.IsNew, FarmerStatus: status}, nil
}

func (h *handler) FaLogin(ctx context.Context, req FaLoginRequestObject) (FaLoginResponseObject, error) {
	out, err := h.svc.FALogin(ctx, req.Body.Code, req.Body.Password, appDevice(req.Body.Device))
	if err != nil {
		return nil, err
	}
	pol := out.OfflineRules
	return FaLogin200JSONResponse{
		Tokens: tokensDTO(out.Tokens), DeviceId: out.DeviceID, FieldAssistant: faDTO(out.FA),
		MustChangePassword: out.FA.MustChangePassword,
		OfflinePolicy:      OfflinePolicy{PinLength: pol.PinLength, OfflineGraceDays: pol.OfflineGraceDays, PinMaxAttempts: pol.PinMaxAttempts},
	}, nil
}

func (h *handler) HoLogin(ctx context.Context, req HoLoginRequestObject) (HoLoginResponseObject, error) {
	out, err := h.svc.HOLogin(ctx, req.Body.Email, req.Body.Password, req.Body.TotpCode)
	if err != nil {
		return nil, err
	}
	return HoLogin200JSONResponse(hoSessionDTO(out)), nil
}

func (h *handler) StartTotpEnrolment(ctx context.Context, req StartTotpEnrolmentRequestObject) (StartTotpEnrolmentResponseObject, error) {
	out, err := h.svc.StartTOTPEnrolment(ctx, req.Body.Email, req.Body.Password)
	if err != nil {
		return nil, err
	}
	return StartTotpEnrolment200JSONResponse{OtpauthUrl: out.URL, Secret: out.Secret}, nil
}

func (h *handler) ConfirmTotpEnrolment(ctx context.Context, req ConfirmTotpEnrolmentRequestObject) (ConfirmTotpEnrolmentResponseObject, error) {
	out, err := h.svc.ConfirmTOTPEnrolment(ctx, req.Body.Email, req.Body.Password, req.Body.TotpCode)
	if err != nil {
		return nil, err
	}
	return ConfirmTotpEnrolment200JSONResponse(hoSessionDTO(out)), nil
}

func (h *handler) RefreshSession(ctx context.Context, req RefreshSessionRequestObject) (RefreshSessionResponseObject, error) {
	out, err := h.svc.Refresh(ctx, req.Body.RefreshToken)
	if err != nil {
		return nil, err
	}
	return RefreshSession200JSONResponse(tokensDTO(out)), nil
}

func (h *handler) Logout(ctx context.Context, req LogoutRequestObject) (LogoutResponseObject, error) {
	var token *string
	if req.Body != nil {
		token = req.Body.RefreshToken
	}
	if err := h.svc.Logout(ctx, token); err != nil {
		return nil, err
	}
	return Logout204Response{}, nil
}

func (h *handler) ChangeFAPassword(ctx context.Context, req ChangeFAPasswordRequestObject) (ChangeFAPasswordResponseObject, error) {
	if err := h.svc.ChangeFAPassword(ctx, req.Body.CurrentPassword, req.Body.NewPassword); err != nil {
		return nil, err
	}
	return ChangeFAPassword204Response{}, nil
}

func (h *handler) GetMe(ctx context.Context, _ GetMeRequestObject) (GetMeResponseObject, error) {
	u, err := h.svc.Me(ctx)
	if err != nil {
		return nil, err
	}
	return GetMe200JSONResponse(hoDTO(u)), nil
}

func (h *handler) ChangeHOPassword(ctx context.Context, req ChangeHOPasswordRequestObject) (ChangeHOPasswordResponseObject, error) {
	if err := h.svc.ChangeHOPassword(ctx, req.Body.CurrentPassword, req.Body.NewPassword); err != nil {
		return nil, err
	}
	return ChangeHOPassword204Response{}, nil
}
