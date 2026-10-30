# Orbit Shifting: implementation plan (start here)

## What Orbit is
Orbit Shifting is Shanmukha Agritec's farmer programme in Telangana. It has three interfaces on one Go backend:
a Telugu-first Farmer app (self sign-up with OTP), a Field Assistant (FA) app that works offline in villages, and a
Head Office (HO) web portal. Farmers get crop advice (salt first, then a Shanmukha product if one exists, never a
competitor brand), FA visits, call-backs and advisories; money (Premium, cashback) comes in Phase 2.

## How to use this file
Open this file first in a new session. Pick the folder you are building, read its `implementation-plan.md`, then
the sources listed under "Read first" in that plan. Each folder plan has: purpose, current state, fixed decisions,
build order tied to the phases below, contract details, conventions, open decisions and definition of done.

## Sources
- Requirements v1.0 (58 IDs: SYS, FAR, PLN, FA, ADM, WF, INT, NFR): `docs/source/originals/Orbit shift app
  Requirements.docx`; plain-text copy `docs/source/requirements.txt`.
- Wireframes (19 farmer, 16 FA, 18 admin screens): text copies `docs/source/farmer-wireframes.txt` and
  `docs/source/fa-admin-wireframes.txt`. The original HTML files (`Orbit Shifting · Farmer App.html`,
  `... · Field Assistant App.html`, `... · Admin Dashboard.html`) are kept outside the repo (the product team shares them; never commit them).
- Build plan (architecture, stack, sync design, roles, roadmap, team): https://claude.ai/artifact/M85KFgHynuZ4gWBqz87pSa
  (local copy `docs/build-plan.html`).
- Working client flow against the real API (Python): `tools/smoke_test.py` (usage in its docstring; dev only).
- Everything except the wireframe HTML files is in the repo under `docs/`. Treat `docs/source/` as read-only inputs.

## Repo map
| Folder | What it holds | Plan |
|---|---|---|
| `backend/` | Go 1.27 modular monolith (api + worker), sqlc, goose migrations, River jobs, seed | [backend/implementation-plan.md](backend/implementation-plan.md), plus `backend/docs/CONVENTIONS.md` |
| `mobile/` | Flutter Melos workspace: `apps/farmer`, `apps/fa`, shared `packages/` (orbit_api, orbit_ui, orbit_l10n, orbit_core, orbit_media, orbit_voice, orbit_maps) | [mobile/implementation-plan.md](mobile/implementation-plan.md) |
| `web/` | pnpm workspace: `apps/ho-portal` (HO portal, React 19 + Vite), `apps/farmer-web` (pages opened from SMS links), `packages/` (api-client, ui, i18n) | [web/implementation-plan.md](web/implementation-plan.md) |
| `infra/` | Terraform for AWS India: `modules/`, `envs/dev`, `envs/staging`, `envs/prod` | [infra/implementation-plan.md](infra/implementation-plan.md) |
| `contracts/` | OpenAPI 3.0.3, one spec per backend module (`openapi/*.yaml`), generated `ENDPOINTS.md` (138 operations), client bundles `build/mobile.yaml` and `build/web.yaml` | [contracts/implementation-plan.md](contracts/implementation-plan.md) |
| `design/` | Design tokens, fonts, icons, illustrations, component specs (single source for Dart and CSS) | [design/implementation-plan.md](design/implementation-plan.md) |
| `i18n/` | UI strings `te.json` / `en.json`, Telugu voice prompts `voice/te/`; SMS template plan | [i18n/implementation-plan.md](i18n/implementation-plan.md) |
| `tools/` | Repo scripts: `list-endpoints.py`, `bundle-specs.py`, `smoke_test.py`; later generators for tokens and strings, fake partners | [tools/implementation-plan.md](tools/implementation-plan.md) |
| `dev/` | `docker-compose.yml` (Postgres 17 + PostGIS, Redis) and init scripts for local dev and tests | [dev/implementation-plan.md](dev/implementation-plan.md) |
| `.github/` | CI; today `workflows/backend.yml` (path-filtered) | covered in infra and tools plans |
| root | `Makefile` (`make dev-up`, `make migrate`, `make backend-<target>`, e.g. `make backend-specs`, `make backend-image`), this file, `INTEGRATION-TEST-LOG.md` | |

Acceptance: [INTEGRATION-TEST-LOG.md](INTEGRATION-TEST-LOG.md) lists the end-to-end journeys to run on staging
once backend, both apps, the portal and infra are built. Every journey cites requirement IDs, and its last table
maps all 58 IDs to journeys.

## Current status (30 Oct 2026)
- **Backend: built.** 8 modules (identity, geo, farmers, masters, visits, messaging, sync, audit), 138 API
  operations, migrations `00001`-`00021` and `00026` (next new one is `00027`), seed data (`make seed`; HO users
  include `agronomy2@orbit.dev` for maker-checker), CI workflow, container image (`backend/Dockerfile`,
  `make backend-image`), worker health on `:8081`. `make check` passes and `tools/smoke_test.py` passes end to
  end. Remaining backend backlog is in `backend/implementation-plan.md`.
- **Contracts: built.** Specs per module; `make backend-specs` regenerates `ENDPOINTS.md` and the client bundles
  `contracts/build/mobile.yaml` and `web.yaml` (`tools/bundle-specs.py`).
- **Mobile, web, infra: not started** (empty folders). **design/, i18n/: plans only.**
- Quick start: `make dev-up && make migrate && make backend-seed && make backend-run-api` (see
  `backend/README.md`; run the worker too with `make backend-run-worker`), then `python3 tools/smoke_test.py`.

Plan vs repo differences: Go 1.27 (plan said 1.25); OpenAPI 3.0.3 (plan said 3.1); specs per module, not per
surface; generated server code is `backend/internal/<module>/api.gen.go`; Makefile, not Taskfile.

## Phase roadmap and which folder delivers what
Week 0 is Monday 9 Nov 2026. Dates are re-baselined at the end of Phase 0.

| Phase | Window | Folder milestones | Exit test |
|---|---|---|---|
| 0 Discovery | wk 0-4 (to ~7 Dec 2026) | infra: AWS accounts, dev + staging, OIDC, Terraform modules; design: tokens, fonts, icons; i18n: string pipeline, login/consent strings; mobile: Melos skeleton, orbit_api from specs, spikes (GPS boundary on a ₹8k phone, offline tiles, snapshot sync); web: HO portal skeleton, api-client from `contracts/build/web.yaml`; tools: generators; contracts: bundle freshness and oasdiff checks in CI | All Phase 0 gates signed off; vendor sandboxes work |
| 1a FA pilot | wk 4-12 (pilot ~1 Feb 2027) | backend: adapters (real SMS with DLT, push, S3), real DLT IDs in the SMS templates, CSV import, territory hand-over in one call; mobile: FA app (login + PIN, near me, enrol + consent OTP, visit log, calendar, alerts, sync); web: H1 overview, H2 FAs/villages/HO users, H5 masters, H7 farmers + detail, H8 audit; infra: staging + prod, backups, alarms | 5 FAs in one mandal log visits for 2 weeks with no lost or duplicated records |
| 1b Farmer app | wk 12-20 (~29 Mar 2027) | backend: calendar module (stage reminders), weather adapter (FAR-05), push + delivery tracking; mobile: farmer app (OTP, consent, village, home, Look for FAs, My visits, My Crop Advisory, calendar, My farm, Listen everywhere, offline states); web: H3 send advisory, H9 messages, farmer-web notice page; i18n: ~150 Telugu prompts | Usability test with 5-10 farmers passes without help (NFR-02) |
| 2 Money | wk 20-30 (by ~7 Jun 2027, Kharif) | backend: plans + Razorpay (one order per season), ledger, invoices, ID check, payouts, services, WhatsApp; mobile: plan/payment, services, send a bill, wallet, ID check, UPI, assisted mode, FA invoice check; web: H4 invoices/services/KYC/payouts, H10 mobile approvals, product card and receipt pages | Penny test end to end in production; reconciliation matches the bank |
| 3 Growth | wk 30-38 (~2 Aug 2027) | backend: soil lab, schemes, loyalty adapters, AI help bot, funnel rollups; mobile: AI bot (voice + photo, hands off to FA), schemes, soil report, bookings; web: H6 analytics, editable roles grid | Funnel and KPIs refresh daily (ADM-09) |

Critical path: data model, auth and devices, FA sync, enrol and visit log, pilot. Protect Phase 2: it is tied to
Kharif sowing.

## Cross-cutting rules
- **Contract first.** Change `contracts/openapi/<module>.yaml`, regenerate (Go server, Dart client, TS client),
  then write code. Generated code is committed and CI fails if it is stale. No breaking changes to `/v1/farmer`
  or `/v1/fa` (old app versions stay on phones for months); add fields or go to `/v2`.
- **No secrets in the repo.** Dev uses `.env` (from `.env.example`) and the log SMS/push providers. Staging and
  prod read secrets from AWS Secrets Manager; deploys use GitHub OIDC; prod applies need environment approvals.
  No real phone numbers beyond the dev seed ones.
- **Telugu first.** Every farmer screen is Telugu by default with a Listen button (FAR-02, FAR-03, NFR-01). Strings
  come from `i18n/`; colours and sizes from `design/`. API errors are shown by `error.code`, never the English
  `message`.
- **Offline-first FA app.** Snapshot down (`GET /v1/fa/sync/snapshot`, ETag, 304 when unchanged), commands up
  (`POST /v1/fa/sync/commands`, batch up to 200, client-minted UUIDv7, idempotent; results applied, merged,
  conflict, rejected). Conflicts show "Keep mine / Keep HO's". Max 7 days offline, then a full login.
- **Every record is farmer + plot + season** (SYS-03); every change is audited with actor, time and device (WF-01).
- **No competitor brands anywhere.** Advice points to a Shanmukha SKU or "salt only"; there is no free-text
  product field. The AI bot must never name a chemical, dose or brand.
- **Consent before data sharing** (FAR-04, INT-01, NFR-06). FA enrolment needs a consent OTP proof or the farmer
  stays `consent_pending`; no partner adapter sends farmer data without a stored consent for that purpose.
- **Maker-checker.** Agronomy approves advice rules and product-naming advisories, never their own. Phase 2
  adds a second approver above ₹5,000 and separation of duties for payouts.
- **Quiet hours** 21:00-07:00 IST for farmer SMS and push (OTP and payment messages excepted).
- **Redis is a cache only.** Redis down means slower, never broken. Jobs and data stay in Postgres.

## Open business decisions (owners and the phase they block)
| Decision | Owner | Blocks |
|---|---|---|
| AWS region: Hyderabad (ap-south-2) or Mumbai (ap-south-1) | Tech, Business | Phase 0 (infra) |
| FA login model (FA-02): per-person logins plus territory hand-over (wireframes, recommended) vs shared login (requirements) | Business, Ops | Phase 0 sign-off (backend built per-person) |
| SMS provider, DLT entity, sender header and template IDs | Tech, procurement | Phase 1a (start DLT in week 1) |
| Short-link domain for SMS links (must be whitelisted in DLT) | Tech | Phase 1a |
| FCM project for push | Tech | Phase 1a |
| S3 bucket and region for photos and voice notes | Tech | Phase 1a |
| Map tile provider whose licence allows offline caching | Tech | Phase 1a |
| Salt-to-product master content and approver | Agronomy | Phase 1a |
| CIV full name and farmer-facing label | Business | Phase 1b |
| Weather feed (FAR-05) | Tech, procurement | Phase 1b |
| WhatsApp BSP | Tech, procurement | Phase 2 |
| Premium price, contents, validity | Business | Phase 2 |
| Cashback rules, MRP cap (an agent assumed ₹1,00,000 per pack; confirm), TDS 194R and GST | Finance, compliance | Phase 2 gate |
| Payout partner and ID-check method (no Aadhaar) | Finance, Tech | Phase 2 |
| Invoice verification: upload vs dealer feed | Operations | Phase 2 |
| AI bot scope, languages, data sources | Product | Phase 3 |

## If you are starting now
1. Close or chase the Phase 0 decisions above (region, FA-02 sign-off, SMS/DLT registration in week 1).
2. Infra: dev and staging environments, so the backend runs somewhere other than a laptop.
3. Mobile: Melos skeleton plus `orbit_api` generated from `contracts/build/mobile.yaml`, then the FA app sync
   spike against the running backend (use `tools/smoke_test.py` as the reference flow). Web: `api-client` from
   `contracts/build/web.yaml`.
4. Design and i18n pipelines (`make tokens`, `make i18n`) before the first real screen, so no app hard-codes
   colours or text.

## Definition of done for the whole programme
- Every requirement ID is covered by a passing journey in `INTEGRATION-TEST-LOG.md` (or marked deferred with a
  reason and owner).
- Each folder meets its own plan's definition of done, and CI is green for every path-filtered workflow.
