package farmers

import (
	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
)

// Audit snapshots. Phones are masked: the audit log is read widely and the
// number itself is on the farmer record.

func farmerAuditView(f store.Farmer) map[string]any {
	return map[string]any{
		"phone":          phone.Mask(f.Phone),
		"name":           f.Name,
		"name_te":        f.NameTe,
		"language":       f.Language,
		"village_id":     uuidPtr(f.VillageID),
		"assigned_fa_id": uuidPtr(f.AssignedFaID),
		"plan":           f.Plan,
		"status":         f.Status,
		"version":        f.Version,
	}
}

func plotAuditView(p store.ListPlotsRow) map[string]any {
	pl := toPlot(p)
	return map[string]any{
		"label":          pl.Label,
		"area_acres":     pl.AreaAcres,
		"area_source":    pl.AreaSource,
		"has_boundary":   pl.Boundary != nil,
		"pin":            pl.Pin,
		"gps_accuracy_m": pl.GPSAccuracyM,
		"version":        pl.Version,
	}
}

func seasonAuditView(s store.CropSeason) map[string]any {
	return map[string]any{
		"season_code":      s.SeasonCode,
		"crop_id":          s.CropID,
		"sowing_date":      s.SowingDate,
		"previous_crop_id": uuidPtr(s.PreviousCropID),
		"status":           s.Status,
	}
}
