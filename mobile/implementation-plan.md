# Mobile implementation plan (Farmer app + FA app)

## Purpose

How to build the two Flutter apps in `mobile/` against the backend as it stands today: the FA app first
(Phase 1a, offline-first) and then the Farmer app (Phase 1b, online-first, Telugu-first with voice). Both apps
share one generated API client, one design system and one string set. A new session should be able to start at
milestone M0 using only this file and the paths under "Read first".

## Read first

| What | Path |
|---|---|
| Backend contract (auth, errors, sync commands, snapshot, FA rule, consent proof) | `orbit/backend/docs/CONVENTIONS.md` (sections 4, 6, 8) |
| Endpoint inventory (138 operations by surface) | `orbit/contracts/ENDPOINTS.md` |
| Specs (OpenAPI 3.0.3, one per module) | `orbit/contracts/openapi/{identity,farmers,geo,masters,visits,messaging,sync}.yaml`; the client is generated from the bundle `orbit/contracts/build/mobile.yaml` |
| Snapshot sections and sync command payloads | `Snap*` and `<Type>Payload` schemas in `contracts/openapi/sync.yaml` (they match the code; snapshot keys are pinned by backend tests). Code: `backend/internal/farmers/territory.go`, `visits/snapshot.go`, `masters/service_advice.go`, `messaging/service_alerts.go`, `geo/provider.go` |
| Command payloads as decoded | `backend/internal/farmers/commands_payloads.go`, `visits/service_log.go` (`logVisitPayload`), `visits/commands.go` |
| Dev backend | `orbit/backend/README.md`, `orbit/backend/Makefile`, `orbit/dev/docker-compose.yml`, `orbit/backend/.env.example` |
| Working client flow (exact request shapes) | `tools/smoke_test.py`; port it to Dart as the first integration test |
| Architecture, stack, roadmap | Build plan, sections "Mobile apps", "FA offline sync", "Repository" (https://claude.ai/artifact/M85KFgHynuZ4gWBqz87pSa) |
| Wireframes | Farmer F1-F11 + states; FA app 16 screens (original HTML files are kept outside the repo (the product team shares them; never commit them); text in `docs/source/`) |

## Current state

- `mobile/apps/` and `mobile/packages/` are empty. `design/` is empty. `i18n/` has only an empty `voice/te/`.
- Backend is built and passing: all 8 modules, every `/v1/auth`, `/v1/farmer` and `/v1/fa` endpoint the apps need
  for Phase 1a/1b, seed data (`make seed`), dev fixed OTP `123456` (`DEV_FIXED_OTP`, dev only), SMS and push go to
  a log sender in dev (nothing is really sent).
- Also built for the apps: forced update (`GET /v1/auth/app-config`, `min_version`/`update_required` on
  heartbeats), open season codes (`season_codes`), farmer photo upload URLs, consent while `pending_profile`, OTP SMS
  in SMS Retriever format (when `OTP_SMS_APP_HASH` is set), Telugu FA alerts, typed snapshot and command schemas.
- Not built on the backend (see "Backend gaps"): weather, crop calendar tasks/reminders, AI help, real push/SMS,
  S3, plans/payments/wallet (Phase 2), assisted mode.

## Decisions (fixed, from the build plan and the brief)

- Two apps, not one app with a role switch. Melos workspace in `mobile/`: `apps/farmer`, `apps/fa`, shared
  `packages/*`. (The plan sketched `farmer_app`/`fa_app`; use `farmer`/`fa`.)
- Stack (plan): Flutter 3 stable, **Riverpod** for state, **go_router**, **Drift** (SQLite) for local data,
  **dio** for HTTP, **FCM** for push, **flutter_map** with offline tiles (Google Maps SDK forbids offline caching),
  generated client **orbit_api** from `contracts/openapi` with openapi-generator (dart-dio), **Sentry** for
  crashes, **Fastlane** to Play tracks, WorkManager for background sync.
- FA sync: full territory snapshot down (gzip + ETag, 304 when unchanged), commands up (batch <= 200,
  client-minted UUIDv7 IDs, idempotent). No incremental sync. Conflicts shown as "Keep mine / Keep HO's".
- Consent (FAR-04): FA app gets an `otp_proof` online and puts it in `EnrolFarmer.consent.otp_proof`; offline
  enrolment leaves the farmer `consent_pending` and the FA sends `RecordConsent` later.
- FA login: HO-issued ID + password, then a 4-digit PIN that works offline for up to 7 days. Revoked device wipes
  itself. Temp passwords must be changed (72 h expiry).
- Farmer app: OTP sign-in, never asks for READ_SMS; Telugu default; a Listen button on every screen; one task per
  screen; Android 8+, under 20 MB download.
- No competitor brands anywhere: advice shows a Shanmukha product only when the rule has a `sku_id`, else the salt.
- Distribution: Play closed testing track for the FA app (and the farmer pilot). Release tags
  `fa-app/1.0.3+12`, `farmer-app/1.3.0+45`.

Where the plan is silent, this file **recommends** (and says so): freezed + json_serializable for app models,
`uuid` 4.x for UUIDv7, `flutter_secure_storage`, SQLCipher for the FA database, `workmanager`, `geolocator`,
`image_picker` + `flutter_image_compress`, `just_audio`, `url_launcher`, `smart_auth` (SMS User Consent),
`connectivity_plus`, FVM to pin Flutter, Melos 7 with Dart pub workspaces.

## Workspace layout

```
mobile/
├─ pubspec.yaml            # pub workspace root + melos: config (scripts below)
├─ .fvmrc                  # pinned Flutter version
├─ analysis_options.yaml   # shared lints (very_good_analysis or flutter_lints + strict casts)
├─ apps/
│  ├─ fa/                  # FA app: features/{auth,farmers,enrol,visits,calendar,alerts,sync,settings}
│  └─ farmer/              # Farmer app: features/{auth,onboarding,home,fas,visits,inbox,farm,calendar}
└─ packages/
   ├─ orbit_api/           # GENERATED dart-dio client. Never hand-edit. Committed.
   ├─ orbit_core/          # env config, dio + interceptors, ApiError, session/token store, single-flight
   │                       # refresh, device_key, heartbeat, wipe, clock offset, connectivity, Sentry, logging
   ├─ orbit_store/         # Drift helpers: open DB (SQLCipher option), key in Keystore, migration test
   │                       # harness, kv cache table, simple outbox (farmer app)
   ├─ orbit_sync/          # FA only: snapshot tables, snapshot parser, command payloads, outbox, projector,
   │                       # sync engine, photo queue, WorkManager entry point
   ├─ orbit_ui/            # theme from design/tokens/, big high-contrast components, Telugu type
   ├─ orbit_l10n/          # ARB generated from i18n/te.json + en.json, voice-prompt key map
   ├─ orbit_media/         # camera, compression (~200 KB), checksum, upload helper
   ├─ orbit_voice/         # Listen button: bundled prompt audio + cached notice audio
   └─ orbit_maps/          # flutter_map + offline tiles for the FA territory
```

Rules: packages never import apps; feature screens stay inside their app; code moves to a package only when
the second app needs it (orbit_sync is the exception, kept separate so the engine is testable without Flutter UI).

Melos scripts (root `pubspec.yaml`, `melos:` section):

| Script | Does |
|---|---|
| `melos bootstrap` | resolves the workspace |
| `melos run gen:api` | regenerates `orbit_api` from `contracts/build/mobile.yaml` (below) |
| `melos run gen:tokens` / `gen:l10n` | `design/tokens/` -> `orbit_ui`; `i18n/*.json` -> ARB -> `flutter gen-l10n` |
| `melos run gen` | all of the above + `build_runner` (drift, freezed, json_serializable) in every package |
| `melos run check` | `gen`, `analyze`, `test` (local; no git check) |
| `melos run check:ci` | format check, generators in `--check` mode, then fails if generated files differ from git (they must be committed), `analyze`, `test` |

### Generated API client (orbit_api)

Generate from the committed bundle `contracts/build/mobile.yaml`: paths under `/v1/auth/`, `/v1/farmer/`,
`/v1/fa/` and `/v1/web/`, the components they reach, and the doc-only `SyncCommandPayloads`. It is written by
`tools/bundle-specs.py`, which fails if two specs define the same schema name differently. After a spec change run
`make backend-specs` from the repo root (or `make specs` in `backend/`), then regenerate the client.

```bash
# from the repo root
make backend-specs      # ENDPOINTS.md + contracts/build/{mobile,web}.yaml
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/local" openapitools/openapi-generator-cli:v7.10.0 generate \
  -i /local/contracts/build/mobile.yaml \
  -g dart-dio \
  -o /local/mobile/packages/orbit_api \
  --additional-properties=pubName=orbit_api,pubLibrary=orbit_api,serializationLibrary=json_serializable,dateLibrary=core \
  --global-property=skipFormModel=true
cd mobile/packages/orbit_api && dart run build_runner build --delete-conflicting-outputs
```

Pin the generator version (keep it in `tools/openapi-generator.version`; v7.10.0 or the newest 7.x tested).
Regenerate whenever a spec under `contracts/openapi/` changes: `melos run gen:api`, commit the result. CI fails
if the committed client is stale. Notes:
- Command payloads are free-form on the wire (`payload: object`), but `sync.yaml` documents each one
  (`EnrolFarmerPayload` ... `AckAlertPayload`, indexed by `SyncCommandPayloads`), so `orbit_api` has typed models
  for them. `orbit_sync` builds commands from those models.
- The `Snap*` schemas match the snapshot the server writes (incl. `consent_pending`, `advice_status`,
  `season_codes`, `photo_key`, nullable crop `duration_days`, salt `name_te`, SKU `product_name_te`). Use the
  generated models, parse in an isolate, and still ignore unknown sections and fields (new ones are additive).
  Keep one test against a real snapshot from the dev backend.

### Design system and i18n

- `design/tokens/` (colours light + dark, type scale, spacing, radius) is the single source. Until the design
  folder has it, M0 creates a first version from the wireframes (green primary, high contrast, min body text
  18 sp for the farmer app, 16 sp for FA). Style Dictionary (or a small Dart script in `tools/`) writes
  `orbit_ui/lib/src/tokens/orbit_tokens.g.dart`; `orbit_ui` builds `ThemeData` from it.
- Components: `BigButton` (min 56 dp tall, full width), `IconTile` (with padlock state, FAR-06), `ListenButton`,
  `StateCard` (one card, one action: the empty/offline/error states), `PhoneField` (+91), `OtpField`,
  `StepHeader`, `SyncBadge`, `ConflictCard` (Yours / HO's). Touch targets >= 48 dp, 56 dp for primary actions.
- Font: Noto Sans Telugu (+ Noto Sans), bundled, subset if size needs it. Never rely on the phone's Telugu font.
- `i18n/te.json`, `i18n/en.json` (keys like `farmer.home.call_fa`) and `i18n/voice/te/<key>.m4a` are the single source.
  `tools/i18n/build` (`make i18n`) writes `orbit_l10n/lib/l10n/app_te.arb` / `app_en.arb`; `flutter gen-l10n` makes
  `AppLocalizations`. `orbit_l10n` also exports `voiceAsset(key)` so a Listen button plays the prompt with the
  same key. Farmer-facing SMS text is not here (it lives in `backend/internal/platform/sms/templates.go`, one DLT
  template per wording and language).

## Contract details the builder needs

### HTTP basics (orbit_core)

- Base URL per flavour: `dev` (Android emulator: `http://10.0.2.2:8080`), `staging`, `prod`. Cleartext allowed
  only in the dev flavour's network security config.
- Errors are always `{ "error": { "code", "message", "details" } }`. Map to a sealed `ApiError` with `code`,
  `status`, `details`. Show our own Telugu/English text per code; the English `message` is a fallback.
- Lists: `?limit=&cursor=` -> `{ items, next_cursor }`.
- Dates `YYYY-MM-DD`, times RFC 3339 UTC. Phone numbers: send what the user typed (10 digits is fine), the
  server normalises to `+91XXXXXXXXXX`. URL-encode `+` as `%2B` in query strings (`/v1/fa/farmers/lookup?phone=`).
- Clock: every heartbeat returns `server_time`. Keep `offset = server_time - device_now` and use the corrected
  time for `visited_at` and `client_created_at` (LogVisit rejects `visited_at` in the future; cheap phones often
  have wrong clocks).

### Error handling table (both apps)

| Response | App does |
|---|---|
| 401 `unauthorized` with `details.reason = "expired"` on an API call | single-flight refresh, then retry the request once |
| 401 other `unauthorized` on an API call | try one refresh; if that fails, go to sign-in (FA offline: PIN still opens local data) |
| 401 `device_revoked` (any call, incl. login/verify/refresh) | **wipe**: delete DB, files, tokens, PIN; new `device_key`; go to sign-in |
| 401 `refresh_reused` / 401 on `/v1/auth/refresh` with reason `expired` | session gone: sign in again (FA: password; outbox is kept) |
| 401 `temp_password_expired` (FA login/refresh) | "Your temporary password has expired. Call HO for a new one." |
| 403 `password_change_required` | route to Change password; after 204 call `/v1/auth/refresh` for a clean token |
| 403 `forbidden` | wrong surface or not allowed: log to Sentry, show a generic card |
| 429 `rate_limited` | read `Retry-After` (seconds); show a countdown (OTP resend) or delay the sync job; never hammer |
| 413 `payload_too_large` | sync: halve the batch and retry |
| 503 `unavailable`, 5xx, timeout | retry with backoff; for user actions show "try again" |

### Tokens and refresh (both apps)

- `TokenPair{access_token, access_expires_at, refresh_token, refresh_expires_at}`. Access lives 15 min;
  refresh 90 days (farmer) / 30 days (FA) in dev config. Store both in `flutter_secure_storage`.
- **Single-flight refresh**: a dio `QueuedInterceptor`; one in-flight `Future<TokenPair>` shared by every caller.
  Refresh proactively when < 60 s of access life is left.
- **Rotation with 60 s grace**: each refresh token is accepted once. If the refresh response is lost, retrying
  with the same old token within 60 s returns the same successor; after that, any reuse revokes the session
  (`refresh_reused`). So: save the new pair before using it; on a network failure retry the same old token at most
  until 50 s after the first attempt, then stop and treat the session as lost. The grace also covers the UI
  isolate and the WorkManager isolate refreshing at the same moment (both get the same successor).
- `device_key`: random install ID (UUID v4, `^[A-Za-z0-9._:-]+$`, 8-128 chars) created on first launch, kept in
  secure storage, replaced after a wipe.

### Farmer sign-in (F1, F1a, village)

1. `POST /v1/auth/otp/request {phone, language: te|en}` -> `OtpSent{phone_masked, expires_in_seconds,
   resend_after_seconds}`. Resend button enabled after `resend_after_seconds` (30). 429 -> countdown from
   `Retry-After`.
2. Autofill: zero-tap SMS Retriever (`smart_auth`) when the server sends the Retriever format (`<#>` first, the
   app's 11-character hash on the last line). The backend does this when `OTP_SMS_APP_HASH` is set, so give infra
   the hash for each flavour's signing key (Play App Signing key for prod). Fall back to the SMS User Consent API
   (no permission, no hash) when the hash is not set.
3. `POST /v1/auth/otp/verify {phone, code, device{device_key, model, os_version, app_version, push_token?}}` ->
   `FarmerSession{tokens, farmer_id, device_id, is_new, farmer_status}`. Errors: 400 `otp_invalid`
   (`details.attempts_left`), 400 `otp_expired` (ask for a new code), 401 `device_revoked`.
4. Route on `farmer_status`: `pending_profile` -> consent (F1a) -> village picker -> name; `active` -> Home;
   `inactive` -> "Account paused, call helpline"; `null` -> `GET /v1/farmer/me` and decide.
5. Consent on F1a goes straight to the server: `POST /v1/farmer/me/consents {purpose: "programme", granted,
   notice_version, audio_played}` works while the farmer is `pending_profile` (grant and withdraw; 403 only for a
   deactivated farmer). Keep it in the outbox if offline. Then the village picker and
   `POST /v1/farmer/me/complete-profile {name, name_te?, language, village_id}` (409 `profile_already_complete` =
   already done, carry on).
6. Village picker: `GET /v1/farmer/villages?q=` (Telugu or English, prefix then fuzzy, `limit` <= 50) with a
   browse fallback `GET /v1/farmer/geo/tree` -> `GET /v1/farmer/villages?mandal_id=`.

### FA sign-in, password change, PIN

1. `POST /v1/auth/fa/login {code, password, device{device_key, ...}}` -> `FASession{tokens, device_id,
   field_assistant, must_change_password, offline_policy{pin_length, offline_grace_days, pin_max_attempts}}`.
   Failures are one 401 `unauthorized` message; also `device_revoked`, `temp_password_expired`.
2. If `must_change_password`: Change password screen -> `POST /v1/fa/me/password {current_password,
   new_password}` (>= 8 chars, a letter and a digit, not the login ID) -> 204 -> `POST /v1/auth/refresh` to get a
   token without the must-change flag. Every other `/v1/fa/*` call returns 403 `password_change_required` until then.
3. Set PIN (`pin_length`, 4). The PIN never leaves the phone. Store a PIN verifier (Argon2id/PBKDF2 + salt) and
   the refresh token encrypted with a key derived from PIN + a Keystore-held secret (plan).
4. PIN unlock works offline while the last successful online contact (login or refresh) is within
   `offline_grace_days` (7). After that: "Session ended. Log in with your password once you have network."
   After `pin_max_attempts` (5) wrong PINs the PIN is disabled and the password is required. Unsynced outbox
   rows are never deleted by a lock-out, only by a revoke wipe.
5. FA profile (name, code, territory label for the PIN screen) comes from `field_assistant` in the login
   response; there is no `GET /v1/fa/me`.

### Heartbeat and push token

`PUT /v1/fa/devices/me` / `PUT /v1/farmer/devices/me {model, os_version, app_version, push_token}` ->
`DeviceStatus{device_id, wipe, server_time, min_version, update_required}`. Call on app start, after each sync,
when FCM rotates the token, and once a day from WorkManager. `wipe: true` -> wipe exactly as for 401
`device_revoked`. `update_required: true` -> blocking "Update the app" screen (FA: after pushing the outbox).

### Forced update and flags

`GET /v1/auth/app-config?app=farmer|fa` (no token, cacheable 5 min) ->
`AppConfig{app, min_version, latest_version, store_url, flags{}}`. Call at start, before sign-in. Below
`min_version`: block and open `store_url` (FA app: push the outbox first if online, never drop it). Below
`latest_version`: a dismissable "New version" card. `flags` turn features on or off (unknown flags ignored); use
them for push, weather and WhatsApp-dependent UI. FCM is blocked on the FCM
project decision: ship with push disabled behind a flag, the heartbeat still runs.

## FA offline engine (orbit_sync)

### Local database (Drift, SQLCipher-encrypted, key in Android Keystore)

Snapshot tables are replaced wholesale on every snapshot. Key fields (from the real snapshot JSON):

| Table | From section | Key fields |
|---|---|---|
| `farmers` | `farmers` | id, phone, name, name_te, language, village_id, source, photo_key, plan, status, consents_granted[], consent_pending, profile_completed_at, **version**, created_at, updated_at |
| `plots` | `plots` | id, farmer_id, label, village_id, boundary (GeoJSON text), pin_lat/pin_lng, area_acres, area_source (`boundary`/`typed`), gps_accuracy_m, status, **version** |
| `seasons` | `seasons` | id, farmer_id, plot_id, season_code, crop_id, sowing_date, previous_crop_id, status, version |
| `visits` | `visits` | id, farmer_id, plot_id, season_id, fa_id, status (`planned`/`done`), planned_for, planned_slot, purpose, visited_at, farmer_present, stage_id, stage_name(_te), notes, photo_count. All planned visits + the 3 latest done per farmer |
| `visit_issues` | `visits[].issues[]` | id, visit_id, issue_id, issue_name(_te), severity, advice_status (`resolved`/`unresolved`), rule_id, salt_id, salt_name(_te), sku_id, product_name(_te), dose, dose_te |
| `callbacks` | `callbacks` | id, farmer_id, requested_at (open requests only) |
| `alerts` | `alerts` | id, kind (`new_farmer`/`callback`/`invoice_check`/`ho_note`), farmer_id, ref_id, title, body, title_te, body_te (null on older alerts and English-only HO notes), status (`open`/`acknowledged`/`closed`), created_at, acknowledged_at |
| `m_crops`, `m_stages` | `masters.crops[]` | crop: id, code, name, name_te, duration_days (nullable); stage: id, crop_id, code, name, name_te, seq, start_day, end_day |
| `m_season_codes` (one row) | `masters.season_codes` | current, next, all_open[], valid_until (IST date) |
| `m_issues` | `masters.issues` | id, crop_id, type, name, name_te |
| `m_salts`, `m_skus` | `masters.salts`, `.skus` | salt: id, name, name_te (nullable); sku: id, code, product_name, product_name_te (nullable), salt_id, pack_size, mrp_paise, cashback_eligible |
| `m_rules` | `masters.rules` | id, rule_key, version, issue_id, salt_id, sku_id (nullable), dose_per_acre, dose_per_acre_te |
| `villages` | `villages` | id, name, name_te, lgd_code, lat, lng, mandal_id/name/name_te, district_id/name/name_te |

Local-only tables: `sync_meta` (etag, territory_version, masters_version, generated_at, last_pull_at,
last_push_at, last_online_at), `outbox`, `photo_queue`, `sync_log` (30 days, for "records synced today" and
rejected items), `sync_lock` (lease row so the UI and the WorkManager isolate never push at the same time).

### Snapshot pull

1. `GET /v1/fa/sync/snapshot` with `If-None-Match: <stored etag>`. ETag looks like `"t12-m3"`.
2. 304 -> touch `last_pull_at`, done. Set dio `validateStatus` to accept 304 for this call.
3. 200 -> body is gzip (`Content-Encoding: gzip`). dart:io's HttpClient sends `Accept-Encoding: gzip` and
   inflates by itself; do not decompress twice (check in the M2 spike).
4. Parse in a background isolate. In **one** Drift transaction: clear snapshot tables, insert all sections,
   replay the outbox projection (below), write `sync_meta` with the new ETag/versions. Only then show it.
5. Under 1 MB gzipped for a few hundred farmers; still, stream-insert in batches of 500 rows to keep memory low
   on 2 GB phones.

When to pull: after each push if the batch response's `territory_version`/`masters_version` differ from
`sync_meta`; when `GET /v1/fa/sync/status` returns an `etag` different from the stored one (poll on app
foreground, after a push notification, and every 15 min while online); on "Sync now". Always push before pull.

### Command outbox

`outbox(seq autoincrement, id uuid v7, type, payload json, entity_type, entity_id, depends_on_id?, state,
attempts, next_attempt_at, batch_territory_version?, result json?, created_at, client_created_at)`.
States: `queued -> sending -> applied | merged | conflict | rejected`, plus `dropped` (parent rejected) and
`resolved` (conflict closed by the FA).

- IDs: command `id` and every entity ID (`farmer_id`, `plot_id`, `season_id`, `visit_id`, `issue_visit_id`,
  `photo_id`, `next_visit.visit_id`) are UUIDv7 minted on the phone (`Uuid().v7()`). Never reuse a command ID
  for a different payload.
- Writing a command and its local projection happens in one Drift transaction, so a killed app never has one
  without the other.
- Ordering: send in `seq` order. Natural chain: EnrolFarmer -> SavePlot -> StartSeason -> PlanVisit/LogVisit.
  The server processes a batch in order.
- Batching: up to 200 commands per `POST /v1/fa/sync/commands {commands:[{id, type, payload,
  client_created_at}]}`; also keep the body well under 5 MiB (server cap for this route).
- Retry: network failure, timeout or 5xx -> the whole batch goes back to `queued` (safe: IDs are idempotency
  keys). Backoff 15 s, 1 min, 5 min, 15 min, 30 min cap, +-20% jitter; reset on connectivity change, app
  foreground or "Sync now". 400 for the whole batch means a client bug: bisect to find the bad command, mark it
  `rejected` locally with reason `client_invalid`, report to Sentry, carry on.
- `retry_from`: when non-null, results cover commands `[0, retry_from)`; apply those, put the rest back to
  `queued` and resend from that index after backoff. A command the server fails 5 times comes back `rejected`
  with `server_could_not_apply`.
- Projection replay: after a snapshot is written, re-apply the local effect of every command in `queued`,
  `sending`, and of `applied`/`merged` commands whose `batch_territory_version` is newer than the snapshot's.
  Projections are upserts by entity ID, so replaying twice is harmless. Delete `applied`/`merged` rows once a
  snapshot with `territory_version >= batch_territory_version` is in (copy a line to `sync_log` first).

### Result handling

| Status | Local effect | UI |
|---|---|---|
| `applied` | keep projection until the next snapshot carries it | Sync: "synced" count |
| `merged` (EnrolFarmer; `merged_into` = existing farmer) | rewrite the local farmer ID to `merged_into` in every local table and in queued payloads (server also follows aliases, but the UI must not show two farmers); pull the snapshot to get the existing farmer's plots/visits | "Already registered: added to Raju P's record" |
| `conflict` (`SavePlot`, `UpdateFarmer`; `conflict{field, yours, theirs}`) | stop replaying this command; pull the snapshot so the screen shows HO's value and the current `version` | ConflictCard "Yours 1 ac 30 gunta / HO's 2 ac 0 gunta". **Keep mine** = new command (new ID, same payload) with `expected_version` = the snapshot's current version. **Keep HO's** = mark `resolved` (nothing is sent; log the choice locally) |
| `rejected` | stop replaying; mark dependents (`depends_on_id` chain) `dropped`; drop queued photos of a rejected LogVisit | Sync: red row with the reason. Map known codes to Telugu/English text: `registered_with_another_fa` ("This farmer is with another FA. Call HO."; no farmer ID comes back), `not_in_your_area` ("Village is outside your area"), `server_could_not_apply` ("Could not save. HO has been told."). Other reasons are English sentences: show them under a generic heading |

Conflicts and rejections stay on the Sync screen until the FA taps them away (30 days max).

### Command payloads (exact)

| Command | Payload | From screen |
|---|---|---|
| `EnrolFarmer` | `farmer_id, phone, name, name_te?, language (te/en), village_id, photo_key?, consent{purposes[], otp_proof?, audio_played, notice_version}` (a `photo_key` not under `farmers/{farmer_id}/` is dropped, the enrolment is kept) | Enrol steps 1-3 |
| `RecordConsent` | `farmer_id, purposes[], otp_proof, audio_played, notice_version` | Farmer 360 "Record consent" (for `consent_pending`) |
| `SavePlot` | `plot_id, farmer_id, label (1-60), boundary_geojson?, pin{lat,lng}?, area_acres, area_source (boundary/typed), gps_accuracy_m?, expected_version?` (a boundary or a pin is required) | Enrol step 2, plot edit |
| `StartSeason` | `season_id, farmer_id, plot_id, season_code (^[a-z]+-[0-9]{4}(-[0-9]{2})?$), crop_id, sowing_date?, previous_crop_id?` | Enrol step 3 |
| `UpdateFarmer` | `farmer_id, expected_version, fields{name?, name_te?, language?, village_id?, photo_key?}` (`photo_key` must be under `farmers/{farmer_id}/` or the command is rejected) | Farmer 360 edit, new photo |
| `PlanVisit` | `visit_id, farmer_id, plot_id, season_id, planned_for, planned_slot (morning/afternoon/any), purpose?` | Calendar "Add", after enrolment, alert "plan visit" |
| `LogVisit` | `visit_id, farmer_id, plot_id, season_id, visited_at, location{lat,lng}?, farmer_present, stage_id?, notes?, issues[{issue_visit_id, issue_id, severity (low/moderate/high), advisory_rule_id}], photos[{photo_id, content_type}], next_visit?{visit_id, planned_for, planned_slot}` (<= 20 issues, <= 20 photos) | Visit log. Use the planned visit's `visit_id` when starting from the calendar (it turns `done`); a new UUIDv7 for an unplanned visit |
| `CancelVisit` | `visit_id, reason?` | Calendar |
| `CloseCallback` | `callback_id, note?` | Alerts "Call Ravi K" -> after the call. (LogVisit also closes the farmer's open call-back.) |
| `AckAlert` | `alert_id` | Alerts "Got it" |

### Farmer photo

`POST /v1/fa/farmers/{farmer_id}/photo/upload-url {content_type, bytes}` (jpeg/png/webp, <= 5 MB, 120 an hour per
FA) -> `FarmerPhotoUpload{storage_key, url, method, headers, expires_at}`. `farmer_id` is the UUIDv7 the app
minted, so it works before `EnrolFarmer` has synced (403 if the farmer exists and is another FA's). PUT the image,
then send `storage_key` as `EnrolFarmer.photo_key` or `UpdateFarmer.fields.photo_key`. Needs network: offline,
enrol without a photo and add it later with UpdateFarmer. The farmer app does the same with
`POST /v1/farmer/me/photo/upload-url` (20 an hour) and `PATCH /v1/farmer/me {photo_key}`. `photo_url` (presigned,
15 min) comes back on Farmer 360 and the farmer home; refetch it rather than caching the URL.

### Visit photos (after LogVisit has synced)

1. Capture with `image_picker`, compress to ~200 KB JPEG (long edge ~1280 px), save in app files, compute
   SHA-256. Row in `photo_queue(photo_id, visit_id, path, content_type, bytes, sha256, state, attempts)`; the
   same `photo_id` and `content_type` go into `LogVisit.photos`.
2. Only after that LogVisit is `applied`: `POST /v1/fa/visits/{visit_id}/photos/{photo_id}/upload-url
   {content_type, bytes}` -> `PhotoUpload{url, method, headers, expires_at, storage_key}`.
3. Upload the file with exactly `method`, `url` and `headers` (a plain dio request without our auth
   interceptor).
4. `POST .../confirm {sha256}` -> 200. Then delete the full file, keep a small thumbnail.
5. Errors: 404 = visit not synced yet / rejected (wait, or drop if the LogVisit was rejected); 409
   `photo_already_uploaded` = treat as done and confirm; 409 `upload_missing` on confirm = PUT again; 400 on
   `content_type` = client bug. Expired URL = ask for a new one.
6. Honour the "Upload photos on Wi-Fi only" setting. Visit data never waits for photos.

### Background sync

WorkManager: a periodic job (15 min, network required) and a one-off job on connectivity change. Each run: take
the `sync_lock` lease -> push outbox -> pull snapshot if versions changed -> photos -> heartbeat. Runs without
the FA opening the app. It uses the stored refresh token, so the token must be readable without the PIN in the
background: keep a Keystore-wrapped copy for the worker, and still require the PIN for the UI.

## Screen map: FA app

| Wireframe screen | Data source | Notes |
|---|---|---|
| Issued login | `POST /v1/auth/fa/login`; `POST /v1/fa/me/password`; `/v1/auth/refresh` | "Remember this device" = set PIN. Footer: app version + `sync_meta.last_pull_at`. "Forgot password? Call HO" = `tel:` helpline |
| PIN unlock | local (PIN verifier, `sync_meta`) | "46 farmers and 3 unsynced records" = count `farmers` + `outbox` queued. "Use password instead" |
| Farmers near me (list) | snapshot `farmers`, `plots`, `villages`, `visits`; GPS | Nearest first: plot pin or boundary centroid, else village lat/lng. Chips: New, 30+ days since last done visit, Finish enrolment (`consent_pending`, no plot or no season). Call = `tel:`, WhatsApp = `https://wa.me/<phone>` |
| Farmers near me (map) | same + `orbit_maps` tiles | "Map saved offline" = tiles downloaded for the territory bbox (from `villages`). Tile licence decision is Phase 0 |
| Visit calendar | snapshot `visits` (planned) + projected `PlanVisit`/`LogVisit` | Day strip, morning/afternoon (`planned_slot`). Start visit -> Visit log with that `visit_id`. Add -> PlanVisit. Cancel -> CancelVisit. "Find farmers due a visit" = list filter. "Plan my route" is Phase 3: hide |
| Visit calendar after saving | same | Logged visit shows Done + unsynced badge until applied |
| Alerts | snapshot `alerts` (offline); `GET /v1/fa/alerts` when online | Show `title_te`/`body_te` when the UI is Telugu and they are set, else `title`/`body`. `new_farmer`: Finish enrolment (prefill phone/village, lookup) or Call + plan visit. `callback`: Call -> CloseCallback. `ho_note`: Got it -> AckAlert. `invoice_check`: Phase 2, hide. Badge = open alerts |
| Enrol step 1 (farmer) | `GET /v1/fa/farmers/lookup?phone=` (online); `POST /v1/fa/consent-otp/request` + `/verify`; snapshot `villages` | Lookup statuses: `new` continue; `mine` open Farmer 360; `unassigned_in_my_area` "Already registered ... We'll add to his record" (enrol continues, server merges); `outside_my_area` / `other_fa` stop and call HO; `deactivated` stop. Lookup is limited to 60/hour: call it once per number. Offline: skip lookup and OTP, show "The number is checked again at sync", enrol without `otp_proof` (farmer becomes `consent_pending`). Play the Telugu consent audio, set `audio_played`. Proof is valid 7 days; if older at send time, drop it and send RecordConsent later. Farmer photo: see "Farmer photo" above (online only) |
| Enrol step 2 (plot) | GPS (`geolocator`), local | Boundary walk with accuracy gate: allow walking only at <= 10 m (show "GPS is ±28 m, too rough"), close polygon, compute area locally for display (server recomputes in PostGIS). Fallback: acres + guntas (40 guntas = 1 acre) -> `area_acres` decimal, `area_source: typed`, pin. Village "from GPS" = nearest snapshot village, editable. SavePlot |
| Enrol step 3 (crop) | masters `m_crops`; local | Crop, sowing date, previous crop. Season picker from `m_season_codes.all_open` (default `current`). The snapshot ETag does not change on a season boundary, so after `valid_until` (IST) pull without `If-None-Match`; a Redis-cached snapshot can be up to 2 h old, so if `valid_until` is still past, offer the old `next` as current until a fresh pull. StartSeason. "Plan first visit" -> PlanVisit |
| Visit log and advice | masters `m_stages`, `m_issues`, `m_rules`, `m_salts`, `m_skus`; snapshot `seasons`; GPS; camera | 1 Photos (aim 1-3). 2 Stage: suggest from days after `sowing_date` vs `start_day..end_day`. 3 Issue: `m_issues` where `crop_id` = season crop; severity low/moderate/high. 4 Salt (FA-09): `m_rules` where `issue_id` = issue; each row shows salt name + dose; if `sku_id` set, "Shanmukha product: <product_name>", else "No Shanmukha product, farmer sees the salt name only". The picked rule's `id` is `advisory_rule_id`. No rule for an issue -> log it with `advisory_rule_id: null` (stored unresolved, HO follows up). 5 Next visit -> `next_visit`. Location + `farmer_present`. "Save & tell farmer" = LogVisit. "Edit this visit": only while the command is still `queued` (replace its payload in place); after sync, editing is not supported (backend backlog) |
| Farmer 360 | snapshot `farmers`, `plots`, `seasons`, `visits`, `visit_issues` | Call, WhatsApp, Directions (`geo:` intent to plot pin), Start visit. Stage + day from season. Last visit + advice. Consent status; "Record consent" for `consent_pending`. Edit profile -> UpdateFarmer. Advisories listened, wallet, invoices, KYC: not in the snapshot / Phase 2, hide. "Help on farmer's phone" (assisted mode): backlog, hide |
| Farmer app assisted mode | none yet | Backlog (assisted mode). Not in 1a/1b |
| Invoice check | none yet | Phase 2. Not built |
| Sync status | `outbox`, `sync_log`, `photo_queue`, `sync_meta`; `GET /v1/fa/sync/status` | Banner: last sync time, pending count. Rows per command with pill (queued, synced, conflict, rejected). ConflictCard with Keep mine / Keep HO's. Wi-Fi-only toggle. "N records synced today". Sync now |
| Error and offline states | local | Low GPS -> Type area / Try again. Conflict card. "Session ended: unlock with your PIN; full login needed within 7 days" |

## Screen map: Farmer app

Online-first with a Drift cache (`orbit_store`) of Home, visits, notices and FA list. Offline: show cached data
with "Saved at 7:00 am" and queue call-back, read and listened marks in a small outbox.

| Wireframe screen | Data source | Notes |
|---|---|---|
| F1 Phone and OTP login | `GET /v1/auth/app-config?app=farmer`; `POST /v1/auth/otp/request`, `/verify` | Language chip sets `language` and app locale (FAR-02). Resend after 30 s. "OTP not received? Call me": blocked (no voice OTP, backlog); show helpline instead |
| F1a Consent | `POST /v1/farmer/me/consents` (allowed while `pending_profile`), before the village picker | `purpose: programme`, `notice_version` from the bundled notice, `audio_played` when the Listen button finished. Soil-partner question (`soil_partner`) is asked later at the first soil-test booking (Phase 2+) |
| Village picker (not in wireframes, plan adds it) | `GET /v1/farmer/villages?q=`, `/v1/farmer/geo/tree` | Then `POST /v1/farmer/me/complete-profile`; this assigns the lead FA and alerts them |
| F2 Home | `GET /v1/farmer/me` (`farmer`, `photo_url`, `village`, `plots[{plot, active_season, days_after_sowing, current_stage}]`, `fa`, `next_visit`); `GET /v1/farmer/notices/unread-count` | Name, village, crop, acreage, plan badge (`farmer.plan`). FA card: Call = `tel:` `fa.phone` (FAR-07). Next visit date. Weather card: blocked (FAR-05). Tiles: Calendar, Pests (-> visits/advice), Ask by voice (Phase 3, locked), Soil test/Schemes/Services/Premium (Phase 2/3, padlock or hidden). No FA state: "Your FA will call within 2 days" + helpline |
| F3 Look for FAs | `GET /v1/farmer/fas?level=village|mandal|district`; `POST /v1/farmer/callbacks`; `POST /v1/farmer/callbacks/{callback_id}/cancel`; `GET /v1/farmer/callbacks/current` | Tabs = `level`. Each `FAOption{fa, coverage_level, is_lead, is_my_fa}`. Call = `tel:`, WhatsApp = `wa.me` (FAR-09). "Ask your FA to call you back": POST has no body; 201 new or 200 already open (safe to retry from the outbox); 409 `no_fa_assigned`. Undo = cancel (409 `callback_closed` if the FA already closed it) |
| F4 My visits | `GET /v1/farmer/visits` (paged, <= 50), `GET /v1/farmer/visits/next` | Group by `plot_id` (name from Home cache). Each issue: `issue_name_te`, severity, `salt_name_te`/`product_name_te`, `dose_te`; `advice_pending` -> "Your FA will follow up". Empty: "No visits yet" + Call FA |
| F5 My Crop Advisory (inbox) | `GET /v1/farmer/notices`, `POST .../{notice_id}/read`, `POST .../{notice_id}/listened` | `pinned` first. Mark read when opened; `listened` when audio played to the end (also marks read). `audio_url` is a short-lived presigned URL: download once, cache the file by notice ID, never cache the URL. Telugu first (`title_te`, `body_te`), English if the farmer chose it |
| F6 Ask by voice | none | Blocked: AI help bot (FAR-14/15, Phase 3). Tile locked |
| F7, F7b Plan and payment | none | Phase 2 |
| F8 Services, F8a Product card | `GET /v1/farmer/dealers?lat&lng&sku_id` exists | Phase 2 for booking and cashback. In 1b, tapping advice with a `sku_id` can show product name, dose and nearby dealers (no pack/MRP: farmer SKU detail is backlog) |
| F8b Advice without a Shanmukha product | from F4 data (`salt_only`) | "Ask for this name at the shop" + Call FA |
| F9, F9a, F9b, F9c Wallet, KYC, bill, UPI | none | Phase 2 |
| F10 My farm | `GET /v1/farmer/me`; `PATCH /v1/farmer/me {name?, name_te?, language?, photo_key?}`; `POST /v1/farmer/me/photo/upload-url`; `POST /v1/farmer/me/plots {label?, pin, area_acres}`; `POST /v1/farmer/me/plots/{plot_id}/seasons {season_code, crop_id, sowing_date?, previous_crop_id?}` (409 `active_season_exists`); `POST /v1/farmer/me/seasons/{season_id}/close {outcome: harvested|abandoned}`; `GET/POST /v1/farmer/me/consents`; `GET /v1/farmer/crops` (stages + `season_codes`; refresh after `valid_until`) | Season picker from `season_codes.all_open`. Village change goes through FA/HO (not editable here). Add plot: GPS pin + area in acres/guntas, one input per screen. Consents list (`programme`, `soil_partner`, `schemes_finance`, `loyalty`; `granted: null` = never asked). Messages SMS/WA preference: no endpoint (backlog). KYC: Phase 2. Your FA -> F3 |
| F11 Crop calendar | `GET /v1/farmer/crops` (stages) + Home `days_after_sowing`, `current_stage` | 1b shows the stage strip and "day 137 of about 170". Tasks list, tick-off and SMS reminders: blocked (calendar module) |
| Empty, offline, error states | local | One card, one action, Listen button. Offline banner with cache time. Payment pending/bill upload failed: Phase 2 |

Voice notes everywhere (NFR-01): each screen has a `ListenButton` playing `i18n/voice/te/<screen key>.m4a`.
Dynamic text (advice, notices without audio) has no audio until server-side TTS exists (backlog); do not use the
phone's Telugu TTS as the main path (plan: patchy on cheap phones).

## Low-end phones, poor networks, data use

- `minSdkVersion 26` (Android 8). Test on 2 GB RAM phones in the Rs 7-10k range (QA device lab).
- Release with R8, `--obfuscate --split-debug-info`, app bundle (per-ABI splits). Farmer app under 20 MB
  download: watch font and audio asset size; keep voice prompts as low-bitrate mono AAC (`.m4a`).
- Lists are `ListView.builder` over Drift queries with indexes (`farmers(village_id)`, `visits(farmer_id,
  status)`, `outbox(state, seq)`); no full-table loads into memory. Snapshot parsing in an isolate.
- Images: compress before storing; thumbnails only in lists; no network images in FA lists.
- Data: snapshot only when the ETag changed; status poll is a few bytes; gzip on; photos optionally Wi-Fi only;
  farmer app caches Home and inbox and refreshes on pull-to-refresh and app resume (not on every screen).
- Network: 20 s connect / 60 s receive timeouts (longer for the snapshot); retry idempotent GETs; never retry a
  non-idempotent farmer POST except the ones the API marks safe (call-back, read, listened).
- Big touch targets (48-56 dp), high contrast for sunlight, icon + Telugu label on every tile, one task per screen.
- Telugu-first: farmer app defaults to `te`; FA app asks at first login (default `te`) and every string exists in
  both. Golden tests render screens in Telugu at text scale 1.0 and 1.3 to catch clipping.

## Testing

- **Unit (orbit_sync, orbit_core)** against a fake API: batch ordering and the 200 cap, `retry_from` resume,
  idempotent resend after a timeout, `merged` ID rewrite across tables and queued payloads, conflict -> Keep mine
  sends the new `expected_version`, rejected parent drops dependents, projection replay after a snapshot,
  single-flight refresh under 10 parallel 401s, refresh retry inside the 60 s grace, `device_revoked` wipe,
  clock-offset correction, PIN lock-out and the 7-day grace.
- **Drift**: schema migration tests for every version (`drift_dev schema` dumps committed).
- **Widget/golden**: every screen in Telugu and English, small (360x640) and large phones, offline and empty states.
- **Integration (`integration_test`) against the dev backend**: `make dev-up && make migrate && make seed`, then
  `make run-api` and `make run-worker`. Seeded logins: FA `FA-KDP-014` (Suresh K, Kondapur + Gachibowli) and
  `FA-CVL-002`, password as printed by `make seed`; farmers `+919000000101` (Ravi K) and `+919000000102`
  (Venkatesh M), OTP `123456`. Port `tools/smoke_test.py` steps: farmer OTP + home, self sign-up + village, FA login +
  snapshot + 304, consent OTP + lookup + EnrolFarmer/SavePlot/StartSeason/LogVisit, resend = same results,
  merge of a self sign-up, call-back -> FA alert, device revoke -> 401 `device_revoked`; add consent before village,
  farmer photo upload (FA and farmer), and a forced update (set `APP_MIN_VERSION_FA` above the build in
  `backend/.env`, restart the API). Use fresh test phone
  numbers per run (SMS goes to the log sender in dev). For temp-password and PIN tests, reset an FA's password
  with `make token KIND=ho ROLE=admin` + `POST /v1/admin/field-assistants/{fa_id}/reset-password`.
- **Field tests (QA)**: airplane-mode scripts (enrol 5 farmers offline for 2 days, kill the app mid-sync, reboot
  the phone, change the phone clock), Telugu checks, sunlight readability.

## Release

- Flavours `dev`, `staging`, `prod` (different application IDs for dev/staging so they install side by side).
- CI `.github/workflows/mobile.yml`, path-filtered on `mobile/**`, `design/**`, `i18n/**` and the two tools (add
  `contracts/**` once `orbit_api` is generated): Flutter from `.fvmrc`, `flutter pub get`, `melos run check:ci`,
  then a build (today the Farmer dev debug APK; later both app bundles). Tag `fa-app/x.y.z+n` or
  `farmer-app/x.y.z+n` -> Fastlane `supply` to the Play internal track, promote to closed testing by hand.
- Signing: Play App Signing; the upload key lives in a GitHub environment secret, never in the repo.
- FA app stays on the closed testing track (FAs added by email list). Farmer app: closed testing for the 1b
  pilot, production later. Fill the data safety form; no READ_SMS; foreground-only location for FAs.
- Sentry DSN per flavour via `--dart-define`; strip PII (phone numbers, names) from breadcrumbs.

## Build order

Week 0 is Mon 9 Nov 2026. Phase 0 = wk 0-4, Phase 1a = wk 4-12 (to ~1 Feb 2027), Phase 1b = wk 12-20 (to ~29 Mar 2027).

| # | Phase | Milestone | Done when |
|---|---|---|---|
| M0 | 0 | Workspace: Melos, FVM, both app shells with flavours, `orbit_api` generated from `contracts/build/mobile.yaml` (`make backend-specs` + generator), app-config check at start, `orbit_core` dio + error mapping, tokens and l10n pipelines with a first `design/tokens/` and `i18n/te.json`/`en.json`, CI, skeleton FA app on the Play internal track. Spikes: GPS boundary walk on a Rs 8k phone, offline tiles, snapshot pull + parse of the seeded territory, Telugu TTS quality | `melos run check:ci` green in CI; the FA shell logs in to the dev backend and prints the snapshot section counts; spike notes written in `mobile/docs/spikes.md` |
| M1 | 1a | FA auth: login, temp password change + refresh, PIN set/unlock, 7-day grace, lock-out, single-flight refresh, heartbeat, wipe on `device_revoked`/`wipe: true`, forced update | Seeded FA logs in; an FA with a reset password is forced through change password and gets a clean token; PIN opens the app in airplane mode; HO revoke wipes the phone at the next call; raising `APP_MIN_VERSION_FA` blocks the old build after its outbox is pushed |
| M2 | 1a | Snapshot store: Drift schema, ETag/304, isolate parse, Farmers near me list + map, Farmer 360 (read-only), alerts list | Snapshot of the seeded territory loads in < 3 s on a 2 GB phone; second pull is a 304; an HO change (e.g. farmer edit) shows after `sync/status` changes |
| M3 | 1a | Outbox + sync engine + Sync screen: ordering, batching, backoff, `retry_from`, results, projection replay, conflict UI, WorkManager | Unit suite above passes; killing the app during a push loses or duplicates nothing; a forced conflict (HO edits a plot while the FA is offline) resolves with both buttons |
| M4 | 1a | Enrolment: lookup, consent OTP, offline fallback + RecordConsent, farmer photo, plot walk/typed, crop with season picker, plan first visit | Enrol online with proof, offline without proof, and a phone that self-signed-up (comes back `merged`); `other_fa` phone stops at lookup; offline enrol of that phone comes back `registered_with_another_fa` and drops its plot/season |
| M5 | 1a | Visit calendar, visit log with stage/issue/severity/salt, next visit, photos, AckAlert, CloseCallback | Visit logged offline shows in HO `/v1/admin/visits` and in the farmer's `/v1/farmer/visits` after sync with the right product/salt; photos confirm after the visit syncs; Wi-Fi-only works |
| M6 | 1a | Pilot hardening: Sentry, clock offset, low-end performance pass, closed testing release | **Phase 1a exit: 5 FAs log visits for 2 weeks with no lost or duplicated records** (check `/v1/admin/sync/commands` for rejects) |
| M7 | 1b | Farmer sign-in: OTP + SMS Retriever autofill (User Consent fallback), consent, village picker, complete-profile, heartbeat with forced update | New phone signs up end to end in Telugu; consent is stored before the village is picked; FA gets the new-farmer alert; retrying after a crash between steps ends with one consent row |
| M8 | 1b | Home, FA card, Look for FAs with call/WhatsApp, call-back + undo, My visits, advice detail (F8b, F8a without cashback) | Seeded farmer sees FA Suresh, next visit and visit advice; call-back reaches the FA app as an alert |
| M9 | 1b | Inbox with read/listened, audio cache, unread badge, push (if FCM is decided) | Advisory sent from HO appears; play marks listened; works from cache offline |
| M10 | 1b | My farm (profile, photo, language, plots, seasons, consents), crop calendar stage strip, offline states, Listen on every screen | All F10 actions work against dev; every screen has a voice prompt |
| M11 | 1b | FA app 1b items (call-me-back alerts, due-visit list, pilot fixes) + farmer usability round, closed testing | **Phase 1b exit: usability test with 5-10 farmers passes without help (NFR-02)** |

## Backend gaps the apps will hit

On the backend backlog (build around them, mock or hide in the UI; item numbers from
`backend/implementation-plan.md`):
- Weather (FAR-05): Home weather card shows a placeholder; hide in prod until the feed exists (item 14).
- Calendar module (F11 tasks, stage reminders by SMS): show stage strip only (item 13).
- AI help bot (FAR-14/15, F6): tile locked (item 21).
- Adapters: real push (FCM project), SMS, S3 storage (item 5). Push disabled behind a flag; photo uploads work
  against `/dev/files` locally.
- Assisted mode (FA "Help on farmer's phone"), farmer phone-number change, Phase 2 money screens (F7-F9, invoice
  check): hidden (items 16, 19, 20).
- `Idempotency-Key` on REST writes (item 10): until it exists, only auto-retry the farmer POSTs that are safe by
  design.
- Editing a visit after it syncs; advisory listened counts in the FA snapshot (Farmer 360) (item 12).
- "Call me with the OTP" voice fallback (FAR-01); server TTS, so visit-advice notices have no `audio_url`
  (NFR-01); farmer SKU detail (pack, MRP) for the F8a product card; SMS/WhatsApp preference (F10) (item 18).

## Open decisions / blockers

- FCM project, map tile provider with an offline-caching licence (and a non-GPL caching library: FMTC is GPL-3.0
  unless licensed; alternative: pre-built MBTiles per territory), helpline number, consent notice text and its
  `notice_version`, Telugu voice recordings (who records, when).
- PIN lock-out: the plan says too many wrong PINs wipe local data; the API's `pin_max_attempts` says "requires the
  password". This plan follows the API (no wipe, unsynced work kept). Confirm with the business.
- What "7 days" counts from: this plan counts from the last successful online contact (login or refresh), per
  the plan's "offline for up to 7 days". The API text says "without a password sign-in". Confirm.
- GPS accuracy gate value (10 m suggested; confirm after the Phase 0 spike).

## Definition of done (mobile/)

- `melos run check:ci` green in CI; generated client, Drift schemas, tokens and ARB files committed and up to date.
- Both apps build release bundles for all flavours; FA app on the closed testing track by the 1a pilot, farmer
  app by 1b.
- Every wireframe screen in scope for 1a/1b is built, or explicitly hidden with the gap it waits on.
- Integration suite passes against a freshly seeded dev backend; offline field scripts pass on a 2 GB phone.
- Phase exit tests met: 1a "5 FAs, 2 weeks, no lost or duplicated records"; 1b "5-10 farmers without help".
