import '../models/models.dart';

/// Sign-in, tokens and the device heartbeat (`/v1/auth/*`,
/// `PUT /v1/farmer/devices/me`).
///
/// Implementations own the token store: [verifyOtp] saves the new session in
/// the `SessionStore` before returning, [logout] clears it, and every other
/// repository reads the access token from it. Screens never handle tokens.
///
/// Every method throws `ApiError` (orbit_core) on failure; a call that never
/// reached the server throws `ApiError.network()`.
abstract interface class AuthRepository {
  /// `GET /v1/auth/app-config?app=farmer` (no token, cacheable 5 minutes).
  ///
  /// Call at start, before sign-in. Throws `network`, `unavailable`.
  Future<AppConfig> getAppConfig();

  /// `POST /v1/auth/otp/request {phone, language}`.
  ///
  /// [phone] as the farmer typed it (10 digits is fine); [language] picks the
  /// SMS language. A new request replaces the previous code.
  /// Throws `validation_failed` (bad phone), `rate_limited` (one every 30 s,
  /// a few an hour; see `ApiError.retryAfter`).
  Future<OtpSent> requestOtp({
    required String phone,
    required Language language,
  });

  /// `POST /v1/auth/otp/verify {phone, code, device}`.
  ///
  /// On success the session is saved to the session store. Throws
  /// `otp_invalid` (`ApiError.attemptsLeft`), `otp_expired` (ask for a new
  /// code), `device_revoked` (wipe, new install ID), `rate_limited`,
  /// `validation_failed`.
  Future<FarmerSession> verifyOtp({
    required String phone,
    required String code,
    required DeviceInfo device,
  });

  /// `POST /v1/auth/refresh {refresh_token}`.
  ///
  /// Normally called only by the HTTP layer's single-flight refresher, not by
  /// screens. Saves the new pair to the session store. Throws `unauthorized`
  /// (session expired or revoked), `refresh_reused`, `device_revoked`.
  Future<TokenPair> refreshSession();

  /// `POST /v1/auth/logout {refresh_token}` (always 204 on the server).
  ///
  /// Never throws: the session store is cleared first and the server call is
  /// best effort (offline sign-out still signs out).
  Future<void> logout();

  /// `PUT /v1/farmer/devices/me {model, os_version, app_version, push_token}`.
  ///
  /// Call on app start, when the push token rotates and once a day.
  /// `DeviceStatus.wipe` means wipe exactly as for `device_revoked`.
  /// Throws `unauthorized`, `device_revoked`, `not_found`.
  Future<DeviceStatus> heartbeat({
    String? model,
    String? osVersion,
    String? appVersion,
    String? pushToken,
  });
}
