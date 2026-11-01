# orbit_l10n

All UI strings for the Farmer and FA apps (Telugu first, English second), generated from `i18n/*.json` at
the repo root, plus the voice prompt key map that `orbit_voice` plays. Do not edit anything under
`lib/l10n/` or any `*.g.dart` by hand: change `i18n/` and run `melos run gen:l10n` from `mobile/` (see
`i18n/README.md`).

## Set up the app

```dart
import 'package:orbit_l10n/orbit_l10n.dart';

MaterialApp.router(
  locale: savedLocale ?? const Locale('te'), // farmer app: Telugu unless the farmer chose English
  localizationsDelegates: OrbitLocalizations.localizationsDelegates, // + Material, Cupertino, Widgets
  supportedLocales: OrbitLocalizations.supportedLocales,             // [te, en]
);
```

Flutter 3.47 ships Material, Cupertino and Widgets localisations for `te`, so no fallback delegate is
needed (a test checks this). Date placeholders format with `intl` date data, which
`GlobalMaterialLocalizations.delegate` loads; keep `localizationsDelegates` as above.

## Use strings

```dart
final l10n = context.l10n;                       // OrbitLocalizations.of(context)
Text(l10n.farmerLoginSendOtp);                   // farmer.login.send_otp
Text(l10n.farmerHomeGreeting(name: farmer.nameTe ?? farmer.name));
Text(l10n.farmerFasCount(count: fas.length));    // ICU plural
Text(l10n.commonDateWeekday(date: visit.plannedFor));
Text(l10n.commonCallName(name: fa.nameTe ?? fa.name));
```

Getter names are the i18n key in camelCase. Placeholders are named parameters.

## Errors

```dart
String describeError(String? code, {Map<String, Object?>? details})   // extension on OrbitLocalizations
```

`l10n.describeError(apiError.code, details: apiError.details)` returns the `error.<code>` text, or
`error.unknown` for a null or unknown code. Known `details` fields add a sentence: `attempts_left`
(`otp_invalid`) and `retry_after_seconds` (put the `Retry-After` header here for `rate_limited`).
App-side codes: `network`, `timeout`, `unknown`. Never show the API's English `message`.
`knownErrorCodes` lists every code with a key.

## Enum labels

```dart
String? enumLabel(String schema, String value)   // null when there is no label
String labelSeverity(String value)              // one per schema; falls back to commonUnknown
```

Schemas: `severity`, `planned_slot`, `visit_status`, `advice_status`, `consent_purpose`, `consent_state`
(app-side: `granted`, `withdrawn`, `never_asked` for `granted == null`), `consent_method`, `season_status`
(also the close-season outcome), `season_kind` (first part of a season code), `coverage_level`,
`farmer_plan`, `farmer_status`, `area_source`, `area_unit`, `notice_sender`, `callback_status`,
`language`. `enumSchemas` lists every value.

## Voice prompts

```dart
VoiceKeys.farmerHomeVoiceHelp        // 'farmer.home.voice_help'
voiceAsset(VoiceKeys.farmerHomeVoiceHelp) // 'packages/orbit_voice/assets/voice/te/...m4a' or null if not recorded
isVoiceKey(key)
```

The audio files are assets of `orbit_voice`; this package only knows their paths. Dependency direction:
`orbit_voice -> orbit_l10n`, never the reverse.

## Tests

`flutter test`: every key resolves in te and en with sample arguments, plurals and placeholders format,
the error mapper falls back, every enum value has a label, Material/Cupertino are Telugu for `te`.
