package identity

import "context"

func (h *handler) RequestConsentOtp(ctx context.Context, req RequestConsentOtpRequestObject) (RequestConsentOtpResponseObject, error) {
	lang := "te"
	if req.Body.Language != nil {
		lang = string(*req.Body.Language)
	}
	out, err := h.svc.RequestConsentOTP(ctx, req.Body.Phone, lang)
	if err != nil {
		return nil, err
	}
	return RequestConsentOtp200JSONResponse{PhoneMasked: out.PhoneMasked, ExpiresInSeconds: int(out.ExpiresIn.Seconds()),
		ResendAfterSeconds: int(out.ResendAfter.Seconds())}, nil
}

func (h *handler) VerifyConsentOtp(ctx context.Context, req VerifyConsentOtpRequestObject) (VerifyConsentOtpResponseObject, error) {
	out, err := h.svc.VerifyConsentOTP(ctx, req.Body.Phone, req.Body.Code)
	if err != nil {
		return nil, err
	}
	return VerifyConsentOtp200JSONResponse{Phone: out.Phone, OtpProof: out.Proof, VerifiedAt: out.VerifiedAt, ExpiresAt: out.ExpiresAt}, nil
}
