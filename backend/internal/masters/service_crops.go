package masters

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/masters/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// ListCrops lists crops with all their stages, oldest first.
func (s *Service) ListCrops(ctx context.Context, active *bool, limit *int, cursor *string) (paging.Page[Crop], error) {
	if err := requireRead(ctx); err != nil {
		return paging.Page[Crop]{}, err
	}
	cur, n, err := pageArgs(limit, cursor)
	if err != nil {
		return paging.Page[Crop]{}, err
	}
	rows, err := s.q.ListCrops(ctx, store.ListCropsParams{
		Active: active, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[Crop]{}, apperr.Internalf("masters: list crops: %w", err)
	}
	page := paging.Build(rows, n, func(c store.Crop) paging.Cursor { return paging.Cursor{At: c.CreatedAt, ID: c.ID} })
	crops, err := withStages(ctx, s.q, page.Items, true)
	if err != nil {
		return paging.Page[Crop]{}, err
	}
	return paging.Page[Crop]{Items: crops, NextCursor: page.NextCursor}, nil
}

// GetCrop returns one crop with every stage, inactive ones included.
func (s *Service) GetCrop(ctx context.Context, id uuid.UUID) (Crop, error) {
	if err := requireRead(ctx); err != nil {
		return Crop{}, err
	}
	return loadCrop(ctx, s.q, id)
}

// CreateCrop adds a crop and, optionally, its stage calendar.
func (s *Service) CreateCrop(ctx context.Context, in CropInput) (Crop, error) {
	if _, err := requireWrite(ctx); err != nil {
		return Crop{}, err
	}
	errs := map[string]string{}
	in.Name = text("name", in.Name, errs)
	in.NameTe = text("name_te", in.NameTe, errs)
	stages := cleanStages(in.Stages, errs)
	if err := validationErr(errs); err != nil {
		return Crop{}, err
	}

	var out Crop
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		c, err := q.CreateCrop(ctx, store.CreateCropParams{
			ID: ids.New(), Code: in.Code, Name: in.Name, NameTe: in.NameTe, DurationDays: in.DurationDays,
		})
		if err != nil {
			if dup := duplicate(err, "code"); dup != nil {
				return dup
			}
			return apperr.Internalf("masters: create crop: %w", err)
		}
		if err := saveStages(ctx, q, c.ID, stages); err != nil {
			return err
		}
		if out, err = loadCrop(ctx, q, c.ID); err != nil {
			return err
		}
		return s.recordPublished(ctx, tx, q, "masters.crop_created", "crop", c.ID, nil, out)
	})
	return out, err
}

// UpdateCrop edits or (de)activates a crop. A deactivated crop disappears from
// the apps' crop lists; its seasons, issues and stages stay as they are.
func (s *Service) UpdateCrop(ctx context.Context, id uuid.UUID, p CropPatch) (Crop, error) {
	if _, err := requireWrite(ctx); err != nil {
		return Crop{}, err
	}
	errs := map[string]string{}
	p.Name = optText("name", p.Name, errs)
	p.NameTe = optText("name_te", p.NameTe, errs)
	if err := validationErr(errs); err != nil {
		return Crop{}, err
	}

	var out Crop
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if _, err := q.GetCropForUpdate(ctx, id); err != nil {
			return notFound(err, "crop")
		}
		before, err := loadCrop(ctx, q, id)
		if err != nil {
			return err
		}
		if _, err := q.UpdateCrop(ctx, store.UpdateCropParams{
			ID: id, Name: p.Name, NameTe: p.NameTe, DurationDays: p.DurationDays, Active: p.Active,
		}); err != nil {
			return apperr.Internalf("masters: update crop: %w", err)
		}
		if out, err = loadCrop(ctx, q, id); err != nil {
			return err
		}
		return s.recordPublished(ctx, tx, q, "masters.crop_updated", "crop", id, before, out)
	})
	return out, err
}

// ReplaceStages saves a crop's whole stage calendar. Stages are matched by
// code; the listed ones are created or updated and numbered in list order,
// the rest are deactivated (never deleted: seasons and visits point at them).
func (s *Service) ReplaceStages(ctx context.Context, cropID uuid.UUID, in []StageInput) (Crop, error) {
	if _, err := requireWrite(ctx); err != nil {
		return Crop{}, err
	}
	errs := map[string]string{}
	stages := cleanStages(in, errs)
	if len(stages) == 0 && len(errs) == 0 {
		errs["stages"] = "at least one stage is required"
	}
	if err := validationErr(errs); err != nil {
		return Crop{}, err
	}

	var out Crop
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if _, err := q.GetCropForUpdate(ctx, cropID); err != nil {
			return notFound(err, "crop")
		}
		before, err := loadCrop(ctx, q, cropID)
		if err != nil {
			return err
		}
		if err := q.DeactivateStages(ctx, cropID); err != nil {
			return apperr.Internalf("masters: deactivate stages: %w", err)
		}
		if err := saveStages(ctx, q, cropID, stages); err != nil {
			return err
		}
		if out, err = loadCrop(ctx, q, cropID); err != nil {
			return err
		}
		return s.recordPublished(ctx, tx, q, "masters.stages_replaced", "crop", cropID, before.Stages, out.Stages)
	})
	return out, err
}

// GetStagesForDay is the provider method for farmers (CONVENTIONS section 5):
// the active stage whose start_day..end_day contains daysAfterSowing. Before
// the first stage it returns the first; after the last, the last; in a gap
// between two stages, the one that started most recently.
func (s *Service) GetStagesForDay(ctx context.Context, cropID uuid.UUID, daysAfterSowing int) (xmod.Stage, error) {
	rows, err := s.q.ListActiveStagesForCrop(ctx, cropID)
	if err != nil {
		return xmod.Stage{}, apperr.Internalf("masters: stages for crop: %w", err)
	}
	if len(rows) == 0 {
		return xmod.Stage{}, apperr.NotFound("crop stages")
	}
	st := pickStage(rows, daysAfterSowing)
	return xmod.Stage{
		ID: st.ID, CropID: st.CropID, Code: st.Code, Name: st.Name, NameTe: st.NameTe,
		Seq: st.Seq, StartDay: st.StartDay, EndDay: st.EndDay,
	}, nil
}

// pickStage chooses the stage for a day from stages sorted by seq (which is
// also start_day order, see cleanStages).
func pickStage(stages []store.CropStage, day int) store.CropStage {
	best := stages[0]
	for _, st := range stages[1:] {
		if int(st.StartDay) <= day {
			best = st
		}
	}
	return best
}

// FarmerCrops returns active crops with their active stages, cached per
// masters version, and today's season codes.
func (s *Service) FarmerCrops(ctx context.Context) (FarmerCrops, error) {
	v, err := s.CurrentVersion(ctx)
	if err != nil {
		return FarmerCrops{}, err
	}
	var out FarmerCrops
	if !s.deps.Cache.GetJSON(ctx, cacheKey(v, cacheFarmerCrops), &out) {
		err = s.readSnapshot(ctx, func(q *store.Queries) error {
			var err error
			if out.Version, err = currentVersion(ctx, q); err != nil {
				return err
			}
			out.Crops, err = activeCrops(ctx, q)
			return err
		})
		if err != nil {
			return FarmerCrops{}, err
		}
		s.deps.Cache.SetJSON(ctx, cacheKey(out.Version, cacheFarmerCrops), out, cacheTTL)
	}
	out.SeasonCodes = SeasonCodesAt(s.deps.Clock.Now()) // by date, not cached
	return out, nil
}

// activeCrops loads active crops with their active stages.
func activeCrops(ctx context.Context, q *store.Queries) ([]Crop, error) {
	rows, err := q.ListActiveCrops(ctx)
	if err != nil {
		return nil, apperr.Internalf("masters: active crops: %w", err)
	}
	return withStages(ctx, q, rows, false)
}

// cleanStages trims and checks a calendar: codes unique, start <= end, and
// day ranges ascending without overlap (so seq order is start_day order).
func cleanStages(in []StageInput, errs map[string]string) []StageInput {
	out := make([]StageInput, len(in))
	seen := map[string]bool{}
	for i, st := range in {
		f := fmt.Sprintf("stages[%d]", i)
		st.Name = text(f+".name", st.Name, errs)
		st.NameTe = text(f+".name_te", st.NameTe, errs)
		if seen[st.Code] {
			errs[f+".code"] = "duplicate stage code"
		}
		seen[st.Code] = true
		if st.EndDay < st.StartDay {
			errs[f+".end_day"] = "must not be before start_day"
		}
		if i > 0 && st.StartDay <= in[i-1].EndDay {
			errs[f+".start_day"] = "must be after the previous stage's end_day"
		}
		out[i] = st
	}
	return out
}

// saveStages upserts stages by code with seq = position + 1.
func saveStages(ctx context.Context, q *store.Queries, cropID uuid.UUID, stages []StageInput) error {
	for i, st := range stages {
		if _, err := q.UpsertStage(ctx, store.UpsertStageParams{
			ID: ids.New(), CropID: cropID, Code: st.Code, Name: st.Name, NameTe: st.NameTe,
			Seq: int32(i + 1), StartDay: st.StartDay, EndDay: st.EndDay,
		}); err != nil {
			return apperr.Internalf("masters: save stage %s: %w", st.Code, err)
		}
	}
	return nil
}

func loadCrop(ctx context.Context, q *store.Queries, id uuid.UUID) (Crop, error) {
	row, err := q.GetCrop(ctx, id)
	if err != nil {
		return Crop{}, notFound(err, "crop")
	}
	crops, err := withStages(ctx, q, []store.Crop{row}, true)
	if err != nil {
		return Crop{}, err
	}
	return crops[0], nil
}

// withStages attaches stages to crops with one query.
func withStages(ctx context.Context, q *store.Queries, rows []store.Crop, includeInactive bool) ([]Crop, error) {
	cropIDs := make([]uuid.UUID, len(rows))
	for i, r := range rows {
		cropIDs[i] = r.ID
	}
	stages, err := q.ListStagesForCrops(ctx, store.ListStagesForCropsParams{CropIds: cropIDs, IncludeInactive: includeInactive})
	if err != nil {
		return nil, apperr.Internalf("masters: list stages: %w", err)
	}
	byCrop := map[uuid.UUID][]Stage{}
	for _, st := range stages {
		byCrop[st.CropID] = append(byCrop[st.CropID], toStage(st))
	}
	out := make([]Crop, len(rows))
	for i, r := range rows {
		out[i] = Crop{
			ID: r.ID, Code: r.Code, Name: r.Name, NameTe: r.NameTe, DurationDays: r.DurationDays,
			Active: r.Active, CreatedAt: r.CreatedAt.UTC(), Stages: byCrop[r.ID],
		}
		if out[i].Stages == nil {
			out[i].Stages = []Stage{}
		}
	}
	return out, nil
}

func toStage(st store.CropStage) Stage {
	return Stage{
		ID: st.ID, CropID: st.CropID, Code: st.Code, Name: st.Name, NameTe: st.NameTe,
		Seq: st.Seq, StartDay: st.StartDay, EndDay: st.EndDay, Active: st.Active,
	}
}

// notFound maps "no rows" to 404 entity; anything else is internal.
func notFound(err error, entity string) error {
	if db.IsNoRows(err) {
		return apperr.NotFound(entity)
	}
	return apperr.Internalf("masters: load %s: %w", entity, err)
}

// recordPublished bumps the masters version and audits the change with the
// new version in meta, all in the caller's transaction.
func (s *Service) recordPublished(ctx context.Context, tx pgx.Tx, q *store.Queries, action, entityType string, id uuid.UUID, before, after any) error {
	v, err := s.publish(ctx, tx, q)
	if err != nil {
		return err
	}
	return record(ctx, tx, action, entityType, id, before, after, map[string]any{"masters_version": v})
}

// record writes one audit entry in the caller's transaction.
func record(ctx context.Context, tx pgx.Tx, action, entityType string, id uuid.UUID, before, after, meta any) error {
	if _, err := audit.Record(ctx, tx, audit.Entry{
		Action: action, EntityType: entityType, EntityID: id, Before: before, After: after, Meta: meta,
	}); err != nil {
		return apperr.Internalf("masters: audit %s: %w", action, err)
	}
	return nil
}
