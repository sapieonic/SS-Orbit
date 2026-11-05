import '../models/models.dart';

/// Sign-in, tokens, password change and the device heartbeat
/// (`/v1/auth/*`, `POST /v1/fa/me/password`, `PUT /v1/fa/devices/me`).
///
/// Implementations own the token store: [login] saves the new session in the
/// `SessionStore` before returning, [refreshSession] saves the rotated pair,
/// [logout] clears it, and every other repository reads the access token from
/// it. Screens never handle tokens.
///
/// Every method throws `ApiError` (orbit_core) on failure; a call that never
/// reached the server throws `ApiError.network()`. Any call may also throw
/// 401 `device_revoked` (wipe local data, new device key).
abstract interface class FaAuthRepository {
  /// `GET /v1/auth/app-config?app=fa` (no token, cacheable 5 minutes).
  ///
  /// Call at start, before sign-in. Throws `network`, `unavailable`.
  Future<AppConfig> getAppConfig();

  /// `POST /v1/auth/fa/login {code, password, device}`.
  ///
  /// [code] is the login ID from HO (`FA-KDP-014`, case-insensitive). Saves
  /// the session (tokens, device ID, FA profile, offline policy) to the
  /// session store. When `FaSession.mustChangePassword` is true the token
  /// only works for [changePassword].
  ///
  /// Throws `unauthorized` (unknown ID, wrong password or inactive login, one
  /// message for all), `temp_password_expired` (temporary password over 72 h
  /// old: call HO), `device_revoked`, `rate_limited`, `validation_failed`.
  Future<FaSession> login({
    required String code,
    required String password,
    required DeviceInfo device,
  });

  /// `POST /v1/auth/refresh {refresh_token}`.
  ///
  /// Normally called only by the HTTP layer's single-flight refresher, and
  /// once after [changePassword] to drop the must-change flag. Saves the new
  /// pair to the session store (and counts as an online contact for the PIN
  /// grace). Throws `unauthorized` (session expired or revoked, login
  /// deactivated), `refresh_reused`, `device_revoked`,
  /// `temp_password_expired`, `rate_limited`.
  Future<TokenPair> refreshSession();

  /// `POST /v1/auth/logout {refresh_token}` (always 204 on the server).
  ///
  /// Never throws: the session store is cleared first and the server call is
  /// best effort. Does not touch the outbox (unsynced work is kept).
  Future<void> logout();

  /// `POST /v1/fa/me/password {current_password, new_password}` (204).
  ///
  /// [newPassword]: at least 8 characters with a letter and a digit, not the
  /// login ID or the old password. Signs out the FA's other sessions; call
  /// [refreshSession] afterwards for a token without the must-change flag.
  /// Throws `validation_failed` (`ApiError.fieldErrors`: weak password, or
  /// `current_password` when the current password is wrong),
  /// `temp_password_expired`, `rate_limited`, `forbidden`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// `PUT /v1/fa/devices/me {model, os_version, app_version, push_token}`.
  ///
  /// Call on app start, after each sync, when the push token rotates and
  /// once a day. `DeviceStatus.wipe` means wipe exactly as for
  /// `device_revoked`; `DeviceStatus.updateRequired` means push the outbox,
  /// then block for the update. Throws `unauthorized`, `device_revoked`,
  /// `password_change_required`, `not_found`, `validation_failed`.
  Future<DeviceStatus> heartbeat({
    String? model,
    String? osVersion,
    String? appVersion,
    String? pushToken,
  });
}
