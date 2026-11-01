# Orbit mobile

Flutter workspace for the Orbit Shifting apps: the **Farmer app** (`apps/farmer`, built) and the **FA app**
(`apps/fa`, not started), with shared packages. The plan is in [implementation-plan.md](implementation-plan.md).

## Layout

| Path | What it is |
|---|---|
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

## Release signing (Android)

Release builds read the upload key from `apps/farmer/android/key.properties`. It is gitignored, as are
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

From the repo root: `make tokens`, `make i18n`, `make mobile-check`, `make farmer-run`.

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

FA app:
- The app itself, plus the FA-only enum labels and error codes in `i18n/`.
