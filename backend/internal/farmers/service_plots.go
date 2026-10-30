package farmers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"math"
	"regexp"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/db"
)

// maxAreaAcres bounds plot area (numeric(8,3) in the schema; no smallholder
// plot comes near it, so a bigger figure is a typo).
const maxAreaAcres = 10000

var seasonCodeRe = regexp.MustCompile(`^[a-z]+-[0-9]{4}(-[0-9]{2})?$`)

// plotGeometry is a validated plot location and area, ready to write.
type plotGeometry struct {
	boundary    *string // GeoJSON Polygon text; nil = no boundary
	pin         *Point
	areaAcres   float64
	areaSource  string
	gpsAccuracy *float64
}

// measurePlot validates a plot's boundary/pin/area. With a boundary, the area
// is computed server-side with PostGIS; the FA's figure is kept only when the
// area source is "typed" (GPS too rough, area told by the farmer).
//
// It runs outside any transaction: PostGIS raises an error on bad GeoJSON,
// which would abort a surrounding transaction.
func (s *Service) measurePlot(ctx context.Context, boundary json.RawMessage, pin *Point, area float64, source string, gps *float64) (plotGeometry, error) {
	g := plotGeometry{pin: pin, areaAcres: area, areaSource: source, gpsAccuracy: gps}
	if source != AreaBoundary && source != AreaTyped {
		return g, apperr.Validation("area_source", "must be boundary or typed")
	}
	text, err := geoJSONText(boundary)
	if err != nil {
		return g, err
	}
	if pin != nil && (pin.Lat < -90 || pin.Lat > 90 || pin.Lng < -180 || pin.Lng > 180) {
		return g, apperr.Validation("pin", "lat must be within ±90 and lng within ±180")
	}
	if text == "" && pin == nil {
		return g, apperr.Validation("pin", "a boundary or a pin is required")
	}
	if gps != nil && (*gps < 0 || *gps > 9999) {
		return g, apperr.Validation("gps_accuracy_m", "must be between 0 and 9999")
	}
	if text != "" {
		m, err := s.q.MeasureBoundary(ctx, text)
		if err != nil {
			if db.PgErrorCode(err) != "" {
				return g, apperr.Validation("boundary_geojson", "not a valid GeoJSON polygon")
			}
			return g, apperr.Internalf("farmers: measure boundary: %w", err)
		}
		if m.GeomType != "POLYGON" {
			return g, apperr.Validation("boundary_geojson", "must be a Polygon")
		}
		if !m.Valid {
			return g, apperr.Validation("boundary_geojson", "boundary crosses itself; walk it again")
		}
		g.boundary = &text
		if source == AreaBoundary {
			g.areaAcres = math.Round(m.AreaAcres*1000) / 1000
		}
	} else if source == AreaBoundary {
		return g, apperr.Validation("area_source", "boundary needs a boundary_geojson; use typed with a pin")
	}
	if g.areaAcres <= 0 || g.areaAcres > maxAreaAcres {
		return g, apperr.Validation("area_acres", "must be more than 0 and at most 10000")
	}
	return g, nil
}

// geoJSONText accepts a GeoJSON object or a JSON string holding one and
// returns the GeoJSON text ("" when absent).
func geoJSONText(raw json.RawMessage) (string, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || string(raw) == "null" {
		return "", nil
	}
	if raw[0] == '"' {
		var s string
		if err := json.Unmarshal(raw, &s); err != nil {
			return "", apperr.Validation("boundary_geojson", "not valid JSON")
		}
		s = strings.TrimSpace(s)
		if s != "" && !json.Valid([]byte(s)) {
			return "", apperr.Validation("boundary_geojson", "not valid JSON")
		}
		return s, nil
	}
	if raw[0] != '{' {
		return "", apperr.Validation("boundary_geojson", "must be a GeoJSON object")
	}
	return string(raw), nil
}

func (g plotGeometry) pinLatLng() (lat, lng *float64) {
	if g.pin == nil {
		return nil, nil
	}
	a, b := g.pin.Lat, g.pin.Lng
	return &a, &b
}

// loadPlot reads one plot (with geometry) by ID.
func loadPlot(ctx context.Context, q *store.Queries, id uuid.UUID) (store.ListPlotsRow, error) {
	rows, err := q.ListPlots(ctx, store.ListPlotsParams{PlotIds: []uuid.UUID{id}, FarmerIds: []uuid.UUID{}})
	if err != nil {
		return store.ListPlotsRow{}, apperr.Internalf("farmers: load plot: %w", err)
	}
	if len(rows) == 0 {
		return store.ListPlotsRow{}, apperr.NotFound("plot")
	}
	return rows[0], nil
}

// startSeason inserts an active season on a plot the caller has already
// checked belongs to the farmer. A plot has at most one active season.
func startSeason(ctx context.Context, q *store.Queries, arg store.InsertSeasonParams) (store.CropSeason, error) {
	if !seasonCodeRe.MatchString(arg.SeasonCode) {
		return store.CropSeason{}, apperr.Validation("season_code", "must look like rabi-2026-27 or kharif-2027")
	}
	if active, err := q.ActiveSeasonForPlot(ctx, arg.PlotID); err == nil {
		return store.CropSeason{}, apperr.Conflict("active_season_exists", map[string]any{"season_id": active.ID})
	} else if !db.IsNoRows(err) {
		return store.CropSeason{}, apperr.Internalf("farmers: active season: %w", err)
	}
	se, err := q.InsertSeason(ctx, arg)
	switch {
	case err == nil:
		return se, nil
	case db.IsForeignKeyViolation(err):
		return store.CropSeason{}, seasonFKError(err)
	case db.IsUniqueViolation(err, "crop_seasons_one_active"):
		return store.CropSeason{}, apperr.Conflict("active_season_exists", nil)
	case db.IsUniqueViolation(err, ""):
		return store.CropSeason{}, apperr.Conflict("season_exists", nil)
	default:
		return store.CropSeason{}, apperr.Internalf("farmers: insert season: %w", err)
	}
}

// seasonFKError names the field behind a crop_seasons foreign-key violation.
func seasonFKError(err error) error {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch {
		case strings.Contains(pgErr.ConstraintName, "previous_crop_id"):
			return apperr.Validation("previous_crop_id", "unknown crop")
		case strings.Contains(pgErr.ConstraintName, "crop_id"):
			return apperr.Validation("crop_id", "unknown crop")
		case strings.Contains(pgErr.ConstraintName, "plot_id"):
			return apperr.Validation("plot_id", "plot does not belong to this farmer")
		}
	}
	return apperr.Validation("season", "refers to a record that does not exist")
}
