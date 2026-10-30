package identity

import (
	"context"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
)

func (h *handler) FaDeviceHeartbeat(ctx context.Context, req FaDeviceHeartbeatRequestObject) (FaDeviceHeartbeatResponseObject, error) {
	out, err := h.svc.Heartbeat(ctx, auth.KindFA, heartbeat(req.Body))
	if err != nil {
		return nil, err
	}
	return FaDeviceHeartbeat200JSONResponse(heartbeatDTO(out)), nil
}

func (h *handler) FarmerDeviceHeartbeat(ctx context.Context, req FarmerDeviceHeartbeatRequestObject) (FarmerDeviceHeartbeatResponseObject, error) {
	out, err := h.svc.Heartbeat(ctx, auth.KindFarmer, heartbeat(req.Body))
	if err != nil {
		return nil, err
	}
	return FarmerDeviceHeartbeat200JSONResponse(heartbeatDTO(out)), nil
}

func (h *handler) ListDevices(ctx context.Context, req ListDevicesRequestObject) (ListDevicesResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListDevices(ctx, string(p.SubjectKind), p.SubjectId, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	items := make([]Device, len(page.Items))
	for i, d := range page.Items {
		items[i] = deviceDTO(d)
	}
	return ListDevices200JSONResponse{Items: items, NextCursor: page.NextCursor}, nil
}

func (h *handler) RevokeDevice(ctx context.Context, req RevokeDeviceRequestObject) (RevokeDeviceResponseObject, error) {
	d, err := h.svc.RevokeDevice(ctx, req.DeviceId, req.Body.Reason)
	if err != nil {
		return nil, err
	}
	return RevokeDevice200JSONResponse(deviceDTO(d)), nil
}

// appConfigCache lets clients and CDNs reuse the release settings for a while.
const appConfigCache = "public, max-age=300"

func (h *handler) GetAppConfig(_ context.Context, req GetAppConfigRequestObject) (GetAppConfigResponseObject, error) {
	r, err := h.svc.AppConfig(string(req.Params.App))
	if err != nil {
		return nil, err
	}
	var store *string
	if r.StoreURL != "" {
		store = &r.StoreURL
	}
	cc := appConfigCache
	return GetAppConfig200JSONResponse{
		Body: AppConfig{App: AppConfigApp(req.Params.App), MinVersion: r.MinVersion, LatestVersion: r.LatestVersion,
			StoreUrl: store, Flags: r.Flags},
		Headers: GetAppConfig200ResponseHeaders{CacheControl: &cc},
	}, nil
}
