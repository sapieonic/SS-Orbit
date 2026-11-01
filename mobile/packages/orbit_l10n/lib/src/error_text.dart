import '../l10n/generated/orbit_localizations.dart';
import 'lookups.g.dart';

/// Turns an API or app error code into text the farmer or FA can read.
extension OrbitErrorText on OrbitLocalizations {
  /// Localised text for an error [code]: the API's `error.code`
  /// (`otp_invalid`, `rate_limited`, ...) or an app-side code (`network`,
  /// `timeout`, `unknown`).
  ///
  /// Codes without an `error.<code>` key, and a null [code], give
  /// [errorUnknown]; the API's English `message` is never shown.
  ///
  /// For a known code, each entry of [details] that has an
  /// `error.detail.<field>` key adds its sentence, in field order. Today:
  /// `attempts_left` (from `otp_invalid`) and `retry_after_seconds` (put the
  /// `Retry-After` header value here for `rate_limited`). Entries without a
  /// key, or with a value of the wrong type, are ignored.
  String describeError(String? code, {Map<String, Object?>? details}) {
    final message = code == null ? null : errorMessageFor(this, code);
    if (message == null) return errorUnknown;
    if (details == null || details.isEmpty) return message;
    final fields = details.keys.toList()..sort();
    return [
      message,
      for (final field in fields) ?errorDetailFor(this, field, details[field]),
    ].join(' ');
  }
}
