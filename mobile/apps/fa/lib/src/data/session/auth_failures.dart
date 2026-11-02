import 'package:flutter/foundation.dart';
import 'package:orbit_core/orbit_core.dart';

/// Called with every failure the session must act on: the [error] and the
/// FA whose session the failed call was made with (null when unknown). A
/// listener may also take `sessionKey` (see [AuthFailureSessionListener]).
typedef AuthFailureListener = void Function(ApiError error, {String? faId});

/// An [AuthFailureListener] that also gets the sign-in's
/// `StoredSession.signInKey` (null when the repository did not give it).
typedef AuthFailureSessionListener = void Function(
  ApiError error, {
  String? faId,
  String? sessionKey,
});

/// The one place the data layer reports API failures that change the
/// session, so no screen and not the sync engine has to handle them.
///
/// Repositories (mock today, the dio client later) call [report] for every
/// [ApiError] a signed-in call ends in. `SessionController` listens and:
///
/// - [endsSession] (any 401 the refresh could not fix: `unauthorized` for a
///   session that ended or expired, `refresh_reused`, `session_revoked`,
///   `temp_password_expired`): the password is needed again
///   (`passwordNeeded`); the outbox and local data are kept;
/// - [isDeviceRevoked] (401 `device_revoked`, HO removed the phone): wipe
///   local data, tokens, PIN and the install ID (`removed`);
/// - [needsPasswordChange] (403 `password_change_required`): back to the
///   password change.
///
/// Every other error (network, 5xx, validation, a rejected command) is
/// ignored here; the caller shows or retries it.
final class AuthFailureHook {
  final List<AuthFailureSessionListener> _listeners = [];

  /// True when [error] means HO removed this phone: wipe it.
  static bool isDeviceRevoked(ApiError error) => error.isDeviceRevoked;

  /// True when [error] means the server session is gone and the FA must
  /// sign in with the password again. The API client reports a 401 only
  /// after its refresh failed. `device_revoked` is not included: see
  /// [isDeviceRevoked].
  static bool endsSession(ApiError error) =>
      error.isUnauthorized && !error.isDeviceRevoked;

  /// True when [error] means the token still carries the must-change flag.
  static bool needsPasswordChange(ApiError error) =>
      error.code == ApiErrorCode.passwordChangeRequired;

  /// True when the session must hear about [error].
  static bool concernsSession(ApiError error) =>
      isDeviceRevoked(error) ||
      endsSession(error) ||
      needsPasswordChange(error);

  /// Reports that a call made with [faId]'s session failed with [error].
  /// Pass [sessionKey], the `StoredSession.signInKey` of the session the
  /// request used (read when it started), so a late failure of an earlier
  /// sign-in of the same FA is told apart; without it the session goes by
  /// [faId]. Cheap and safe to call for every error: only [concernsSession]
  /// errors reach the listeners. Never throws.
  void report(ApiError error, {String? faId, String? sessionKey}) {
    if (!concernsSession(error)) return;
    for (final listener in [..._listeners]) {
      try {
        listener(error, faId: faId, sessionKey: sessionKey);
      } on Object catch (e) {
        debugPrint('AuthFailureHook listener failed: $e');
      }
    }
  }

  /// Calls [listener] for every reported failure until the returned function
  /// is called. A listener that takes `sessionKey` gets it too.
  VoidCallback listen(AuthFailureListener listener) {
    final AuthFailureSessionListener wrapped = switch (listener) {
      final AuthFailureSessionListener withKey => withKey,
      _ => (error, {faId, sessionKey}) => listener(error, faId: faId),
    };
    _listeners.add(wrapped);
    return () => _listeners.remove(wrapped);
  }
}
