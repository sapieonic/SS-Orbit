import 'package:flutter/foundation.dart';
import 'package:orbit_core/orbit_core.dart';

/// Called with every failure the session must act on: the [error] and the
/// farmer whose session the failed call was made with (null when unknown).
typedef AuthFailureListener = void Function(ApiError error, {String? farmerId});

/// The one place the data layer reports API failures that change the
/// session, so no screen has to handle them.
///
/// Repositories (mock today, the dio client later) call [report] for every
/// [ApiError] a signed-in call ends in. `SessionController` listens and:
///
/// - [endsSession] (any 401 the refresh could not fix: `unauthorized` for a
///   session that ended or expired, `refresh_reused`; or `device_revoked`,
///   which HO sends for a revoked phone): signs out to phone entry
///   (`device_revoked` also forgets the install ID). `session_revoked` is an
///   HO-portal code; a farmer token never gets it, though any 401 counts;
/// - [needsRecheck] (403 `forbidden`, e.g. a deactivated farmer's write, or
///   409 `profile_incomplete`): asks the server for the farmer's status
///   again and re-routes (Account paused, or back to sign-up).
///
/// Every other error is ignored here; the screen shows it.
final class AuthFailureHook {
  final List<AuthFailureListener> _listeners = [];

  /// True when [error] means the session is gone and the farmer must sign
  /// in again. The API client reports a 401 only after its refresh failed.
  static bool endsSession(ApiError error) =>
      error.isUnauthorized || error.isDeviceRevoked;

  /// True when [error] may mean the farmer's status changed on the server
  /// (deactivated by HO, or a sign-up that is not complete).
  static bool needsRecheck(ApiError error) =>
      error.code == ApiErrorCode.forbidden ||
      error.code == ApiErrorCode.profileIncomplete;

  /// Reports that a call made with [farmerId]'s session failed with [error].
  /// Cheap and safe to call for every error: only [endsSession] and
  /// [needsRecheck] errors reach the listeners. Never throws.
  void report(ApiError error, {String? farmerId}) {
    if (!endsSession(error) && !needsRecheck(error)) return;
    for (final listener in [..._listeners]) {
      try {
        listener(error, farmerId: farmerId);
      } on Object catch (e) {
        debugPrint('AuthFailureHook listener failed: $e');
      }
    }
  }

  /// Calls [listener] for every reported failure until the returned function
  /// is called.
  VoidCallback listen(AuthFailureListener listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}
