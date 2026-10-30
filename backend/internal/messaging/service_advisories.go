package messaging

import (
	"context"
	"encoding/json"
	"slices"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
	"github.com/sapionic/orbit/backend/internal/platform/storage"
)

// Advisory roles: admin, agronomy and ops compose and send; only agronomy
// approves advisories that name a product (and never their own).
var advisoryRoles = []auth.Role{auth.RoleAdmin, auth.RoleAgronomy, auth.RoleOps}

// Page sizes.
const (
	advisoryListDefault   = 50
	advisoryListMax       = 200
	recipientsListDefault = 100
	recipientsListMax     = 500
)

var audioExt = map[string]string{
	"audio/mpeg": ".mp3", "audio/mp4": ".m4a", "audio/aac": ".aac", "audio/ogg": ".ogg", "audio/wav": ".wav",
}

var imageExt = map[string]string{"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}

// CreateAdvisory saves a draft and returns upload URLs for its media.
func (s *Service) CreateAdvisory(ctx context.Context, in AdvisoryInput) (NewAdvisory, error) {
	p, err := auth.RequireRole(ctx, advisoryRoles...)
	if err != nil {
		return NewAdvisory{}, err
	}
	class, channels, err := validateAdvisoryInput(&in)
	if err != nil {
		return NewAdvisory{}, err
	}
	if err := s.checkProductMentions(ctx, in.NamesProduct, &in.TitleTe, &in.BodyTe, in.TitleEn, in.BodyEn); err != nil {
		return NewAdvisory{}, err
	}
	if err := s.scopeTarget(ctx, p, &in.Target); err != nil {
		return NewAdvisory{}, err
	}
	target, err := json.Marshal(in.Target)
	if err != nil {
		return NewAdvisory{}, apperr.Internalf("messaging: marshal target: %w", err)
	}

	id := ids.New()
	var out NewAdvisory
	var audioKey, imageKey *string
	if in.AudioContentType != nil {
		ext, ok := audioExt[*in.AudioContentType]
		if !ok {
			return NewAdvisory{}, apperr.Validation("audio_content_type", "unsupported audio type")
		}
		audioKey = ptr("messaging/advisories/" + id.String() + "/audio" + ext)
		if out.AudioUpload, err = s.presignPut(ctx, *audioKey, *in.AudioContentType); err != nil {
			return NewAdvisory{}, err
		}
	}
	if in.ImageContentType != nil {
		ext, ok := imageExt[*in.ImageContentType]
		if !ok {
			return NewAdvisory{}, apperr.Validation("image_content_type", "unsupported image type")
		}
		imageKey = ptr("messaging/advisories/" + id.String() + "/image" + ext)
		if out.ImageUpload, err = s.presignPut(ctx, *imageKey, *in.ImageContentType); err != nil {
			return NewAdvisory{}, err
		}
	}

	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		row, err := q.CreateAdvisory(ctx, store.CreateAdvisoryParams{
			ID: id, Sender: in.Sender, TitleTe: in.TitleTe, BodyTe: in.BodyTe, TitleEn: in.TitleEn, BodyEn: in.BodyEn,
			AudioKey: audioKey, ImageKey: imageKey, NamesProduct: in.NamesProduct, Class: class,
			Target: target, Channels: channels, CreatedBy: p.ID,
		})
		if err != nil {
			if db.IsForeignKeyViolation(err) {
				return apperr.Forbidden("your HO account was not found")
			}
			return apperr.Internalf("messaging: create advisory: %w", err)
		}
		out.Advisory = toAdvisory(row)
		_, err = audit.Record(ctx, tx, audit.Entry{
			Action: "messaging.advisory_created", EntityType: "advisory", EntityID: id, After: out.Advisory,
		})
		return err
	})
	return out, err
}

func (s *Service) presignPut(ctx context.Context, key, contentType string) (*storage.Presigned, error) {
	u, err := s.deps.Storage.PresignPut(ctx, key, contentType, uploadURLTTL)
	if err != nil {
		return nil, apperr.Internalf("messaging: presign upload: %w", err)
	}
	return &u, nil
}

// validateAdvisoryInput normalises in and returns the class and the stored
// channel list. A message that names a product is promotional (it needs a
// promotional SMS template) and needs Agronomy approval.
func validateAdvisoryInput(in *AdvisoryInput) (string, []string, error) {
	fields := map[string]string{}
	in.TitleTe, in.BodyTe = strings.TrimSpace(in.TitleTe), strings.TrimSpace(in.BodyTe)
	if in.TitleTe == "" {
		fields["title_te"] = "Telugu title is required"
	}
	if in.BodyTe == "" {
		fields["body_te"] = "Telugu text is required"
	}
	in.TitleEn, in.BodyEn = trimOptional(in.TitleEn), trimOptional(in.BodyEn)
	if in.Sender == "" {
		in.Sender = "ho"
	}
	if in.Sender != "ho" && in.Sender != "civ" {
		fields["sender"] = "must be ho or civ"
	}
	class := ClassService
	if in.NamesProduct {
		class = ClassPromotional
	}
	if in.Class != nil {
		if *in.Class != ClassService && *in.Class != ClassPromotional {
			fields["class"] = "must be service or promotional"
		} else if in.NamesProduct && *in.Class == ClassService {
			fields["class"] = "a message that names a product is promotional"
		} else {
			class = *in.Class
		}
	}
	channels := dedupe(in.Channels)
	for _, c := range channels {
		if !slices.Contains([]string{ChannelPush, ChannelSMS, ChannelWhatsApp, ChannelInApp}, c) {
			fields["channels"] = "unknown channel " + c
		}
	}
	if len(channels) == 0 {
		fields["channels"] = "pick at least one channel"
	}
	if in.Target.Plan != nil && *in.Target.Plan != "free" && *in.Target.Plan != "premium" {
		fields["target.plan"] = "must be free or premium"
	}
	if len(fields) > 0 {
		return "", nil, apperr.ValidationFields(fields)
	}
	// Every recipient gets an in-app notice; store in_app so the list says so.
	if !slices.Contains(channels, ChannelInApp) {
		channels = append(channels, ChannelInApp)
	}
	in.Target.normalize()
	return class, channels, nil
}

func trimOptional(s *string) *string {
	if s == nil {
		return nil
	}
	t := strings.TrimSpace(*s)
	if t == "" {
		return nil
	}
	return &t
}

// scopeTarget applies the HO user's area scope to t. For a scoped user the
// given district_ids must all be inside the scope (403 otherwise) and an empty
// list becomes the scope. That is enough to keep the audience inside the
// scope because FarmerIDsForTargeting ANDs every non-empty list: a village or
// mandal filter only narrows within those districts, and a mandal from another
// district matches nobody. Villages are also checked here (they must exist,
// and a scoped user may not name one outside the scope) so the mistake is
// reported instead of silently reaching nobody; mandals cannot be looked up
// through the geo port. Lists are deduplicated.
func (s *Service) scopeTarget(ctx context.Context, p auth.Principal, t *Target) error {
	t.normalize()
	t.DistrictIDs, t.MandalIDs, t.VillageIDs = dedupe(t.DistrictIDs), dedupe(t.MandalIDs), dedupe(t.VillageIDs)
	t.CropIDs, t.StageCodes = dedupe(t.CropIDs), dedupe(t.StageCodes)
	if p.HasAreaScope() {
		if len(t.DistrictIDs) == 0 {
			t.DistrictIDs = slices.Clone(p.DistrictIDs)
		}
		for _, d := range t.DistrictIDs {
			if !p.CanSeeDistrict(d) {
				return apperr.Forbidden("you can only send advisories to your own districts")
			}
		}
	}
	if len(t.VillageIDs) == 0 {
		return nil
	}
	vs, err := s.ports.Geo.GetVillages(ctx, t.VillageIDs)
	if err != nil {
		return apperr.Internalf("messaging: villages: %w", err)
	}
	found := make(map[uuid.UUID]uuid.UUID, len(vs))
	for _, v := range vs {
		found[v.ID] = v.DistrictID
	}
	for _, id := range t.VillageIDs {
		district, ok := found[id]
		if !ok {
			return apperr.Validation("target.village_ids", "unknown village "+id.String())
		}
		if p.HasAreaScope() && !p.CanSeeDistrict(district) {
			return apperr.Forbidden("you can only send advisories to your own districts")
		}
	}
	return nil
}

// visible reports whether an HO user may see an advisory: users with an area
// scope see advisories whose target names districts, all inside their scope.
func visible(p auth.Principal, a AdvisoryRecord) bool {
	if !p.HasAreaScope() {
		return true
	}
	if len(a.Target.DistrictIDs) == 0 {
		return false
	}
	for _, d := range a.Target.DistrictIDs {
		if !p.CanSeeDistrict(d) {
			return false
		}
	}
	return true
}

// PreviewRecipients counts the farmers the target reaches now.
func (s *Service) PreviewRecipients(ctx context.Context, t Target) (int, error) {
	p, err := auth.RequireRole(ctx, advisoryRoles...)
	if err != nil {
		return 0, err
	}
	if err := s.scopeTarget(ctx, p, &t); err != nil {
		return 0, err
	}
	farmerIDs, err := s.ports.Farmers.FarmerIDsForTargeting(ctx, t.toXmod())
	if err != nil {
		return 0, apperr.Internalf("messaging: targeting: %w", err)
	}
	return len(farmerIDs), nil
}

// GetAdvisory returns one advisory with its reach so far and preview URLs.
func (s *Service) GetAdvisory(ctx context.Context, id uuid.UUID) (AdvisoryRecord, error) {
	p, err := auth.RequireRole(ctx, advisoryRoles...)
	if err != nil {
		return AdvisoryRecord{}, err
	}
	row, err := s.q.GetAdvisory(ctx, id)
	if err != nil {
		return AdvisoryRecord{}, notFoundOr(err, "advisory")
	}
	a := toAdvisory(row)
	if !visible(p, a) {
		return AdvisoryRecord{}, apperr.NotFound("advisory")
	}
	st, err := s.q.AdvisoryStats(ctx, someUUID(id))
	if err != nil {
		return AdvisoryRecord{}, apperr.Internalf("messaging: advisory stats: %w", err)
	}
	stats := Reach{Notices: int(st.Notices), Read: int(st.Read), Listened: int(st.Listened), Deliveries: map[string]int{}}
	_ = json.Unmarshal(st.Deliveries, &stats.Deliveries)
	a.Stats = &stats
	a.AudioURL, a.ImageURL = s.presignGet(ctx, a.AudioKey), s.presignGet(ctx, a.ImageKey)
	return a, nil
}

// ListAdvisories lists advisories newest first.
func (s *Service) ListAdvisories(ctx context.Context, status *string, limit *int, cursor *string) (paging.Page[AdvisoryRecord], error) {
	p, err := auth.RequireRole(ctx, advisoryRoles...)
	if err != nil {
		return paging.Page[AdvisoryRecord]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[AdvisoryRecord]{}, err
	}
	n := paging.Limit(limit, advisoryListDefault, advisoryListMax)
	arg := store.ListAdvisoriesParams{Status: status, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1)}
	if p.HasAreaScope() {
		arg.ScopeDistrictIds = p.DistrictIDs
	}
	rows, err := s.q.ListAdvisories(ctx, arg)
	if err != nil {
		return paging.Page[AdvisoryRecord]{}, apperr.Internalf("messaging: list advisories: %w", err)
	}
	page := paging.Build(rows, n, func(r store.Advisory) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} })
	return paging.Map(page, toAdvisory), nil
}

// ListRecipients lists the farmers an advisory reached, with delivery status.
func (s *Service) ListRecipients(ctx context.Context, id uuid.UUID, limit *int, cursor *string) (paging.Page[RecipientStatus], error) {
	if _, err := s.GetAdvisory(ctx, id); err != nil { // role, existence and scope
		return paging.Page[RecipientStatus]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[RecipientStatus]{}, err
	}
	n := paging.Limit(limit, recipientsListDefault, recipientsListMax)
	rows, err := s.q.ListAdvisoryRecipients(ctx, store.ListAdvisoryRecipientsParams{
		AdvisoryID: someUUID(id), CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[RecipientStatus]{}, apperr.Internalf("messaging: recipients: %w", err)
	}
	page := paging.Build(rows, n, func(r store.ListAdvisoryRecipientsRow) paging.Cursor {
		return paging.Cursor{At: r.CreatedAt, ID: r.ID}
	})
	out := paging.Map(page, func(r store.ListAdvisoryRecipientsRow) RecipientStatus {
		out := RecipientStatus{NoticeID: r.ID, FarmerID: r.FarmerID, CreatedAt: r.CreatedAt.UTC(),
			ReadAt: utcPtr(r.ReadAt), ListenedAt: utcPtr(r.ListenedAt), Deliveries: []ChannelDelivery{}}
		_ = json.Unmarshal(r.Deliveries, &out.Deliveries)
		return out
	})
	// Names and masked phones from the farmers module, one call per page.
	farmerIDs := make([]uuid.UUID, len(out.Items))
	for i, r := range out.Items {
		farmerIDs[i] = r.FarmerID
	}
	farmers, err := s.farmerSummaries(ctx, dedupe(farmerIDs))
	if err != nil { // names are a convenience; the delivery status still shows
		logx.From(ctx).WarnContext(ctx, "messaging: farmer names for recipients", "err", err)
		return out, nil
	}
	for i, r := range out.Items {
		f, ok := farmers[r.FarmerID]
		if !ok {
			continue
		}
		out.Items[i].FarmerName, out.Items[i].FarmerNameTe = f.Name, f.NameTe
		if f.Phone != "" {
			out.Items[i].PhoneMasked = ptr(phone.Mask(f.Phone))
		}
	}
	return out, nil
}

func notFoundOr(err error, entity string) error {
	if db.IsNoRows(err) {
		return apperr.NotFound(entity)
	}
	return apperr.Internalf("messaging: get %s: %w", entity, err)
}
