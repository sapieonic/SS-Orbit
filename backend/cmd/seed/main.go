// Command seed loads dev data: Rangareddy district (mandals, villages), HO
// users, FAs with allocations, masters (crops, stages, issues, salts, SKUs,
// rules, a dealer) and sample farmers with plots, seasons and a planned visit.
//
// It writes SQL directly with fixed IDs (UUIDv5 from a readable name) and
// ON CONFLICT DO NOTHING, so running it twice is safe. Dev only: it refuses to
// run when ORBIT_ENV is prod.
//
//	go run ./cmd/seed
package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Dev-only passwords, printed at the end so whoever runs the seed can log in.
const (
	hoPassword = "orbit-dev-pass"
	faPassword = "fa-dev-pass"
)

var seedNS = uuid.MustParse("5b0f1a52-6f0e-4c1d-9a51-0b17c0de5eed")

// sid returns a stable ID for a seed row, e.g. sid("village:kondapur").
func sid(name string) uuid.UUID { return uuid.NewSHA1(seedNS, []byte(name)) }

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "seed:", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	if cfg.Env == config.EnvProd {
		return fmt.Errorf("refusing to seed a prod database")
	}
	ctx := context.Background()
	pool, err := db.Open(ctx, cfg.DatabaseURL, 2)
	if err != nil {
		return err
	}
	defer pool.Close()

	hoHash, err := auth.HashPassword(hoPassword)
	if err != nil {
		return err
	}
	faHash, err := auth.HashPassword(faPassword)
	if err != nil {
		return err
	}

	err = db.WithTx(ctx, pool, func(tx pgx.Tx) error {
		steps := []func(context.Context, pgx.Tx) error{
			seedGeo,
			func(ctx context.Context, tx pgx.Tx) error { return seedPeople(ctx, tx, hoHash, faHash) },
			seedMasters,
			seedFarmers,
		}
		for _, step := range steps {
			if err := step(ctx, tx); err != nil {
				return err
			}
		}
		return territory.Bump(ctx, tx, sid("fa:suresh"), sid("fa:lakshmi"))
	})
	if err != nil {
		return err
	}

	fmt.Println("seed: done")
	fmt.Printf("  HO logins (password %q, no TOTP yet): admin@orbit.dev, agronomy@orbit.dev, agronomy2@orbit.dev, finance@orbit.dev, ops@orbit.dev\n", hoPassword)
	fmt.Printf("  FA logins (password %q): FA-KDP-014 (Suresh K, Kondapur + Gachibowli), FA-CVL-002 (Lakshmi P, Chevella mandal)\n", faPassword)
	fmt.Println("  Farmers (OTP sign-in, DEV_FIXED_OTP): +919000000101 Ravi K, +919000000102 Venkatesh M")
	return nil
}

// exec runs each statement with its args and stops at the first error.
func exec(ctx context.Context, tx pgx.Tx, stmts ...stmt) error {
	for _, s := range stmts {
		if _, err := tx.Exec(ctx, s.sql, s.args...); err != nil {
			return fmt.Errorf("%s: %w", s.what, err)
		}
	}
	return nil
}

type stmt struct {
	what string
	sql  string
	args []any
}

func seedGeo(ctx context.Context, tx pgx.Tx) error {
	const district = `INSERT INTO districts (id, name, name_te) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`
	const mandal = `INSERT INTO mandals (id, district_id, name, name_te) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`
	const village = `INSERT INTO villages (id, mandal_id, name, name_te, centroid)
		VALUES ($1, $2, $3, $4, ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography) ON CONFLICT DO NOTHING`

	rr, sl, cv := sid("district:rangareddy"), sid("mandal:serilingampally"), sid("mandal:chevella")
	return exec(ctx, tx,
		stmt{"district", district, []any{rr, "Rangareddy", "రంగారెడ్డి"}},
		stmt{"mandal", mandal, []any{sl, rr, "Serilingampally", "శేరిలింగంపల్లి"}},
		stmt{"mandal", mandal, []any{cv, rr, "Chevella", "చేవెళ్ల"}},
		stmt{"village", village, []any{sid("village:kondapur"), sl, "Kondapur", "కొండాపూర్", 78.3570, 17.4600}},
		stmt{"village", village, []any{sid("village:gachibowli"), sl, "Gachibowli", "గచ్చిబౌలి", 78.3489, 17.4401}},
		stmt{"village", village, []any{sid("village:madhapur"), sl, "Madhapur", "మాదాపూర్", 78.3915, 17.4483}},
		stmt{"village", village, []any{sid("village:chevella"), cv, "Chevella", "చేవెళ్ల", 78.1353, 17.3067}},
		stmt{"village", village, []any{sid("village:mudimyal"), cv, "Mudimyal", "ముడిమ్యాల్", 78.1000, 17.3300}},
	)
}

func seedPeople(ctx context.Context, tx pgx.Tx, hoHash, faHash string) error {
	const ho = `INSERT INTO ho_users (id, email, name, password_hash, role) VALUES ($1, $2, $3, $4, $5) ON CONFLICT DO NOTHING`
	const fa = `INSERT INTO field_assistants (id, code, name, name_te, phone, password_hash, must_change_password,
		level, languages, working_hours, created_by)
		VALUES ($1, $2, $3, $4, $5, $6, false, $7, $8, $9, $10) ON CONFLICT DO NOTHING`
	const villageAlloc = `INSERT INTO fa_allocations (id, fa_id, level, village_id, created_by)
		VALUES ($1, $2, 'village', $3, $4) ON CONFLICT DO NOTHING`
	const mandalAlloc = `INSERT INTO fa_allocations (id, fa_id, level, mandal_id, created_by)
		VALUES ($1, $2, 'mandal', $3, $4) ON CONFLICT DO NOTHING`

	admin := sid("ho:admin")
	suresh, lakshmi := sid("fa:suresh"), sid("fa:lakshmi")
	return exec(ctx, tx,
		stmt{"ho admin", ho, []any{admin, "admin@orbit.dev", "HO Admin", hoHash, "admin"}},
		stmt{"ho agronomy", ho, []any{sid("ho:agronomy"), "agronomy@orbit.dev", "Agronomy Lead", hoHash, "agronomy"}},
		// A second agronomy user so maker-checker (never approve your own) can be tested.
		stmt{"ho agronomy 2", ho, []any{sid("ho:agronomy2"), "agronomy2@orbit.dev", "Agronomy Reviewer", hoHash, "agronomy"}},
		stmt{"ho finance", ho, []any{sid("ho:finance"), "finance@orbit.dev", "Finance Desk", hoHash, "finance"}},
		stmt{"ho ops", ho, []any{sid("ho:ops"), "ops@orbit.dev", "Field Ops", hoHash, "ops"}},
		stmt{"fa suresh", fa, []any{suresh, "FA-KDP-014", "Suresh K", "సురేష్ కె", "+919000000014", faHash,
			"village", []string{"te", "en"}, "Mon-Sat 8am-5pm", admin}},
		stmt{"fa lakshmi", fa, []any{lakshmi, "FA-CVL-002", "Lakshmi P", "లక్ష్మి పి", "+919000000002", faHash,
			"mandal", []string{"te"}, "Mon-Sat 7am-4pm", admin}},
		stmt{"alloc", villageAlloc, []any{sid("alloc:suresh:kondapur"), suresh, sid("village:kondapur"), admin}},
		stmt{"alloc", villageAlloc, []any{sid("alloc:suresh:gachibowli"), suresh, sid("village:gachibowli"), admin}},
		stmt{"alloc", mandalAlloc, []any{sid("alloc:lakshmi:chevella"), lakshmi, sid("mandal:chevella"), admin}},
	)
}

type stage struct {
	code, name, nameTe string
	start, end         int
}

func seedMasters(ctx context.Context, tx pgx.Tx) error {
	const crop = `INSERT INTO crops (id, code, name, name_te, duration_days) VALUES ($1, $2, $3, $4, $5) ON CONFLICT DO NOTHING`
	const cropStage = `INSERT INTO crop_stages (id, crop_id, code, name, name_te, seq, start_day, end_day)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8) ON CONFLICT DO NOTHING`
	crops := []struct {
		code, name, nameTe string
		days               int
		stages             []stage
	}{
		{"cotton", "Cotton", "పత్తి", 160, []stage{
			{"seedling", "Seedling", "మొలక దశ", 0, 20},
			{"square", "Square formation", "మొగ్గ దశ", 21, 50},
			{"flowering", "Flowering", "పూత దశ", 51, 80},
			{"boll", "Boll development", "కాయ దశ", 81, 120},
			{"picking", "Picking", "తీత దశ", 121, 160},
		}},
		{"paddy", "Paddy", "వరి", 120, []stage{
			{"nursery", "Nursery", "నారుమడి", 0, 25},
			{"tillering", "Tillering", "పిలకల దశ", 26, 55},
			{"panicle", "Panicle initiation", "పొట్ట దశ", 56, 85},
			{"maturity", "Grain filling and maturity", "గింజ దశ", 86, 120},
		}},
		{"chilli", "Chilli", "మిరప", 150, []stage{
			{"seedling", "Seedling", "మొలక దశ", 0, 30},
			{"vegetative", "Vegetative", "ఎదుగుదల దశ", 31, 60},
			{"flowering", "Flowering", "పూత దశ", 61, 90},
			{"fruiting", "Fruiting and picking", "కాయ దశ", 91, 150},
		}},
	}
	var stmts []stmt
	for _, c := range crops {
		cropID := sid("crop:" + c.code)
		stmts = append(stmts, stmt{"crop " + c.code, crop, []any{cropID, c.code, c.name, c.nameTe, c.days}})
		for i, s := range c.stages {
			stmts = append(stmts, stmt{"stage " + c.code + "/" + s.code, cropStage,
				[]any{sid("stage:" + c.code + ":" + s.code), cropID, s.code, s.name, s.nameTe, i + 1, s.start, s.end}})
		}
	}

	const salt = `INSERT INTO salts (id, name, name_te) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`
	const sku = `INSERT INTO skus (id, code, product_name, product_name_te, salt_id, pack_size, mrp_paise)
		VALUES ($1, $2, $3, $4, $5, $6, $7) ON CONFLICT DO NOTHING`
	const issue = `INSERT INTO issues (id, crop_id, type, name, name_te) VALUES ($1, $2, $3, $4, $5) ON CONFLICT DO NOTHING`
	const rule = `INSERT INTO advisory_rules (id, rule_key, version, issue_id, salt_id, sku_id, dose_per_acre,
		dose_per_acre_te, status, change_note, created_by, approved_by, approved_at)
		VALUES ($1, $2, 1, $3, $4, $5, $6, $7, 'approved', 'Seed data', $8, $9, now()) ON CONFLICT DO NOTHING`
	const dealer = `INSERT INTO dealers (id, name, name_te, phone, village_id, location, status)
		VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography, 'active') ON CONFLICT DO NOTHING`
	const dealerSKU = `INSERT INTO dealer_skus (dealer_id, sku_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`

	ema, imi, tri := sid("salt:emamectin"), sid("salt:imidacloprid"), sid("salt:tricyclazole")
	skuEB, skuIM := sid("sku:SH-EB-250"), sid("sku:SH-IM-100")
	pbw, wf, blast := sid("issue:cotton:pink-bollworm"), sid("issue:cotton:whitefly"), sid("issue:paddy:blast")
	author, approver := sid("ho:admin"), sid("ho:agronomy")
	dealerID := sid("dealer:sri-sai")
	var nullSKU *uuid.UUID

	stmts = append(stmts,
		stmt{"salt", salt, []any{ema, "Emamectin benzoate 5% SG", "ఎమామెక్టిన్ బెంజోయేట్ 5% SG"}},
		stmt{"salt", salt, []any{imi, "Imidacloprid 17.8% SL", "ఇమిడాక్లోప్రిడ్ 17.8% SL"}},
		stmt{"salt", salt, []any{tri, "Tricyclazole 75% WP", "ట్రైసైక్లాజోల్ 75% WP"}},
		stmt{"sku", sku, []any{skuEB, "SH-EB-250", "Sample 5 SG", "శాంపిల్ 5 SG", ema, "250 g", 45000}},
		stmt{"sku", sku, []any{skuIM, "SH-IM-100", "Sample Guard 17.8", "శాంపిల్ గార్డ్ 17.8", imi, "100 ml", 32000}},
		stmt{"issue", issue, []any{pbw, sid("crop:cotton"), "pest", "Pink bollworm", "గులాబీ రంగు పురుగు"}},
		stmt{"issue", issue, []any{wf, sid("crop:cotton"), "pest", "Whitefly", "తెల్ల దోమ"}},
		stmt{"issue", issue, []any{blast, sid("crop:paddy"), "disease", "Blast", "అగ్గి తెగులు"}},
		stmt{"rule", rule, []any{sid("rule:pbw:v1"), sid("rulekey:pbw"), pbw, ema, skuEB,
			"80 g in 200 L water per acre", "ఎకరానికి 200 లీ. నీటిలో 80 గ్రా.", author, approver}},
		stmt{"rule", rule, []any{sid("rule:wf:v1"), sid("rulekey:wf"), wf, imi, skuIM,
			"50 ml in 200 L water per acre", "ఎకరానికి 200 లీ. నీటిలో 50 మి.లీ.", author, approver}},
		stmt{"rule", rule, []any{sid("rule:blast:v1"), sid("rulekey:blast"), blast, tri, nullSKU,
			"120 g in 200 L water per acre", "ఎకరానికి 200 లీ. నీటిలో 120 గ్రా.", author, approver}},
		stmt{"dealer", dealer, []any{dealerID, "Sri Sai Agro Traders", "శ్రీ సాయి ఆగ్రో ట్రేడర్స్", "+919000000501",
			sid("village:kondapur"), 78.3591, 17.4621}},
		stmt{"dealer sku", dealerSKU, []any{dealerID, skuEB}},
		stmt{"dealer sku", dealerSKU, []any{dealerID, skuIM}},
		stmt{"masters version", `UPDATE master_versions SET version = version + 1, updated_at = now() WHERE kind = 'all'`, nil},
	)
	return exec(ctx, tx, stmts...)
}

func seedFarmers(ctx context.Context, tx pgx.Tx) error {
	const farmer = `INSERT INTO farmers (id, phone, name, name_te, village_id, assigned_fa_id, source,
		enrolled_by_fa_id, status, profile_completed_at)
		VALUES ($1, $2, $3, $4, $5, $6, 'fa', $6, 'active', now()) ON CONFLICT DO NOTHING`
	// consents is append-only, so guard with NOT EXISTS rather than ON CONFLICT.
	const consent = `INSERT INTO consents (id, farmer_id, purpose, granted, method, captured_by_fa_id, notice_version, language)
		SELECT $1, $2, 'programme', true, 'fa_otp', $3, 'v1', 'te'
		WHERE NOT EXISTS (SELECT 1 FROM consents WHERE id = $1)`
	const plot = `INSERT INTO plots (id, farmer_id, label, village_id, pin, area_acres, area_source, created_by_fa_id)
		VALUES ($1, $2, $3, $4, ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography, $7, 'typed', $8) ON CONFLICT DO NOTHING`
	const season = `INSERT INTO crop_seasons (id, farmer_id, plot_id, season_code, crop_id, sowing_date)
		VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT DO NOTHING`
	const visit = `INSERT INTO visits (id, farmer_id, plot_id, season_id, fa_id, status, planned_for, planned_slot, purpose, district_id)
		VALUES ($1, $2, $3, $4, $5, 'planned', $6, 'morning', $7, $8) ON CONFLICT DO NOTHING`

	suresh := sid("fa:suresh")
	ravi, venk := sid("farmer:ravi"), sid("farmer:venkatesh")
	raviPlot, venkPlot := sid("plot:ravi:1"), sid("plot:venkatesh:1")
	raviSeason, venkSeason := sid("season:ravi:1:kharif-2026"), sid("season:venkatesh:1:rabi-2026-27")
	tomorrow := time.Now().UTC().Truncate(24*time.Hour).AddDate(0, 0, 1)

	return exec(ctx, tx,
		stmt{"farmer ravi", farmer, []any{ravi, "+919000000101", "Ravi K", "రవి కె", sid("village:kondapur"), suresh}},
		stmt{"farmer venkatesh", farmer, []any{venk, "+919000000102", "Venkatesh M", "వెంకటేష్ ఎం", sid("village:gachibowli"), suresh}},
		stmt{"consent", consent, []any{sid("consent:ravi:programme"), ravi, suresh}},
		stmt{"consent", consent, []any{sid("consent:venkatesh:programme"), venk, suresh}},
		stmt{"plot", plot, []any{raviPlot, ravi, "Plot 1", sid("village:kondapur"), 78.3555, 17.4612, 2.5, suresh}},
		stmt{"plot", plot, []any{venkPlot, venk, "Plot 1", sid("village:gachibowli"), 78.3470, 17.4390, 1.75, suresh}},
		stmt{"season", season, []any{raviSeason, ravi, raviPlot, "kharif-2026", sid("crop:cotton"),
			time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC)}},
		stmt{"season", season, []any{venkSeason, venk, venkPlot, "rabi-2026-27", sid("crop:paddy"),
			time.Date(2026, 10, 10, 0, 0, 0, 0, time.UTC)}},
		stmt{"visit", visit, []any{sid("visit:ravi:planned-1"), ravi, raviPlot, raviSeason, suresh, tomorrow,
			"Check bollworm traps", sid("district:rangareddy")}},
		// farmers keeps a copy of the village's mandal and district for area filters.
		stmt{"farmer area", `UPDATE farmers f SET mandal_id = v.mandal_id, district_id = m.district_id
			FROM villages v JOIN mandals m ON m.id = v.mandal_id
			WHERE f.village_id = v.id AND f.id = ANY($1) AND f.mandal_id IS NULL`, []any{[]uuid.UUID{ravi, venk}}},
	)
}
