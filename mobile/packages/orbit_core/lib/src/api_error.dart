import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Stable error codes the Orbit backend sends in `{error: {code}}`, the
/// reasons it gives for rejected FA sync commands, plus [network] and
/// [timeout] for failures that never reached the server.
///
/// orbit_l10n's `describeError` has text for every code a farmer or FA can
/// meet; the rest (HO portal codes, [methodNotAllowed], [conflict],
/// [serverCouldNotApply]) fall back to its generic "something went wrong".
///
/// The list is not closed: the server may add codes, so always keep a
/// default branch when switching on [ApiError.code].
abstract final class ApiErrorCode {
  // Standard codes (backend/docs/CONVENTIONS.md section 4).

  /// 401: missing, invalid or expired token (`details.reason = "expired"`).
  static const unauthorized = 'unauthorized';

  /// 403: wrong token kind or not allowed.
  static const forbidden = 'forbidden';

  /// 404.
  static const notFound = 'not_found';

  /// 400 with `details.fields: {name: reason}`.
  static const validationFailed = 'validation_failed';

  /// 400: the request could not be parsed.
  static const invalidRequest = 'invalid_request';

  /// 400: a paging cursor the server does not accept.
  static const invalidCursor = 'invalid_cursor';

  /// 405.
  static const methodNotAllowed = 'method_not_allowed';

  /// 413: request body too large.
  static const payloadTooLarge = 'payload_too_large';

  /// 429: see [ApiError.retryAfter].
  static const rateLimited = 'rate_limited';

  /// 503: try again with backoff.
  static const unavailable = 'unavailable';

  /// 500: server bug, no details.
  static const internal = 'internal';

  /// 409 without a more specific code (a duplicate or a wrong status).
  static const conflict = 'conflict';

  // Auth and session.

  /// 401 on any call: wipe local data and use a new install ID.
  static const deviceRevoked = 'device_revoked';

  /// 401 on refresh: the refresh token was reused; sign in again.
  static const refreshReused = 'refresh_reused';

  /// 401: HO session revoked (HO portal only).
  static const sessionRevoked = 'session_revoked';

  /// 401: FA temporary password expired (FA app).
  static const tempPasswordExpired = 'temp_password_expired';

  /// 403: FA must change the temporary password first (FA app).
  static const passwordChangeRequired = 'password_change_required';

  /// 400 on OTP verify: wrong code, see [ApiError.attemptsLeft].
  static const otpInvalid = 'otp_invalid';

  /// 400 on OTP verify: no live code (expired, used or too many tries).
  static const otpExpired = 'otp_expired';

  /// 401 on HO login: TOTP is not set up yet (HO portal only).
  static const totpEnrolmentRequired = 'totp_enrolment_required';

  /// 409 on HO TOTP start: TOTP is already set up (HO portal only).
  static const totpAlreadyEnabled = 'totp_already_enabled';

  // Farmer app conflicts (409).

  /// 409 on `POST /v1/farmer/callbacks`: the farmer has no FA yet.
  static const noFaAssigned = 'no_fa_assigned';

  /// 409 on call-back cancel: the FA already closed it.
  static const callbackClosed = 'callback_closed';

  /// 409 on season start: the plot already has an active season.
  static const activeSeasonExists = 'active_season_exists';

  /// 409 on season start: this plot already had a season with that code.
  static const seasonExists = 'season_exists';

  /// 409 on season close: the season is not active.
  static const seasonNotActive = 'season_not_active';

  /// 409 on complete-profile: already complete (carry on).
  static const profileAlreadyComplete = 'profile_already_complete';

  /// 409 on farmer writes while still `pending_profile`.
  static const profileIncomplete = 'profile_incomplete';

  /// 409 on versioned writes.
  static const versionMismatch = 'version_mismatch';

  /// 409 on an HO farmer edit: the new phone number belongs to another
  /// farmer.
  static const phoneTaken = 'phone_taken';

  // Photo uploads (FA app, 409).

  /// 409 on visit photo upload-url: this photo is already uploaded.
  static const photoAlreadyUploaded = 'photo_already_uploaded';

  /// 409 on visit photo confirm: the object never reached storage; upload
  /// it again.
  static const uploadMissing = 'upload_missing';

  // FA sync: reasons in a rejected command result's `error`
  // (`POST /v1/fa/sync/commands`), not in an error response.

  /// EnrolFarmer: the phone belongs to another FA's farmer.
  static const registeredWithAnotherFa = 'registered_with_another_fa';

  /// The farmer's village is outside the FA's area.
  static const notInYourArea = 'not_in_your_area';

  /// The server failed to apply the command several times and dropped it.
  static const serverCouldNotApply = 'server_could_not_apply';

  // Client-side.

  /// No HTTP response at all: offline, DNS failure or connection reset.
  static const network = 'network';

  /// No HTTP response in time: the network is there but too slow. Treated
  /// like [network] by [ApiError.isNetwork].
  static const timeout = 'timeout';
}

/// An error from the Orbit API, or a network failure before any response.
///
/// Mirrors the backend envelope `{ "error": { "code", "message", "details" } }`
/// plus the HTTP [status] and the `Retry-After` header. Every repository, mock
/// or real, throws only this type for expected failures, so screens can switch
/// on [code] without caring where the data came from.
///
/// Show your own Telugu/English text per [code]; [message] is the server's
/// English text, kept as a fallback and for logs.
@immutable
final class ApiError implements Exception {
  /// Creates an error from the parts of an API error response.
  const ApiError({
    required this.code,
    required this.message,
    this.status,
    this.details = const {},
    this.retryAfter,
  });

  /// A request that got no HTTP response (offline, connection error, timeout).
  ///
  /// [status] is null. [code] is [ApiErrorCode.timeout] when [timeout] is
  /// set, so the farmer reads "the network is slow" rather than "no
  /// internet", else [ApiErrorCode.network]. Both are [isNetwork]: screens
  /// show the offline state and keep cached data either way.
  const ApiError.network({
    String message = 'network unavailable',
    bool timeout = false,
  }) : this(
         code: timeout ? ApiErrorCode.timeout : ApiErrorCode.network,
         message: message,
       );

  /// Builds an error from a decoded error response body.
  ///
  /// [body] is the decoded JSON (`{error: {code, message, details}}`); a body
  /// of any other shape still gives a usable error, with a code derived from
  /// [status]. [retryAfterHeader] is the raw `Retry-After` value in seconds.
  factory ApiError.fromResponse(
    int status,
    Object? body, {
    String? retryAfterHeader,
  }) {
    String? code;
    String? message;
    var details = const <String, Object?>{};
    if (body case {'error': final Map<Object?, Object?> error}) {
      if (error['code'] case final String c when c.isNotEmpty) code = c;
      if (error['message'] case final String m) message = m;
      if (error['details'] case final Map<Object?, Object?> d) {
        details = {for (final e in d.entries) '${e.key}': e.value};
      }
    }
    final seconds = int.tryParse(retryAfterHeader?.trim() ?? '');
    return ApiError(
      code: code ?? _codeForStatus(status),
      message: message ?? 'HTTP $status',
      status: status,
      details: details,
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );
  }

  /// Stable machine-readable code; compare with [ApiErrorCode] constants.
  final String code;

  /// The server's English message (fallback text only).
  final String message;

  /// HTTP status, or null for [ApiErrorCode.network] and
  /// [ApiErrorCode.timeout].
  final int? status;

  /// Extra context, e.g. `{"attempts_left": 3}` or `{"fields": {...}}`.
  final Map<String, Object?> details;

  /// From `Retry-After` on 429 (and sometimes 503).
  final Duration? retryAfter;

  /// No response from the server ([ApiErrorCode.network] or
  /// [ApiErrorCode.timeout]): show the offline state, keep cached data.
  bool get isNetwork =>
      code == ApiErrorCode.network || code == ApiErrorCode.timeout;

  /// No response in time ([ApiErrorCode.timeout]); also [isNetwork].
  bool get isTimeout => code == ApiErrorCode.timeout;

  /// Worth retrying later without changing the request: network failures,
  /// 5xx and 429 (after [retryAfter]). Never retry 4xx business errors.
  bool get isRetryable =>
      isNetwork ||
      code == ApiErrorCode.rateLimited ||
      (status != null && status! >= 500);

  /// 401 of any kind.
  bool get isUnauthorized => status == 401;

  /// 401 `unauthorized` with `details.reason = "expired"`: refresh and retry.
  bool get isExpiredToken =>
      code == ApiErrorCode.unauthorized && details['reason'] == 'expired';

  /// The device was revoked: wipe local data and sign in again.
  bool get isDeviceRevoked => code == ApiErrorCode.deviceRevoked;

  /// `details.attempts_left` on [ApiErrorCode.otpInvalid], else null.
  int? get attemptsLeft => switch (details['attempts_left']) {
    final int n => n,
    final num n => n.toInt(),
    _ => null,
  };

  /// `details.fields` on [ApiErrorCode.validationFailed]: field -> reason.
  Map<String, String> get fieldErrors => switch (details['fields']) {
    final Map<Object?, Object?> m => {
      for (final e in m.entries) '${e.key}': '${e.value}',
    },
    _ => const {},
  };

  static String _codeForStatus(int status) => switch (status) {
    400 => ApiErrorCode.invalidRequest,
    401 => ApiErrorCode.unauthorized,
    403 => ApiErrorCode.forbidden,
    404 => ApiErrorCode.notFound,
    405 => ApiErrorCode.methodNotAllowed,
    413 => ApiErrorCode.payloadTooLarge,
    429 => ApiErrorCode.rateLimited,
    503 => ApiErrorCode.unavailable,
    _ => ApiErrorCode.internal,
  };

  @override
  bool operator ==(Object other) =>
      other is ApiError &&
      other.code == code &&
      other.message == message &&
      other.status == status &&
      other.retryAfter == retryAfter &&
      const DeepCollectionEquality().equals(other.details, details);

  @override
  int get hashCode => Object.hash(
    code,
    message,
    status,
    retryAfter,
    const DeepCollectionEquality().hash(details),
  );

  @override
  String toString() =>
      'ApiError(${status ?? '-'} $code: $message'
      '${details.isEmpty ? '' : ' $details'}'
      '${retryAfter == null ? '' : ' retryAfter=${retryAfter!.inSeconds}s'})';
}
