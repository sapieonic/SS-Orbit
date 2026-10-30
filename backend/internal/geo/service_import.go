package geo

import (
	"context"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"regexp"
	"slices"
	"strconv"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/geo/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
)

// Import limits.
const (
	importMaxRows   = 10000
	importMaxErrors = 50
)

var (
	importColumns  = []string{"district", "mandal", "village", "name_te", "lgd_code", "lat", "lng"}
	importRequired = []string{"district", "mandal", "village"}
	lgdPattern     = regexp.MustCompile(`^[0-9]{1,10}$`)
)

// importRow is one parsed CSV data row. line is its line in the file.
type importRow struct {
	line                      int
	district, mandal, village string
	nameTe, lgdCode           *string
	lat, lng                  *float64
}

// rowErrors collects per-row problems as validation fields "row N".
type rowErrors map[string]string

func (e rowErrors) add(line int, msg string) {
	if len(e) < importMaxErrors {
		e[fmt.Sprintf("row %d", line)] = msg
	}
}

func (e rowErrors) err() error {
	if len(e) == 0 {
		return nil
	}
	return apperr.ValidationFields(e).WithMessage("the file has invalid rows; nothing was imported")
}

// ImportVillages imports villages from CSV, all or nothing (see the spec for
// the format). Existing villages (same mandal, name ignoring case) take the
// row's non-empty values. FAs covering touched mandals are bumped.
func (s *Service) ImportVillages(ctx context.Context, r io.Reader, createMissing bool) (ImportResult, error) {
	p, err := requireWrite(ctx)
	if err != nil {
		return ImportResult{}, err
	}
	rows, err := parseVillageCSV(r)
	if err != nil {
		return ImportResult{}, err
	}
	res := ImportResult{Rows: len(rows)}
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		res = ImportResult{Rows: len(rows)}
		imp := &importer{s: s, q: s.q.WithTx(tx), p: p, createMissing: createMissing, res: &res,
			districts: map[string]uuid.UUID{}, mandals: map[string]uuid.UUID{}, touched: map[uuid.UUID]bool{}}
		errs := rowErrors{}
		for _, row := range rows {
			if err := imp.apply(ctx, row); err != nil {
				var rowErr *importRowError
				if errors.As(err, &rowErr) {
					errs.add(row.line, rowErr.msg)
					continue
				}
				return err
			}
		}
		if err := errs.err(); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{Action: "geo.villages_imported", EntityType: "village_import",
			Meta: map[string]any{"rows": res.Rows, "created": res.Created, "updated": res.Updated, "unchanged": res.Unchanged,
				"districts_created": res.DistrictsCreated, "mandals_created": res.MandalsCreated}}); err != nil {
			return err
		}
		touched := make([]uuid.UUID, 0, len(imp.touched))
		for id := range imp.touched {
			touched = append(touched, id)
		}
		return s.bumpMandals(ctx, tx, imp.q, touched...)
	})
	if err != nil {
		return ImportResult{}, err
	}
	s.invalidateTree(ctx)
	return res, nil
}

// importRowError is a problem with one row (collected, not fatal).
type importRowError struct{ msg string }

func (e *importRowError) Error() string { return e.msg }

func rowErr(format string, args ...any) error {
	return &importRowError{msg: fmt.Sprintf(format, args...)}
}

// importer resolves districts and mandals by name (memoised) and upserts
// villages inside one transaction.
type importer struct {
	s             *Service
	q             *store.Queries
	p             auth.Principal
	createMissing bool
	res           *ImportResult
	districts     map[string]uuid.UUID // lower(name) -> id
	mandals       map[string]uuid.UUID // district id + "/" + lower(name) -> id
	touched       map[uuid.UUID]bool   // mandals whose villages changed
}

func (imp *importer) apply(ctx context.Context, row importRow) error {
	districtID, err := imp.district(ctx, row.district)
	if err != nil {
		return err
	}
	mandalID, err := imp.mandal(ctx, districtID, row.mandal)
	if err != nil {
		return err
	}
	name := row.village
	existing, err := imp.q.FindVillageName(ctx, store.FindVillageNameParams{MandalID: mandalID, Name: name})
	switch {
	case err == nil:
		name = existing
	case !db.IsNoRows(err):
		return err
	}
	id := ids.New()
	got, err := imp.q.UpsertVillage(ctx, store.UpsertVillageParams{
		ID: id, MandalID: mandalID, LgdCode: row.lgdCode, Name: name, NameTe: row.nameTe, Lat: row.lat, Lng: row.lng,
	})
	switch {
	case db.IsNoRows(err):
		imp.res.Unchanged++
		return nil
	case db.IsUniqueViolation(err, "villages_lgd_code_key"):
		// The transaction is aborted now, so this ends the import.
		return apperr.Conflict("lgd_code_taken", map[string]any{"row": row.line, "lgd_code": *row.lgdCode}).
			WithMessage(fmt.Sprintf("row %d: lgd_code %s already belongs to another village", row.line, *row.lgdCode))
	case err != nil:
		return err
	case got == id:
		imp.res.Created++
	default:
		imp.res.Updated++
	}
	imp.touched[mandalID] = true
	return nil
}

func (imp *importer) district(ctx context.Context, name string) (uuid.UUID, error) {
	key := strings.ToLower(name)
	id, ok := imp.districts[key]
	if !ok {
		d, err := imp.q.FindDistrictByName(ctx, name)
		switch {
		case err == nil:
			id = d.ID
		case !db.IsNoRows(err):
			return uuid.Nil, err
		case !imp.createMissing:
			return uuid.Nil, rowErr("unknown district %q", name)
		case imp.p.HasAreaScope():
			return uuid.Nil, rowErr("unknown district %q (only HO users without an area scope can add districts)", name)
		default:
			d, err = imp.q.InsertDistrict(ctx, store.InsertDistrictParams{ID: ids.New(), Name: name})
			if err != nil {
				return uuid.Nil, err
			}
			id = d.ID
			imp.res.DistrictsCreated++
		}
		imp.districts[key] = id
	}
	if !imp.p.CanSeeDistrict(id) {
		return uuid.Nil, rowErr("district %q is outside your area", name)
	}
	return id, nil
}

func (imp *importer) mandal(ctx context.Context, districtID uuid.UUID, name string) (uuid.UUID, error) {
	key := districtID.String() + "/" + strings.ToLower(name)
	if id, ok := imp.mandals[key]; ok {
		return id, nil
	}
	m, err := imp.q.FindMandalByName(ctx, store.FindMandalByNameParams{DistrictID: districtID, Name: name})
	switch {
	case err == nil:
	case !db.IsNoRows(err):
		return uuid.Nil, err
	case !imp.createMissing:
		return uuid.Nil, rowErr("unknown mandal %q in this district", name)
	default:
		m, err = imp.q.InsertMandal(ctx, store.InsertMandalParams{ID: ids.New(), DistrictID: districtID, Name: name})
		if err != nil {
			return uuid.Nil, err
		}
		imp.res.MandalsCreated++
	}
	imp.mandals[key] = m.ID
	return m.ID, nil
}

// parseVillageCSV reads and validates the whole file. Row problems are
// returned together as one validation error.
func parseVillageCSV(r io.Reader) ([]importRow, error) {
	cr := csv.NewReader(r)
	cr.TrimLeadingSpace = true
	cr.FieldsPerRecord = -1
	header, err := cr.Read()
	if errors.Is(err, io.EOF) {
		return nil, apperr.Validation("body", "the file is empty")
	}
	if err != nil {
		return nil, apperr.Validation("body", "not valid CSV: "+err.Error())
	}
	cols := map[string]int{}
	for i, h := range header {
		h = strings.ToLower(strings.TrimSpace(strings.TrimPrefix(h, "\uFEFF")))
		if !slices.Contains(importColumns, h) {
			return nil, apperr.Validation("header", fmt.Sprintf("unknown column %q (allowed: %s)", h, strings.Join(importColumns, ", ")))
		}
		if _, dup := cols[h]; dup {
			return nil, apperr.Validation("header", fmt.Sprintf("column %q appears twice", h))
		}
		cols[h] = i
	}
	for _, c := range importRequired {
		if _, ok := cols[c]; !ok {
			return nil, apperr.Validation("header", fmt.Sprintf("missing column %q", c))
		}
	}

	var rows []importRow
	errs := rowErrors{}
	seen := map[string]int{}    // district/mandal/village (lower) -> line
	seenLGD := map[string]int{} // lgd code -> line
	for {
		rec, err := cr.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, apperr.Validation("body", "not valid CSV: "+err.Error())
		}
		line, _ := cr.FieldPos(0)
		if blankRecord(rec) {
			continue
		}
		if len(rows) == importMaxRows {
			return nil, apperr.Validation("body", fmt.Sprintf("at most %d rows per file", importMaxRows))
		}
		get := func(col string) string {
			i, ok := cols[col]
			if !ok || i >= len(rec) {
				return ""
			}
			return strings.Join(strings.Fields(rec[i]), " ")
		}
		row := importRow{line: line, district: get("district"), mandal: get("mandal"), village: get("village")}
		if msg := row.fill(get); msg != "" {
			errs.add(line, msg)
			continue
		}
		key := strings.ToLower(row.district + "/" + row.mandal + "/" + row.village)
		if prev, dup := seen[key]; dup {
			errs.add(line, fmt.Sprintf("same village as row %d", prev))
			continue
		}
		seen[key] = line
		if row.lgdCode != nil {
			if prev, dup := seenLGD[*row.lgdCode]; dup {
				errs.add(line, fmt.Sprintf("lgd_code also used on row %d", prev))
				continue
			}
			seenLGD[*row.lgdCode] = line
		}
		rows = append(rows, row)
	}
	if err := errs.err(); err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return nil, apperr.Validation("body", "the file has no data rows")
	}
	return rows, nil
}

// fill validates the row's fields and sets the optional ones. It returns a
// message for the first problem, or "".
func (row *importRow) fill(get func(string) string) string {
	for _, c := range importRequired {
		if get(c) == "" {
			return c + " is required"
		}
	}
	if len(row.district) > 100 || len(row.mandal) > 100 || len(row.village) > 100 {
		return "names must be at most 100 characters"
	}
	if v := get("name_te"); v != "" {
		row.nameTe = &v
	}
	if v := get("lgd_code"); v != "" {
		if !lgdPattern.MatchString(v) {
			return "lgd_code must be 1 to 10 digits"
		}
		row.lgdCode = &v
	}
	lat, lng := get("lat"), get("lng")
	if (lat == "") != (lng == "") {
		return "lat and lng must be given together"
	}
	if lat != "" {
		la, err1 := strconv.ParseFloat(lat, 64)
		ln, err2 := strconv.ParseFloat(lng, 64)
		if err1 != nil || err2 != nil || la < -90 || la > 90 || ln < -180 || ln > 180 {
			return "lat/lng must be decimal degrees (lat -90..90, lng -180..180)"
		}
		row.lat, row.lng = &la, &ln
	}
	return ""
}

func blankRecord(rec []string) bool {
	for _, f := range rec {
		if strings.TrimSpace(f) != "" {
			return false
		}
	}
	return true
}
