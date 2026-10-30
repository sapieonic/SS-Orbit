# Backend implementation plan

## Purpose

The Go API and worker behind all three Orbit Shifting clients: the farmer app, the offline FA app and the HO
portal. This file says what is already built, how to run and change it, and what is left to build, in order,
phase by phase. Open it at the start of any backend task.

## Read first

1. `backend/docs/CONVENTIONS.md`: the contract every module follows. Sections are referenced below by number.
2. `backend/README.md`: quick start, Makefile targets, "Adding an endpoint", "Adding a migration", configuration.
3. `contracts/ENDPOINTS.md`: all 138 operations by surface. The specs in `contracts/openapi/*.yaml` are the truth.
4. `internal/audit/`: the reference module. Copy its shape for anything new.
5. `internal/app/wire.go` (ports wiring) and `internal/app/app.go` (deps, worker, periodic jobs).
6. `internal/xmod/types.go`: value types passed between modules.
7. The build plan (stack, sync design, roadmap): https://claude.ai/artifact/M85KFgHynuZ4gWBqz87pSa

## Current state

Built and green: all 8 modules, 138 operations, 22 migration files (`00001`-`00021` and `00026`; `00022`-`00025`
were reserved and never used), dev seed data (`make seed`), CI (`.github/workflows/backend.yml` runs `make check`
against Postgres+PostGIS and Redis). `tools/smoke_test.py` (end to end: OTP sign-in, FA login, snapshot + ETag,
sync batch, inbox, call-back, HO login with TOTP, advisory preview, device revoke; usage in its docstring)
passes twice in a row against a running API and worker.

Also built: one container image (`Dockerfile`, `make image`; distroless, binaries `api` (default), `worker`,
`migrate`, `seed`; image default `ORBIT_ENV=prod`, pass `ORBIT_ENV=dev` for a local `docker run`); `cmd/migrate`
needs only `DATABASE_URL` (`config.LoadDatabase()`); worker `/healthz` and `/readyz` (DB ping) on
`WORKER_HEALTH_ADDR` (`:8081`); empty `REDIS_URL` runs without Redis; forced update via
`GET /v1/auth/app-config` and the heartbeats; every SMS wording with its own placeholder DLT ID per language in
`internal/platform/sms/templates.go`; `make specs` regenerates `contracts/ENDPOINTS.md` and the client bundles
`contracts/build/mobile.yaml` and `web.yaml` (`tools/bundle-specs.py`).

Not built: real partner adapters (only `log` SMS/push and `local` storage exist, and `ORBIT_ENV=prod` refuses
them, so prod cannot start yet; that is deliberate), no Sentry, no golangci-lint config, real DLT IDs.

### Modules

| Module | Owns (tables) | What it does | Endpoints | Background work |
|---|---|---|---|---|
| `identity` | `ho_users`, `field_assistants`, `devices`, `sessions`, `otp_challenges` | Farmer OTP sign-in (SMS Retriever format when `OTP_SMS_APP_HASH` is set), FA login (temp password, 72 h expiry, `password_change_required`), HO login + TOTP enrolment, refresh rotation, devices and remote wipe, app config and forced update (`GET /v1/auth/app-config`, `min_version`/`update_required` on heartbeats), consent OTP (`otp_proof`), FA and HO user admin, HO user directory, the surface guard's `CheckPrincipal` | 34 | `identity.maintenance` hourly: seal TOTP secrets, purge rate-limit counters |
| `geo` | `districts`, `mandals`, `villages`, `fa_allocations` | District/mandal/village masters, village CSV import, FA allocations at village/mandal/district level, allocation hand-over, village picker trees | 18 | none |
| `farmers` | `farmers`, `consents`, `plots`, `crop_seasons`, `farmer_aliases`, `farmer_enrolments` | Farmer profile and photo, consent records (also while `pending_profile`), plots (PostGIS), seasons and open season codes, stage computation, merge aliases, "Look for FAs", phone lookup for FAs, reassignment (by village with `from_fa_id`, or by farmer), season rollover, Farmer 360, territory resolver | 20 | sync commands `EnrolFarmer`, `RecordConsent`, `SavePlot`, `StartSeason`, `UpdateFarmer` |
| `masters` | `crops`, `crop_stages`, `salts`, `skus`, `issues`, `advisory_rules`, `dealers`, `dealer_skus`, `master_versions` | Crops and stage calendars, issues, salts, Shanmukha SKUs, advice rules with maker-checker (Agronomy approves, never their own), dealers and "nearest dealer" | 28 | subscriber `masters.cache_invalidation` |
| `visits` | `visits`, `visit_issues`, `visit_photos`, `callback_requests` | Planned and logged visits, salt-then-product advice snapshot on the visit, photo upload URLs, farmer call-backs, admin visit search (with farmer and village names), overdue list, QA sample, counts per FA or per day | 12 | sync commands `PlanVisit`, `LogVisit`, `CancelVisit`, `CloseCallback`; `visits.mark_missed` hourly; subscriber on `farmers.reassigned` |
| `messaging` | `advisories`, `notices`, `deliveries`, `fa_alerts`, `ho_alerts` | Advisories (targeting, preview, draft edit, Agronomy approval when a product is named; neither author nor last editor approves), farmer inbox, web notice pages, FA alerts (English + Telugu) and HO notes, HO alerts, SMS/push delivery with quiet hours, SMS delivery webhook (stub) | 20 | `messaging.advisory_fanout`, `messaging.delivery`, `messaging.fa_alert_push`, `messaging.fa_offline` (hourly); 6 event subscribers |
| `sync` | `sync_commands`, `sync_command_failures` | FA snapshot (gzip, ETag `"t{territory}-m{masters}"`, 304), command batches (<= 200, idempotent by ID, `retry_from`), dead-letter after repeated infra failures, HO review of stored commands | 4 | `sync.retention` daily; subscriber `sync.drop_snapshot_cache` |
| `audit` | `audit_log` (append-only by trigger) | Audit search and per-record chain for HO. Every module writes rows through `platform/audit` | 2 | none |

Platform (`internal/platform/*`) holds config, db, cache, ratelimit, auth, httpx, jobs, events, commands,
territory, storage, sms (sender + every SMS template), push, paging, clock, testutil. No business logic there
(CONVENTIONS section 3).

## Decisions (fixed, don't reopen)

- Go 1.27 (the plan said 1.25), chi, pgx v5 + sqlc, goose, River on Postgres for jobs and events, Redis as cache
  and rate limits only (Redis down = slower, never broken), oapi-codegen strict servers, PostgreSQL 17 + PostGIS.
- One OpenAPI 3.0.3 spec per module (the plan said 3.1 and per surface; oapi-codegen doesn't support 3.1).
  Generated server code is `internal/<module>/api.gen.go` (the plan said `internal/gen/`).
- Makefile, not Taskfile. Generated code is committed; `make check` fails when it is stale.
- Modules never import each other: ports + `internal/xmod` only (section 5). A module touches only its own tables.
- FA offline: full snapshot down, idempotent commands up, no incremental sync (sections 6 and 8).
- Money in paise (int64), UUIDv7 IDs (phones mint them offline), E.164 phones, `*_te` Telugu fields.
- No competitor brands anywhere. Advice is a salt, plus a Shanmukha SKU only if one exists.
- Quiet hours 21:00-07:00 IST for farmer SMS/push. WhatsApp waits for a BSP decision.

## How to run and verify

```sh
cd backend
make dev-up      # Postgres+PostGIS (orbit, orbit_test) and Redis; creates .env from .env.example
make migrate     # goose + River migrations
make seed        # dev data; prints the dev HO, FA and farmer logins (DEV_FIXED_OTP=123456 in dev)
make run-api     # :8080
make run-worker  # second terminal; `make ping` also publishes a system.ping event
curl localhost:8080/readyz
curl -H "Authorization: Bearer $(make -s token KIND=fa)" localhost:8080/v1/fa/sync/status
make check       # before every push: generated code fresh, gofmt, go vet, all tests
make specs       # after a spec change: ENDPOINTS.md + contracts/build/{mobile,web}.yaml
make image       # container image orbit-backend:dev (IMAGE_TAG=<git sha> in CI)
python3 ../tools/smoke_test.py   # end to end against the running api + worker (dev seed, OTP 123456)
```

Dev seed logins: HO `admin@orbit.dev`, `agronomy@orbit.dev`, `agronomy2@orbit.dev` (second Agronomy user for
maker-checker), `finance@orbit.dev`, `ops@orbit.dev` (password `orbit-dev-pass`, TOTP set up on first login); FA
`FA-KDP-014`, `FA-CVL-002` (password `fa-dev-pass`); farmers by OTP `123456`.

Integration tests use `orbit_test` (`TEST_DATABASE_URL`) and skip when it is unset. Set
`TEST_REDIS_URL=redis://localhost:6379/15` to also run the Redis tests. Local stack details:
`dev/implementation-plan.md`.

## How to work in it

Point to the conventions; don't restate them in code reviews.

| Task | Steps | Reference |
|---|---|---|
| Add an endpoint | Spec first in `contracts/openapi/<module>.yaml` (absolute path; prefix picks the surface; shared error responses; `limit`/`cursor` for lists) → `make gen` → handler method on `StrictServerInterface` → rules in `service*.go` → tests. Then `make specs` (ENDPOINTS.md and both bundles; it fails on a schema-name clash across specs) | README "Adding an endpoint"; CONVENTIONS 4, 11; `contracts/implementation-plan.md` |
| Add a query | `internal/<module>/queries/*.sql` with `-- name: Foo :one\|:many\|:exec`, `make gen`. Only your module's tables. PostGIS as GeoJSON text | CONVENTIONS 11 |
| Add a sync command | Payload struct + `commands.Typed` handler in `commands.go`, register in `RegisterCommands`, idempotent on command ID, `territory.Bump` in the same tx. Add the type to the CONVENTIONS 6 table and its payload schema to `sync.yaml` | CONVENTIONS 6, 8 |
| Add an event | Name constant + payload struct + `catalog` entry in `internal/platform/events/catalog.go`; publish inside the writer's tx; subscribe with `events.Handle(bus, "<module>.<purpose>", fn)` in `RegisterSubscribers`. Subscribers must be idempotent. Update the CONVENTIONS 7 table | CONVENTIONS 7 |
| Add a periodic job | Job args with `Kind() "<module>.<job>"`, worker added in `RegisterWorkers`, package-level `PeriodicJobs()`; the integrator appends it in `periodicJobs()` in `internal/app/app.go`. Only the River leader schedules periodic jobs, so running several workers is safe | CONVENTIONS 12 (jobs), 13 |
| Add a migration | `migrations/000NN_<module>_<what>.sql`, Up and Down, own tables only. Next free number is `00027` (`00022`-`00025` were reserved and never used; don't fill them). `make migrate && make gen`; seed rows also go into `reseedSQL` in `testutil/db.go`; check `make migrate-down && make migrate`. Never edit an applied migration | README "Adding a migration"; CONVENTIONS 13 |
| Wire a port | Consumer declares the method in its `ports.go`; provider implements it on `*Service` with the same signature; value types in `internal/xmod`; the integrator sets the field in `internal/app/wire.go`. Never read ports in `New` | CONVENTIONS 5 |
| Add a module | Package with the section 2 anatomy, `oapi-codegen.yaml` + `generate.go`, a `sqlc.yaml` entry, a migration for its tables, then add it to `Modules`/`allPorts`/`NewModules` in `wire.go`. Hooks are discovered by interface | CONVENTIONS 2; `internal/app/hooks.go` |
| Add config | Field with `env` tag + default in `internal/platform/config/config.go`, a line in `.env.example`, a prod check in `Validate` if a dev value is unsafe, and a row in `infra/implementation-plan.md` | `config.go` |

Every state-changing service method writes `audit.Record` in its transaction (CONVENTIONS 9). Tests: service
unit tests with fakes, HTTP tests via `testutil.Router`, integration via `testutil.NewDB` (CONVENTIONS 10).

## Build order (remaining work)

Week 0 is Monday 9 Nov 2026. Each item needs specs updated first, `make check` green, and an audit row for every
write. Items marked (new) are not in the agreed backlog; they came out of reading the code for this plan.

### Phase 0 (wk 0-4): make it deployable

The container image, `migrate` with only `DATABASE_URL`, the worker health listener and forced update are done
(see Current state). Left:

1. **golangci-lint with depguard.** Add `.golangci.yml`: depguard denies `internal/<module>` importing any other
   module (only `internal/platform/...` and `internal/xmod`), plus errcheck, staticcheck, gosec basics. Install it
   in CI. *Done when* a test import of `internal/farmers` from `internal/visits` fails `make lint` in CI.
2. **Sentry.** JSON logs already exist (`LOG_FORMAT=json`). Add Sentry for panics and 5xx in api and job failures
   in worker (`SENTRY_DSN`, empty = off). *Done when* a forced panic shows in Sentry from staging.
3. **Dev partners.** MinIO and fake SMS/push servers in `dev/docker-compose.yml` (see `dev/implementation-plan.md`),
   usable once the adapters below exist. *Done when* `make dev-up` starts them and the S3 adapter's integration
   test runs against MinIO.
4. **`orbit_app` DB role.** The app connects as a role with no UPDATE/DELETE grant on the append-only tables
   (`audit_log`, `consents`, later the ledger), on top of today's triggers; migrations run as the owner. *Done
   when* a test checks the grants and staging uses that role.

### Phase 1a (wk 4-12, FA pilot ~1 Feb 2027): adapters and HO operations

5. **`adapters` module** (SYS-02). Real implementations behind the existing `storage.Storage`, `sms.Sender` and
   `push.Sender` interfaces, selected by `STORAGE_PROVIDER=s3`, `SMS_PROVIDER=<vendor>`, `PUSH_PROVIDER=fcm`:
   - S3 storage: presigned PUT/GET with short TTL, SSE-KMS, keys as today (`storage.ValidKey`), including farmer
     photos (`farmers/{id}/photo-{uuid}.{ext}`).
   - SMS: the chosen DLT-registered vendor; Unicode for Telugu; sends each template's DLT ID; retries via the
     existing `messaging.delivery` job.
   - Push: FCM HTTP v1 with a service account from Secrets Manager.
   - Delivery webhooks: replace the `/hooks/sms/{provider}` stub with signature checks and status updates on
     `deliveries` by `provider_ref`; reject unsigned calls with 401.
   - Short links for SMS (whitelisted domain, DLT rule) that redirect to `<FARMER_WEB_BASE_URL>/web/notices/{id}?t=`.
   - WhatsApp only after a BSP is chosen. Per-partner timeouts, retries, and a metric per call.
   *Done when* staging runs `ORBIT_ENV=prod` with these providers, an enrolment SMS reaches a test phone, a visit
   photo lands in S3, and a signed delivery report flips a delivery to delivered.
6. **Real DLT IDs, then message templates in the DB.** Replace the 20 placeholder IDs in
   `internal/platform/sms/templates.go` with the registered ones (launch blocker). Later, move the wordings to a
   messaging-owned table with admin endpoints to list and edit them (Agronomy or admin). *Done when* no ID is a
   placeholder (`sms.IsPlaceholder`); for the DB part, changing a wording needs no deploy.
7. **Nightly audit export to S3 Object Lock.** A periodic job writes the previous day's `audit_log` rows (and
   `consents`) as gzipped JSON Lines to the audit bucket (compliance mode), records the last exported time, and
   alerts on failure. *Done when* a day's file exists in staging, can't be deleted, and row counts match.
8. **CSV import for masters and CSV export on admin lists.** Imports for dealers, SKUs and issues (rules stay
   maker-checker: imported rules land as drafts), modelled on `POST /v1/admin/geo/village-imports` (large body
   limit, dry-run, per-row errors). Exports for farmers, FAs, visits, audit, advisory recipients: streamed CSV with
   the same filters and scope as the list endpoints, audited. *Done when* the H5 "Import CSV" and H2/H7/H8 "Export"
   buttons have endpoints, and an area-scoped HO user's export contains only their districts.
9. **One-call territory hand-over** (ADM-03, H2 "Hand over territory"). Today it is two calls:
   `POST /v1/admin/allocations/handover` (geo) then `POST /v1/admin/farmer-reassignments` with `from_fa_id`,
   `to_fa_id` and the affected `village_ids` (only the old FA's farmers in those villages move; unassigned
   farmers move only by `farmer_ids`). Add one endpoint that does both, moves open planned visits and call-backs
   (already done by the `farmers.reassigned` subscriber), optionally deactivates the old login on the date, and
   SMSes farmers. Must be safe to repeat. *Done when* one call moves allocations, farmers and open visits, and a
   retry moves nothing.
10. **`Idempotency-Key` on REST writes.** Middleware storing (key, principal, route, request hash, response) for
    24 h in Postgres; same key + same body replays the response, same key + different body is 409
    `idempotency_key_reused`. Document the header in the specs. Start with farmer and HO POSTs. *Done when* a
    retried `POST /v1/farmer/callbacks` with the same key creates one call-back.
11. **Known small gaps.** PATCH endpoints can't clear optional fields (decide: explicit `null` clears, then fix
    the handlers); `POST /v1/admin/fa-alerts` ignores the HO user's district scope (enforce it); the admin dealer
    list has no mandal filter (add `mandal_id`). *Done when* each has a test.
12. **Smaller API additions the clients asked for** (new). Each is additive:
    - Edit a visit after it syncs (an `EditVisit` command or admin correction, audited with before/after).
    - Advisory listened counts in the FA snapshot.
    - Audit search filters for actor kind and assisted actions (H8).
    - Admin view of one farmer's notices (H7 detail).
    - Advisory to selected farmer IDs (H7 "Send advisory").
    - httpOnly-cookie sessions for the HO portal (today tokens are in the JSON body).
    - A staging-only back-dating tool for time-based tests (missed visits, offline FAs, season codes).
    *Done when* each has its spec, endpoint or command, and a test.

### Phase 1b (wk 12-20, farmer app ~29 Mar 2027)

13. **`calendar` module** (F11 crop calendar, FA-05 tie-in). Tasks per crop stage (masters-owned content, Agronomy
    approved), a per-season task list for the farmer with tick-off, and stage reminders by SMS/push the evening
    before (respecting quiet hours). Farmer endpoints under `/v1/farmer/calendar...`. *Done when* a seeded cotton
    season shows its tasks, ticking one is saved, and the reminder job sends once per task.
14. **Weather** (FAR-05, INT-02). Adapter for the chosen feed, cached per grid cell in Redis with a Postgres copy of
    the last value, served on farmer home (`GET /v1/farmer/me` or a new `/v1/farmer/weather`). Blocked on the feed
    decision. *Done when* home shows weather for the plot location and the last saved value when the feed is down.
15. **HO "Add farmer"** (H7). `POST /v1/admin/farmers` using the same rules as `EnrolFarmer` (phone merge,
    `consent_pending` without proof, `farmer.registered` with `source=ho`). *Done when* an HO-added farmer appears
    in the assigned FA's next snapshot with consent pending.
16. **Farmer phone-number change.** HO-initiated (with OTP to the new number) and farmer-initiated (OTP to both),
    collision check against existing farmers, sessions on the old number revoked, audited. *Done when* the farmer
    signs in with the new number and keeps their plots and history, and the old number no longer reaches them
    (today an OTP sign-in with an unknown number creates a new self sign-up, so decide what the old number does).
17. **WhatsApp channel** if the BSP is chosen by then (adapter + templates + delivery reports).
18. **Farmer app additions** (new). SMS/WhatsApp preference endpoint (F10); farmer SKU detail for the product card;
    server Telugu TTS with `audio_url` on visit-advice notices; a "call me with the OTP" fallback for sign-in.
    *Done when* each has its spec, endpoint and a test.

### Phase 2 (wk 20-30, money live ~7 Jun 2027)

19. **Assisted mode.** `Principal.OnBehalfOf` and the audit column already exist. Add the farmer-OTP handshake
    (FA asks, farmer approves on their phone), a short-lived assisted token, audit rows marked assisted, and the
    rule that UPI PIN and KYC submit are never assisted. *Done when* H8 "Include actions done with FA help" can
    filter these rows.
20. **Money** (FAR-16-21, PLN-01-02, FA-11, ADM-06-07). New modules per the plan: `plans` (tiers, prices, Razorpay
    order per season, server-side plan checks), `services`, `invoices` (FA check, HO approval, 5% cashback, MRP
    cap), `payouts` (ledger, UPI payee-name match + selfie + Finance review, batches, second approval above
    Rs 5,000, separation of duties: the bill approver can't release its payout), Razorpay and payout webhooks with
    polling as backup. Ledger tables append-only. *Done when* the plan's exit test passes: a penny test end to end in
    production and a reconciliation report that matches the bank.

### Phase 3 (wk 30-38)

21. **AI help bot** (FAR-14, FAR-15). Claude through the Anthropic Go SDK with tools over the farmer's own data,
    Telugu speech-to-text and TTS. Hard guardrail: never names a chemical, dose or brand; offers "send a photo" and
    "call my FA" hand-offs. Output filter using `masters.ProductTerms` plus a blocklist, and an eval set in CI.
    *Done when* the eval set has zero chemical/dose/brand mentions and hand-offs create a call-back.
22. Soil-lab, schemes and loyalty adapters, engagement analytics (ADM-09), editable roles grid: scope later.

## Contract details the builder needs

- Surfaces and guard rules: CONVENTIONS 4. Error shape `{error: {code, message, details}}`; codes in use include
  `validation_failed`, `version_mismatch`, `device_revoked`, `session_revoked`, `password_change_required`,
  `payload_too_large`, `rate_limited`. New codes go in the spec and the CONVENTIONS list.
- Sync: CONVENTIONS 6 has every command type and payload; rejection reasons the FA app shows are
  `registered_with_another_fa` and `not_in_your_area`.
- Events: CONVENTIONS 7. New Phase 1a/1b events will likely be `farmer.phone_changed` and `calendar.task_due`
  (names to confirm when built).
- Prod config refuses `SMS_PROVIDER=log`, `PUSH_PROVIDER=log`, `STORAGE_PROVIDER=local`, a set `DEV_FIXED_OTP`,
  `CORS_ORIGINS=*` and an empty `TOTP_ENC_KEY`. Never change `TOTP_ENC_KEY` once secrets are sealed.

### What the clients wait on

| Client milestone | Backend items it needs |
|---|---|
| FA app pilot build (Phase 1a) | 5 (S3 photos, SMS for consent OTP and enrolment SMS, FCM for alerts), 6 (real DLT IDs), staging up |
| HO portal pilot (Phase 1a) | 8, 9, 10, 11, 12 |
| Farmer app launch (Phase 1b) | 5, 6, 10, 13, 14, 16, 18; 17 if WhatsApp is chosen |
| Farmer web pages (`/web/notices/{id}`, API `/v1/web/notices/{notice_id}`) | 5 (short links), CloudFront hosting from the infra plan |
| Money (Phase 2) | 19, 20 |

## Conventions

- Layout and file shape: CONVENTIONS 1-2. Keep files under ~400 lines; split by area (`service_plots.go`).
- Names: audit actions `<module>.<verb past tense>` (`farmers.enrolled`); job kinds `<module>.<job>`; subscriber
  names `<module>.<purpose>`; event names `<entity>.<past tense>`; error codes snake_case; JSON snake_case.
- Errors: return `apperr` values from services; handlers pass them through unchanged.
- Scope: area-scoped HO users (`DistrictIDs`) must be filtered in every new list, export and write
  (`p.HasAreaScope()`, `p.CanSeeDistrict(id)`). Add a test with a scoped user for each new admin endpoint.
- Partners: every outbound call goes through an interface in `internal/platform` (or the adapters module) with a
  dev/fake implementation, a timeout, retries in a River job, and no secrets or OTPs in logs (`logx.Redact`).
- Tests for new work: unit tests with fakes for rules, one HTTP test per endpoint (auth kind, role, validation),
  an integration test for SQL and transactions. No `t.Parallel()` in DB tests.
- No new third-party dependency inside a module without the tech lead's OK (Sentry, AWS SDK, FCM and the Anthropic
  SDK are expected ones; add them in `internal/platform` or the adapters module).
- PR checklist: spec changed first, `make gen`, `make specs` re-run, CONVENTIONS tables updated (ports,
  commands, events, config), migration Down works, `make check` green.

## Open decisions and blockers

| Decision | Blocks | Owner |
|---|---|---|
| SMS provider + DLT entity, header and template IDs | 5, 6, prod launch | Business |
| FCM project | 5 (push) | Business/tech lead |
| S3 bucket names and AWS region (ap-south-2 Hyderabad or ap-south-1 Mumbai) | 5, 7 | Tech lead, see `infra/implementation-plan.md` |
| Short-link domain for SMS links (must be DLT-whitelisted) | 5 | Business |
| WhatsApp BSP | 17 | Business |
| Weather feed | 14 | Business |
| MRP cap per pack (an agent assumed Rs 1,00,000) | 20 | Finance |
| TDS 194R and GST treatment of cashback | 20 | Finance |
| PATCH null semantics | 11 | Tech lead |

## Definition of done for the backend folder

- Every endpoint is in a spec, `contracts/ENDPOINTS.md` is regenerated, and `make check` passes in CI.
- No module imports another module (depguard enforces it).
- Every write has an audit row; every farmer data share has a consent record (INT-01).
- `ORBIT_ENV=prod` starts with real adapters in staging; `/readyz` is 200 and the worker is healthy.
- Phase exit tests met: 1a "5 FAs log visits for 2 weeks with no lost or duplicated records"; 2 "penny test
  in production and reconciliation matches the bank".
