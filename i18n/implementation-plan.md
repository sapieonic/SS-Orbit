# i18n/ implementation plan

## Purpose
`i18n/` is the single source for every UI string the apps show (Telugu and English) and for the recorded Telugu
voice prompts. SMS and other server-sent texts are not UI strings: every SMS wording is in
`backend/internal/platform/sms/templates.go` with its DLT ID (section "SMS templates"). Telugu is the default
everywhere a farmer sees text (FAR-02, NFR-01).

## Read first
- Requirements FAR-01..03, FAR-12, NFR-01, NFR-03, INT-01: `docs/source/requirements.txt`.
- Wireframe text with the Telugu copy: `docs/source/farmer-wireframes.txt`, `docs/source/fa-admin-wireframes.txt`.
- Server texts today: `backend/internal/platform/sms/templates.go` (every SMS wording, both languages, DLT IDs),
  `backend/internal/messaging/templates.go` (notice and push texts, FA alert texts; fills the SMS variables),
  `backend/internal/messaging/quiet.go` (quiet hours). Identity renders the OTP and consent SMS from the same
  `sms` package.
- Build plan, "Repositories and shared code" and "Messaging and compliance":
  https://claude.ai/artifact/M85KFgHynuZ4gWBqz87pSa
- Sibling plans: `../mobile/implementation-plan.md` (orbit_l10n, orbit_voice), `../web/implementation-plan.md`
  (packages/i18n), `../backend/implementation-plan.md` (adapters, templates), `../design/implementation-plan.md`.

## Current state
- `i18n/` holds only `voice/te/.gitkeep`. No string files, no generator.
- The backend already writes farmer-facing text in both languages: notices store `title_te/body_te` and
  `title_en/body_en`; SMS and push are rendered once in the farmer's `language` (`te` default, `en` when chosen).
- FA alerts (`fa_alerts`) have English `title`/`body` plus Telugu `title_te`/`body_te` (migration `00026`),
  filled for new-farmer and call-back alerts and optional on HO notes. See "FA alerts" below.
- API error bodies carry an English `message` and a stable `error.code`. Apps must translate the code, not show
  the message.

## Decisions (fixed)
- Source files: `i18n/te.json` and `i18n/en.json` (flat `key -> string`, sorted) plus `i18n/meta.json`
  (per key: `description`, `screen`, `max_len`, `voice: true|false`). Telugu is the reference language; English
  may be missing for farmer-only strings and falls back to Telugu.
- Message syntax: ICU MessageFormat (`{count, plural, one {...} other {...}}`, `{name}`), which both Flutter
  `intl` (ARB) and the web (FormatJS / `react-intl`) understand.
- Farmer-facing content that HO edits (crop, stage, issue, salt, product names; advisories) lives in the database
  with `*_te` fields, not in these files.
- SMS texts live in code (`platform/sms/templates.go`), one DLT template per wording and language, because DLT
  registers each one. They are not generated from `te.json`. Moving them to DB rows with admin endpoints is still
  backlog (below).
- The admin portal is English, with Telugu previews of farmer-facing content.

## How strings flow
```
i18n/te.json, en.json, meta.json
  └─ tools/i18n/build (make i18n)
       ├─ mobile/packages/orbit_l10n/lib/l10n/app_te.arb, app_en.arb   -> flutter gen-l10n -> AppLocalizations
       ├─ mobile/packages/orbit_l10n/lib/voice_keys.g.dart              (key -> asset path for orbit_voice)
       └─ web/packages/i18n/src/locales/te.json, en.json                (farmer-web; admin uses en + previews)
```
- ARB keys must be Dart identifiers, so the generator maps `farmer.home.call_fa` to `farmerHomeCallFa` and writes
  `@farmerHomeCallFa` with the `description` and placeholders from `meta.json`.
- Generated files are committed. CI runs `make i18n` and fails on a diff, like OpenAPI and token codegen.
- CI checks: same key set in te and en (en may be absent only where meta says `farmer_only`); placeholders match
  between languages; no empty Telugu value; `max_len` respected; every key with `voice: true` has its audio file;
  no competitor brand or chemical names in string files (a deny list kept by Agronomy).

## Key naming
- `<surface>.<screen>.<element>` in snake_case: `farmer.login.send_otp`, `farmer.home.call_fa`,
  `fa.enrol.step_plot`, `fa.sync.keep_mine`, `fa.sync.keep_ho`, `web.notice.listen`.
- Shared words: `common.*` (`common.call`, `common.save`, `common.retry`, `common.offline`).
- API errors: `error.<code>` with the exact backend code, for example `error.otp_invalid`, `error.otp_expired`,
  `error.rate_limited`, `error.password_change_required`, `error.temp_password_expired`, `error.device_revoked`,
  `error.registered_with_another_fa`, `error.not_in_your_area`, `error.version_mismatch`, and `error.unknown` as
  the fallback.
- Enum labels: `enum.<schema>.<value>` (`enum.severity.high`, `enum.visit_status.missed`,
  `enum.consent_purpose.soil_partner`), so every API enum value has a label.
- Never reuse a key for a different meaning; rename instead (voice files follow the key).

## Telugu voice prompts (`i18n/voice/te/`)
- One file per prompt key, same name as the key: `i18n/voice/te/farmer.login.enter_phone.m4a`.
- Format: AAC-LC in `.m4a`, mono, 24 kHz, about 32 kbps, loudness normalised to -16 LUFS, silence trimmed, at most
  15 s. AAC plays on every Android phone and in every browser, and a 10 s prompt is about 40 KB.
- `i18n/voice/te/manifest.json` records key, a hash of the Telugu text it was recorded from, duration and
  speaker. CI flags a prompt whose text changed after recording (stale audio).
- Flutter bundles the files as assets of `orbit_voice` (fixed prompts only). Farmer web pages load them from
  CloudFront. Dynamic text (advisory bodies, names) needs server-side Telugu TTS, cached; that is backend backlog
  (not built), not work for this folder.
- Who records: one native Telugu speaker from Telangana (neutral, rural-friendly register), hired by Shanmukha,
  recorded in a quiet room with a USB condenser mic. The script is the `te.json` text for `voice: true` keys,
  reviewed first by the Telugu reviewer (below). Budget: about 150 prompts for Phase 1b.

## SMS templates sent by the backend today
Source: `backend/internal/platform/sms/templates.go` (`sms.All()` lists them). 10 wordings x 2 languages = 20
templates, each with its own 19-digit DLT ID constant (`DLT<Name>Te` / `DLT<Name>En`). All IDs are placeholders
(prefix `1107000000000000`, `sms.IsPlaceholder`) until DLT registration; a test forbids two templates sharing an
ID. The registered wording must match `Text` with each `{var}` registered as `{#var#}`. Parts are for a sample
render with a 30-character title and a 40-character link; Telugu goes as Unicode SMS (70 chars for one part, 67
per part after that), English as GSM-7 (160 / 153).

| Key | Sent by | DLT IDs (te / en) | Placeholders (max) | Telugu text | Parts te / en |
|---|---|---|---|---|---|
| `login_otp` | identity, farmer sign-in | `...115` / `...116` | code, minutes (`OTP_TTL`, 5) | `{code} మీ Orbit Shifting లాగిన్ కోడ్. {minutes} నిమిషాలు చెల్లుతుంది. ఎవరితోనూ పంచుకోవద్దు.` | 2 / 1 |
| `login_otp_retriever` | same, when `OTP_SMS_APP_HASH` is set (Android SMS Retriever) | `...117` / `...118` | code, app_hash (11 chars, last line); en also minutes | `<#> {code} మీ Orbit లాగిన్ కోడ్. ఎవరికీ చెప్పవద్దు.\n{app_hash}` | 1 / 1 |
| `consent_otp` (FAR-04) | identity, FA enrolment | `...119` / `...120` | code, minutes | `{code} మీ Orbit Shifting అంగీకార కోడ్. ... ఫీల్డ్ అసిస్టెంట్‌కు చెప్పండి. {minutes} నిమిషాలు చెల్లుతుంది.` | 3 / 2 |
| `advisory_service` | messaging, advisory SMS | `...101` / `...102` | title (30), link | `{title}. పూర్తి సలహా వినండి / చదవండి: {link}` | 2 / 1 |
| `advisory_promo` (names a product) | same | `...103` / `...104` | title (30), link | `{title}. ఉత్పత్తి సలహా వినండి / చదవండి: {link}` | 2 / 1 |
| `notice_link` (WhatsApp stub sent as SMS) | messaging, WhatsApp channel | `...105` / `...106` | title, body (600), link | `{title}\n{body}\nవినండి / చదవండి: {link}` | long |
| `welcome` | messaging, on registration | `...107` / `...108` | name (30, may be empty) | `నమస్కారం {name}, ఆర్బిట్‌లో మీ నమోదు పూర్తయింది. పంట సలహాలు యాప్‌లో, SMS ద్వారా అందుతాయి.` | 2 / 1 |
| `fa_assigned` (hand-over) | messaging | `...109` / `...110` | fa_name (30), fa_phone | `మీ కొత్త ఫీల్డ్ అసిస్టెంట్ {fa_name}. ఫోన్: {fa_phone}` | 1 / 1 |
| `visit_issues` | messaging, after a logged visit | `...111` / `...112` | date, count, link | `{date} న మీ పొలం సందర్శనలో {count} సమస్యలు గుర్తించాం. సలహా చూడండి: {link}` | 2 / 1 |
| `visit_no_issues` | same | `...113` / `...114` | date | `{date} న మీ పొలం సందర్శించాం. ఎలాంటి సమస్యలు కనిపించలేదు.` | 1 / 1 |

DLT ID column shows the last 3 digits after the placeholder prefix. `{link}` is filled at send time with a signed
link `<FARMER_WEB_BASE_URL>/web/notices/{notice_id}?t=...` (`WEB_LINK_TTL`, 7 days); the page calls
`GET /v1/web/notices/{notice_id}`. Advisory SMS no longer carries the body: HO writes a title that reads well in
30 characters, and the full text and voice note are on the web page. Quiet hours 21:00-07:00 IST apply to
advisory and notice SMS; OTPs go out at any time.

Still open
- Replace every placeholder ID with the real DLT ID before launch (needs the DLT entity and header).
- Links inside SMS must use a whitelisted domain (short-link domain is an open decision).
- The sender header (6 letters) and the CIV label in sender text are open decisions.

## Plan: DB-managed templates (backend backlog, not started)
The wordings and per-language DLT IDs are fixed in code now, which is enough for launch. Moving them to the
database is backlog ("admin endpoints to manage message templates"):
1. New table `message_templates` (owned by messaging): `key`, `channel` (sms, whatsapp, push), `language`,
   `class` (service, promotional), `dlt_template_id`, `dlt_header`, `body` with named variables, `variables`
   (name, max length), `status` (draft, active, retired), `version`, `approved_by`, timestamps. Identity reads
   OTP and consent templates through a port.
2. Seed the rows from `sms.All()`; keep the "no shared ID" test as a DB check. In prod the API refuses to start if
   a template key the code uses has no active row.
3. Admin screen under H9 Messages (web): list, view, edit draft, activate. Activation needs Ops and records the
   DLT ID. Endpoints do not exist yet.
4. Done when changing a wording needs no deploy and every SMS sent carries a real DLT ID.

## FA alerts in Telugu
- `fa_alerts.title_te` / `body_te` (migration `00026`) are filled for `new_farmer` and `callback` alerts (texts in
  `messaging/templates.go`, `faAlertNewFarmerText`, `faAlertCallbackText`). HO notes take optional `title_te` /
  `body_te` in `POST /v1/admin/fa-alerts`; older alerts and English-only notes have them null.
- The snapshot and `GET /v1/fa/alerts` carry both languages. The FA app shows Telugu when the FA's UI language is
  Telugu and `title_te` is set, else the English `title`/`body`.
- Push goes in the FA's first language: the first `te` or `en` in the FA's `languages` (Telugu if neither), and
  English when the alert has no Telugu text. FAs have no separate UI-language field; the app keeps the UI choice
  locally.

## Notice and SMS length rules
- Push body is cut to 180 runes, WhatsApp body to 600 (`messaging/templates.go`); SMS variables are cut to their
  template `Max` (advisory title 30, names 30). A cut ends with `…`. The H3 composer shows the SMS preview with
  the title as it will be cut, per language.
- Telugu SMS costs more per message (Unicode parts). Each part counts; keep templates to 2 parts where possible.
- Never put a competitor brand, and never a chemical or dose in free-text AI bot replies (Phase 3 guardrail).

## Review process with a Telugu speaker
- Named reviewer: a native Telugu speaker from the field team (an experienced FA or agronomist), plus Shanmukha's
  marketing for tone. They review every pull request that changes `te.json` or a template (CODEOWNERS on
  `i18n/`).
- Checklist: plain spoken Telugu a low-literacy farmer understands; same meaning as English; no English jargon
  unless farmers use it (SMS, OTP, UPI stay in Latin); numbers and dates readable; fits the button at 360 dp.
- Golden screenshots in Telugu are attached to the pull request so the reviewer checks text in place.
- Before each phase exit, read every new voice prompt aloud with 2-3 farmers in the pilot mandal.

## Build order
1. **Phase 0 (wk 0-4):** create `te.json`, `en.json`, `meta.json` with the login, consent, common and error
   keys; write `tools/i18n/build` and `make i18n`; CI checks. Done when the Flutter skeleton app and a web page
   show Telugu from generated files and CI fails on a missing key.
2. **Phase 1a (wk 4-12):** all FA app strings (Telugu UI optional per FA) and enum labels; real DLT IDs swapped
   into `platform/sms/templates.go` (backend); FA alerts shown from `title_te`/`body_te`. Done when the pilot SMS
   (enrolment, consent, advice) go out under registered DLT templates and the FA app has no hard-coded text.
3. **Phase 1b (wk 12-20):** all farmer app and farmer web strings; record and ship ~150 Telugu prompts. Done
   when every farmer screen has Telugu text and a working Listen button (NFR-01) and the reviewer has signed off.
4. **Phase 2:** wallet, payment, KYC, services strings; payment and payout SMS templates (DLT, service class).
5. **Phase 3:** AI bot prompts and canned replies, schemes and soil report strings.

## Backend backlog that touches i18n
- No endpoints to list or edit message templates (H9); wordings change by deploy until then.
- Placeholder DLT IDs must be replaced with real ones before launch.
- No server TTS: dynamic text (advisory bodies, visit advice) has no audio unless HO uploads a voice note.

## Open decisions
- SMS provider, DLT entity and sender header; CIV full name and label; short-link domain; WhatsApp BSP.
- Voice artist and recording budget; whether the FA app offers a Telugu UI at launch.

## Definition of done
- Every UI string in `mobile/` and `web/` comes from generated i18n files; CI blocks missing keys and placeholders.
- Every farmer screen has Telugu text and voice; every SMS template has a real DLT ID (no `sms.IsPlaceholder`).
- The Telugu reviewer has signed off the strings and prompts for the phase.
