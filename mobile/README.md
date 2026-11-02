# Orbit mobile

Flutter workspace for the Orbit Shifting apps: the **Farmer app** (`apps/farmer`, built) and the **FA app**
(`apps/fa`, runs on mock data), with shared packages. The plan is in [implementation-plan.md](implementation-plan.md).

## Layout

| Path | What it is |
|---|---|
| `apps/fa` | FA app. Offline first, runs on mock data ([app README](apps/fa/README.md)) |
| `apps/farmer` | Farmer app. Telugu first. Runs on mock data today ([data layer README](apps/farmer/lib/src/data/README.md)) |
| `packages/orbit_core` | Pure Dart: `ApiError`, `OrbitEnv`, money/date/phone/area helpers, `Clock`. No Flutter, so it works in isolates and tools |
| `packages/orbit_ui` | Design system: generated tokens, `OrbitTheme.farmer()` / `.fa()`, bundled fonts, components, `OrbitIcons` |
| `packages/orbit_l10n` | `OrbitLocalizations` (te, en) generated from `../i18n/*.json`, error and enum label helpers, voice key map |
| `packages/orbit_voice` | `VoicePlayer` for Listen buttons: bundled Telugu prompts and cached notice audio |

Layering (enforced by review, packages never import apps):

```
apps/farmer ──► orbit_ui ─┐
     │      ──► orbit_voice ──► orbit_l10n
     │      ──► orbit_l10n
     └──────► orbit_core
```

`orbit_ui` takes already-localised strings and plain values, so the FA app reuses every component with its own
theme. Nothing in the packages is Android-only; the same code builds for iOS.

## Setup

```bash
# Flutter version is pinned in .fvmrc (use FVM, or a matching SDK on PATH)
dart pub global activate melos 8.10.0   # same version as pubspec.lock
cd mobile && flutter pub get
```

## Run the Farmer app

```bash
cd mobile/apps/farmer
flutter run --flavor dev                                            # mock data (default in dev)
flutter run --flavor dev --dart-define=ORBIT_MOCK_SCENARIO=offline  # start in a scenario
```

Mock logins: Ravi `9000000101`, Venkatesh `9000000102`; any other number signs up. OTP `123456`. The dev menu
(scenarios: no FA, no visits, account paused, offline, slow, server error, session revoked; reset data) opens
from the login screen in dev builds. A revoked or reset session sends the app back to phone entry.

Flavours `dev`, `staging`, `prod` have their own application IDs (Android). Staging and prod refuse mock data.
iOS schemes per flavour still need Xcode on a Mac (see "Not done yet"). All three flavours use the default
Flutter launcher icon; replace it (per flavour if we want them told apart) before any Play upload.

## Run the FA app

```bash
cd mobile/apps/fa
flutter run --flavor dev    # mock data (default in dev)
```

Mock logins: Suresh Kumar `FA-KDP-014` / `orbit2026`; `FA-KDP-099` / `temp1234` has a temporary password
that must be changed; `FA-KDP-077` / `temp5678` has an expired temporary password. Consent OTP `123456`.
The dev menu (mock scenarios, HO actions, reset) opens from the sign-in screens and Me in dev builds; see the
[FA app README](apps/fa/README.md).
Flavours and the launcher icon work as in the Farmer app (app names "Orbit FA Dev", "Orbit FA Staging",
"Orbit FA").

## Release signing (Android)

Release builds read the upload key from `android/key.properties` in each app:
`apps/farmer/android/key.properties` and `apps/fa/android/key.properties`. They are gitignored, as are
`*.jks` and `*.keystore`; never commit them.

```properties
# storeFile is an absolute path, or relative to android/app
storeFile=/home/you/keys/orbit-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without the file, `dev` release builds are signed with the debug key (so `flutter run --release` works), and
`staging` / `prod` release builds (APK or app bundle) stop with an error pointing here. If the file is there
but a field is missing, every release build stops. Debug builds never need it, so CI is not affected.

## Generated code (committed, CI checks freshness)

```bash
melos run gen:tokens   # design/tokens/*.json -> orbit_ui/lib/src/tokens/orbit_tokens.g.dart
melos run gen:l10n     # i18n/*.json -> orbit_l10n ARB -> OrbitLocalizations, voice keys
melos run check        # local: regenerate, analyze (fatal infos), all tests; uncommitted work is fine
melos run check:ci     # CI: dart format, generated files fresh and committed, analyze, all tests
```

`check:ci` fails on any uncommitted change under `mobile/`, `i18n/` or `design/`, so run it on a clean tree.
When it says generated files are stale, run `melos run gen` and commit the result. `melos run format:check`
runs only the format step (mobile, `tools/tokens`, `tools/i18n`).

From the repo root: `make tokens`, `make i18n`, `make mobile-check`, `make farmer-run`, `make fa-run`.

`apps/farmer/dart_test.yaml` skips tests tagged `dev-backend` by default. That tag is for the repository
contract suite run against a running dev backend, which comes with the `Api*Repository` classes (step 5 in the
[data layer README](apps/farmer/lib/src/data/README.md)); no test carries it yet. Once it exists, run it with
`flutter test --run-skipped --tags dev-backend`.

## Swapping mock data for the real API

Screens only see repository interfaces through Riverpod providers. All mock data and behaviour is in one file,
`apps/farmer/lib/src/data/mock/mock_backend.dart`. To go live: generate `orbit_api` from
`contracts/build/mobile.yaml`, write the `Api*Repository` classes, and run with `--dart-define=ORBIT_DATA_SOURCE=api`.
The repository contract tests (`apps/farmer/test/data/repository_contract.dart`) then run against both. Steps:
[data layer README](apps/farmer/lib/src/data/README.md).

## Not done yet

Data and platform:
- `orbit_api` (generated client) and the `Api*Repository` classes.
- No offline cache or outbox: data lives in memory only, and requests made offline are not queued.
- Session store is in memory (no `flutter_secure_storage` yet), so a restart signs the farmer out.
- Heartbeat and app config are not wired: no forced update, device wipe or server time.
- SMS autofill (`smart_auth`), photo upload (`image_picker`), GPS (`geolocator`; plot pins use the village
  centre until then), push (FCM decision).

Screens and features:
- Home tiles for Weather, Wallet and Advisory, and the F7-F9 money screens (Phase 2).
- Calendar tasks and SMS reminders.
- Messages and KYC rows in My farm.
- Per-notice WhatsApp share and the full-screen "show at shop" view.

Content and release:
- Telugu voice recordings (`i18n/voice/te/`): Listen buttons show "audio coming" until they exist.
- Telugu review of strings marked `"review": "pending"` in `i18n/meta.json`.
- Launcher icons per flavour (all use the Flutter default today).
- iOS flavour schemes and signing (needs a Mac); Play upload (Fastlane).

FA app (`apps/fa`, built on mock data; see its [README](apps/fa/README.md)):
- `Api*Repository` classes over `orbit_api` (steps in the [FA data layer README](apps/fa/lib/src/data/README.md)).
- Drift store with SQLCipher behind `LocalStore` (in memory today, so a restart loses the territory and the
  outbox), and `flutter_secure_storage` behind `SessionStore` (in memory, so a restart signs the FA out). See
  the [offline engine README](apps/fa/lib/src/local/README.md), "Later: Drift and orbit_sync".
- WorkManager background sync; sync runs only while the app is open.
- `connectivity_plus`, `geolocator` and `image_picker` behind `ConnectivityService`, `LocationService` and
  `PhotoCapture`. Only the mocks exist; on the API their providers throw `UnimplementedError` naming the
  plugin, so real data never gets scripted GPS or generated photos. The iOS usage strings for camera and
  location are in `Info.plist` already. Offline map tiles (the farmers map needs network for its tiles).
- Consent audio recording (orbit_voice); biometric unlock.
- Refresh token bound to the PIN (plan, "FA sign-in", step 3): keep the refresh token encrypted with a key
  derived from the PIN and a Keystore-held secret, so a copy of the secure storage alone cannot sign in.
  Today the PIN only gates the app's screens; the tokens sit in the session store as they are.
- Contract gap, missed visits: the backend's hourly `visits.mark_missed` job turns planned visits dated before
  today into `missed`, and the snapshot carries only planned visits and the 3 latest done per farmer
  (`backend/internal/visits/queries/visits.sql`, `ListPlannedVisitsForFarmers` with `status = 'planned'`). So
  a visit the FA did not make yesterday drops off the phone at the next pull: no overdue chip, no "move to
  another day", no logging it, although PlanVisit, LogVisit and CancelVisit all accept a missed visit.
  Proposed change: the `visits` section also carries `missed` visits planned in the last 14 days (that query
  with `status = 'planned' OR (status = 'missed' AND planned_for >= today - 14)`, and `SnapVisit.status`
  documented as `planned | done | missed`). The mock already does this (`MockBackend.snapshotMissedDays`).
- Backend fix to suggest: Go text limits count bytes (`len()`), so a plot label is 60 bytes, about 20 Telugu
  letters, and a name 100 bytes. Counting characters (`utf8.RuneCountInString`) would match what the app
  shows; until then the mock and the app count bytes too.
- Contract gap: `SnapAlert` has no farmer name or phone, and unassigned self sign-ups are not in the
  snapshot, so a new-farmer alert can't be acted on fully offline (backend contract question).
- Backend gap: the real backend never closes FA alerts. `backend/internal/messaging/queries/fa_alerts.sql`
  only inserts, gets, acknowledges and lists them, so `new_farmer` alerts stay open after EnrolFarmer or a
  merge, and `callback` alerts after CloseCallback or LogVisit. The mock and the app's projector close them,
  so once the API lands they would come back as open on the next pull. Needs a backend change: messaging
  closes them when a farmer is enrolled or merged and when a call-back is closed.
- No read-only view of a done visit (Farmer 360's last visit row); the farmers map ignores the filter chips
  (search only).
- Screens left out for later: invoice checks, assisted mode, wallet and KYC rows, "Plan my route".
- Telugu review of the FA strings marked `"review": "pending"`.
