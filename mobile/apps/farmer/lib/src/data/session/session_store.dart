import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'session_phase.dart';

/// What survives between launches once a farmer has signed in.
@immutable
class StoredSession {
  /// Creates a stored session.
  const StoredSession({
    required this.tokens,
    required this.farmerId,
    required this.deviceId,
  });

  /// Current token pair (replaced on every refresh).
  final TokenPair tokens;

  /// The signed-in farmer.
  final String farmerId;

  /// The registered device.
  final String deviceId;

  /// A copy with new tokens (after a refresh).
  StoredSession withTokens(TokenPair tokens) =>
      StoredSession(tokens: tokens, farmerId: farmerId, deviceId: deviceId);

  @override
  bool operator ==(Object other) =>
      other is StoredSession &&
      other.tokens == tokens &&
      other.farmerId == farmerId &&
      other.deviceId == deviceId;

  @override
  int get hashCode => Object.hash(tokens, farmerId, deviceId);
}

/// Where the session, the install ID and the language choice are kept.
///
/// The repositories write the session (sign-in, refresh, sign-out) and read
/// the access token from it; the session notifier reads it at start. Today
/// only [InMemorySessionStore] exists; a `flutter_secure_storage`
/// implementation replaces it without other changes.
abstract interface class SessionStore {
  /// The saved session, or null when signed out.
  Future<StoredSession?> readSession();

  /// Saves [session], replacing any previous one.
  Future<void> writeSession(StoredSession session);

  /// Forgets the session and its saved phase (sign-out, revoke). Keeps the
  /// install ID and language unless [wipe] is set (device revoked: new
  /// install ID too).
  Future<void> clearSession({bool wipe = false});

  /// The last known phase of the signed-in farmer (see
  /// [SavedSessionPhase.saved]), or null when none was saved. Used when the
  /// server cannot be asked at start (offline), so an unfinished sign-up
  /// resumes at its step instead of Home. Keep it next to the session: a
  /// secure-storage store saves [SessionPhase.name] and ignores unknown names.
  Future<SessionPhase?> readPhase();

  /// Saves the last known phase of the signed-in farmer.
  Future<void> writePhase(SessionPhase phase);

  /// The random install ID (`device_key`), or null before the first sign-in.
  Future<String?> readDeviceKey();

  /// Saves the install ID.
  Future<void> writeDeviceKey(String deviceKey);

  /// The language the farmer picked, or null before they picked one.
  Future<Language?> readLanguage();

  /// Saves the language choice.
  Future<void> writeLanguage(Language language);
}

/// A [SessionStore] that keeps everything in memory (lost on restart).
final class InMemorySessionStore implements SessionStore {
  /// Creates an empty store, or one that starts with a saved session.
  InMemorySessionStore([this._session]);

  StoredSession? _session;
  SessionPhase? _phase;
  String? _deviceKey;
  Language? _language;

  @override
  Future<StoredSession?> readSession() async => _session;

  @override
  Future<void> writeSession(StoredSession session) async => _session = session;

  @override
  Future<void> clearSession({bool wipe = false}) async {
    _session = null;
    _phase = null;
    if (wipe) _deviceKey = null;
  }

  @override
  Future<SessionPhase?> readPhase() async => _phase;

  @override
  Future<void> writePhase(SessionPhase phase) async => _phase = phase;

  @override
  Future<String?> readDeviceKey() async => _deviceKey;

  @override
  Future<void> writeDeviceKey(String deviceKey) async => _deviceKey = deviceKey;

  @override
  Future<Language?> readLanguage() async => _language;

  @override
  Future<void> writeLanguage(Language language) async => _language = language;
}
