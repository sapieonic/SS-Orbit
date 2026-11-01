/// Orbit UI strings for the Farmer and FA apps: Telugu first, then English.
///
/// Everything here is generated from `i18n/te.json`, `en.json` and
/// `meta.json` at the repo root (run `melos run gen:l10n` from `mobile/`).
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: OrbitLocalizations.localizationsDelegates,
///   supportedLocales: OrbitLocalizations.supportedLocales, // te, en
/// );
///
/// Text(context.l10n.farmerLoginSendOtp);
/// Text(context.l10n.describeError(error.code, details: error.details));
/// Text(context.l10n.labelSeverity(issue.severity));
/// ```
library;

export 'l10n/generated/orbit_localizations.dart';
export 'src/context_l10n.dart';
export 'src/error_text.dart';
export 'src/lookups.g.dart' show OrbitEnumLabels, enumSchemas, knownErrorCodes;
export 'src/voice.dart';
export 'src/voice_keys.g.dart'
    show VoiceKeys, recordedVoiceKeys, voiceAssetPackage, voiceAssetPaths;
