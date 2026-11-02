import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'session_phase.dart';

/// What survives between launches once an FA has signed in.
@immutable
class StoredSession {
  /// Creates a stored session.
  const StoredSession({
    required this.tokens,
    required this.faId,
    required this.deviceId,
    required this.fieldAssistant,
    required this.offlinePolicy,
    required this.mustChangePassword,
    this.signInKey,
  });

  /// The session as `POST /v1/auth/fa/login` returned it.
  factory StoredSession.fromLogin(FaSession s) => StoredSession(
    tokens: s.tokens,
    faId: s.fieldAssistant.id,
    deviceId: s.deviceId,
    fieldAssistant: s.fieldAssistant,
    offlinePolicy: s.offlinePolicy,
    mustChangePassword: s.mustChangePassword,
    signInKey: keyFor(s.tokens),
  );

  /// Reads what [toJson] wrote (the session store's `session` key).
  /// Throws [FormatException] for a malformed object.
  factory StoredSession.fromJson(Map<String, Object?> json) => StoredSession(
    tokens: TokenPair.fromJson(json.reqMap('tokens')),
    faId: json.reqString('fa_id'),
    deviceId: json.reqString('device_id'),
    fieldAssistant: FieldAssistant.fromJson(json.reqMap('field_assistant')),
    offlinePolicy: OfflinePolicy.fromJson(json.reqMap('offline_policy')),
    mustChangePassword: json.reqBool('must_change_password'),
    signInKey: json.optString('sign_in_key'),
  );

  /// The session as one JSON object ([StoredSession.fromJson] reads it).
  Map<String, Object?> toJson() => {
    'tokens': tokens.toJson(),
    'fa_id': faId,
    'device_id': deviceId,
    'field_assistant': fieldAssistant.toJson(),
    'offline_policy': offlinePolicy.toJson(),
    'must_change_password': mustChangePassword,
    if (signInKey != null) 'sign_in_key': signInKey,
  };

  /// The [signInKey] of a sign-in whose first pair is [tokens]: a short
  /// hash of its refresh token (the token itself is not kept twice).
  static String keyFor(TokenPair tokens) => sha256
      .convert(utf8.encode(tokens.refreshToken))
      .toString()
      .substring(0, 16);

  /// Current token pair (replaced on every refresh).
  final TokenPair tokens;

  /// The signed-in FA.
  final String faId;

  /// The registered device.
  final String deviceId;

  /// The FA's profile from the last login (there is no `GET /v1/fa/me`):
  /// shown on the PIN and Me screens, offline too.
  final FieldAssistant fieldAssistant;

  /// PIN length, offline grace and PIN tries from the last login.
  final OfflinePolicy offlinePolicy;

  /// Signed in with a temporary password: until the password is changed and
  /// the session refreshed, the token only works for the password change.
  final bool mustChangePassword;

  /// Names this sign-in (one login and all its refreshes): set at login and
  /// kept by [withTokens]. Repositories report failures with it
  /// (`AuthFailureHook.report(sessionKey:)`), so a late failure of an
  /// earlier sign-in, even of the same FA, never ends this one. Null only
  /// for a session saved without it (then the session goes by [faId]).
  final String? signInKey;

  /// A copy with new tokens (after a refresh), and the must-change flag the
  /// new token carries when given. Keeps [signInKey] (taken from the old
  /// pair when the session had none).
  StoredSession withTokens(TokenPair tokens, {bool? mustChangePassword}) =>
      StoredSession(
        tokens: tokens,
        faId: faId,
        deviceId: deviceId,
        fieldAssistant: fieldAssistant,
        offlinePolicy: offlinePolicy,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        signInKey: signInKey ?? keyFor(this.tokens),
      );

  @override
  bool operator ==(Object other) =>
      other is StoredSession &&
      other.tokens == tokens &&
      other.faId == faId &&
      other.deviceId == deviceId &&
      other.fieldAssistant == fieldAssistant &&
      other.offlinePolicy == offlinePolicy &&
      other.mustChangePassword == mustChangePassword &&
      other.signInKey == signInKey;

  @override
  int get hashCode => Object.hash(
    tokens,
    faId,
    deviceId,
    fieldAssistant,
    offlinePolicy,
    mustChangePassword,
    signInKey,
  );

  @override
  String toString() => 'StoredSession($faId, device $deviceId)';
}

/// The PIN verifier kept on the phone. The PIN itself is never stored; the
/// session's PIN code (`pin_lock.dart`) derives [hash] from it with [salt]
/// and [iterations]. The store treats every field as opaque.
@immutable
class PinRecord {
  /// Creates a record.
  const PinRecord({
    required this.salt,
    required this.hash,
    required this.iterations,
    this.failedAttempts = 0,
  });

  /// Random salt (encoded by the PIN code, e.g. base64).
  final String salt;

  /// The derived key (encoded by the PIN code, e.g. base64).
  final String hash;

  /// Key-derivation iterations used for [hash].
  final int iterations;

  /// Wrong PINs in a row since the last right one.
  final int failedAttempts;

  /// Reads what [toJson] wrote (the session store's `pin` key). Throws
  /// [FormatException] for a malformed object.
  factory PinRecord.fromJson(Map<String, Object?> json) => PinRecord(
    salt: json.reqString('salt'),
    hash: json.reqString('hash'),
    iterations: json.reqInt('iterations'),
    failedAttempts: json.optInt('failed_attempts') ?? 0,
  );

  /// The verifier as one JSON object ([PinRecord.fromJson] reads it).
  Map<String, Object?> toJson() => {
    'salt': salt,
    'hash': hash,
    'iterations': iterations,
    'failed_attempts': failedAttempts,
  };

  /// A copy with another [failedAttempts] count.
  PinRecord withFailedAttempts(int failedAttempts) => PinRecord(
    salt: salt,
    hash: hash,
    iterations: iterations,
    failedAttempts: failedAttempts,
  );

  @override
  bool operator ==(Object other) =>
      other is PinRecord &&
      other.salt == salt &&
      other.hash == hash &&
      other.iterations == iterations &&
      other.failedAttempts == failedAttempts;

  @override
  int get hashCode => Object.hash(salt, hash, iterations, failedAttempts);

  @override
  String toString() => 'PinRecord(failedAttempts: $failedAttempts)';
}

/// The FA whose local data (saved farmers, outbox) is on this phone.
///
/// Kept after a logout so that another FA's login can warn about their
/// unsynced records and wipe them first.
@immutable
class PhoneOwner {
  /// Creates an owner.
  const PhoneOwner({required this.faId, required this.code, this.name});

  /// Reads what [toJson] wrote. Throws [FormatException] for a malformed
  /// object.
  factory PhoneOwner.fromJson(Map<String, Object?> json) => PhoneOwner(
    faId: json.reqString('fa_id'),
    code: json.reqString('code'),
    name: json.optString('name'),
  );

  /// The owner as JSON ([PhoneOwner.fromJson] reads it).
  Map<String, Object?> toJson() => {
    'fa_id': faId,
    'code': code,
    if (name != null) 'name': name,
  };

  /// The FA's ID.
  final String faId;

  /// Their login ID (`FA-KDP-014`).
  final String code;

  /// Their name, when known.
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is PhoneOwner &&
      other.faId == faId &&
      other.code == code &&
      other.name == name;

  @override
  int get hashCode => Object.hash(faId, code, name);

  @override
  String toString() => 'PhoneOwner($code)';
}

/// What the session controller keeps beside the session, PIN and last
/// online contact, so a restart routes where the app left off.
///
/// Each field is one key in the secure-storage implementation (a missing
/// key is the default; writing a default deletes the key):
///
/// | Field | Key | Value |
/// |---|---|---|
/// | [phase] | `session.phase` | `SessionPhase.name`; an unknown name reads as null |
/// | [passwordNeededReason] | `session.password_needed_reason` | a `PasswordNeededReason` |
/// | [updateMinVersion] | `session.update_min_version` | `1.2.0` |
/// | [sessionEnded] | `session.session_ended` | `1` when true |
/// | [updateFromHeartbeat] | `session.update_from_heartbeat` | `1` when true |
/// | [cleanTokenPending] | `session.clean_token_pending` | `1` when true |
/// | [passwordChangeSent] | `session.password_change_sent` | `1` when true |
/// | [wipePending] | `session.wipe_pending` | `1` when true |
/// | [lastSeenAt] | `session.last_seen_at` | RFC 3339 UTC |
/// | [lastOwner] | `owner.fa_id`, `owner.code`, `owner.name` | strings |
@immutable
class SessionMeta {
  /// Creates the meta; the defaults are "nothing saved".
  const SessionMeta({
    this.phase,
    this.passwordNeededReason,
    this.updateMinVersion,
    this.updateFromHeartbeat = false,
    this.sessionEnded = false,
    this.cleanTokenPending = false,
    this.passwordChangeSent = false,
    this.wipePending = false,
    this.lastSeenAt,
    this.lastOwner,
  });

  /// The phase the app was in last.
  final SessionPhase? phase;

  /// Why the password is needed (a `PasswordNeededReason`), when [phase] is
  /// [SessionPhase.passwordNeeded].
  final String? passwordNeededReason;

  /// The `min_version` of an update block still in force.
  final String? updateMinVersion;

  /// The block came from a heartbeat (not cached): only a heartbeat lifts
  /// it, not an `app-config` answer that may be up to 5 minutes old.
  final bool updateFromHeartbeat;

  /// The server session ended while the FA kept working offline: nothing
  /// syncs until a password login.
  final bool sessionEnded;

  /// The password was changed but the refresh for a token without the
  /// must-change flag has not worked yet.
  final bool cleanTokenPending;

  /// The first-login password change was sent, and whether the server took
  /// it is not known yet (no answer, or the app was killed). The next
  /// recheck refreshes and reads the new token's must-change flag.
  final bool passwordChangeSent;

  /// HO removed the phone and the local data is not deleted yet: the app
  /// shows the splash and retries the wipe (at start, on resume) before it
  /// routes anywhere. [SessionStore.clear] keeps it.
  final bool wipePending;

  /// The latest device time the session has seen (UTC, the device clock,
  /// like the last online contact). Never moves back; a clock more than
  /// `clockBackTolerance` behind it ends the PIN's offline grace.
  final DateTime? lastSeenAt;

  /// Whose local data is on the phone. [SessionStore.clear] keeps it,
  /// except a clear that wipes the install ID (the phone was wiped).
  final PhoneOwner? lastOwner;

  /// Nothing saved.
  static const empty = SessionMeta();

  /// Reads what [toJson] wrote. A missing key is its default and an unknown
  /// phase name reads as null (an older or newer app wrote it); a value of
  /// the wrong type throws [FormatException].
  factory SessionMeta.fromJson(Map<String, Object?> json) {
    final phase = json.optString('phase');
    final owner = json.optMap('last_owner');
    return SessionMeta(
      phase: SessionPhase.values.where((p) => p.name == phase).firstOrNull,
      passwordNeededReason: json.optString('password_needed_reason'),
      updateMinVersion: json.optString('update_min_version'),
      updateFromHeartbeat: json.optBool('update_from_heartbeat') ?? false,
      sessionEnded: json.optBool('session_ended') ?? false,
      cleanTokenPending: json.optBool('clean_token_pending') ?? false,
      passwordChangeSent: json.optBool('password_change_sent') ?? false,
      wipePending: json.optBool('wipe_pending') ?? false,
      lastSeenAt: json.optDateTime('last_seen_at'),
      lastOwner: owner == null ? null : PhoneOwner.fromJson(owner),
    );
  }

  /// The meta as one JSON object, defaults left out ([SessionMeta.fromJson]
  /// reads it). A store that keeps one key per field (see the table above)
  /// writes each entry under its key instead.
  Map<String, Object?> toJson() => {
    if (phase != null) 'phase': phase!.name,
    if (passwordNeededReason != null)
      'password_needed_reason': passwordNeededReason,
    if (updateMinVersion != null) 'update_min_version': updateMinVersion,
    if (updateFromHeartbeat) 'update_from_heartbeat': true,
    if (sessionEnded) 'session_ended': true,
    if (cleanTokenPending) 'clean_token_pending': true,
    if (passwordChangeSent) 'password_change_sent': true,
    if (wipePending) 'wipe_pending': true,
    if (lastSeenAt != null) 'last_seen_at': utcIso(lastSeenAt!),
    if (lastOwner != null) 'last_owner': lastOwner!.toJson(),
  };

  static const _keep = Object();

  /// A copy with the given fields replaced; pass null to clear a nullable
  /// field.
  SessionMeta copyWith({
    Object? phase = _keep,
    Object? passwordNeededReason = _keep,
    Object? updateMinVersion = _keep,
    bool? updateFromHeartbeat,
    bool? sessionEnded,
    bool? cleanTokenPending,
    bool? passwordChangeSent,
    bool? wipePending,
    Object? lastSeenAt = _keep,
    Object? lastOwner = _keep,
  }) => SessionMeta(
    phase: identical(phase, _keep) ? this.phase : phase as SessionPhase?,
    passwordNeededReason: identical(passwordNeededReason, _keep)
        ? this.passwordNeededReason
        : passwordNeededReason as String?,
    updateMinVersion: identical(updateMinVersion, _keep)
        ? this.updateMinVersion
        : updateMinVersion as String?,
    updateFromHeartbeat: updateFromHeartbeat ?? this.updateFromHeartbeat,
    sessionEnded: sessionEnded ?? this.sessionEnded,
    cleanTokenPending: cleanTokenPending ?? this.cleanTokenPending,
    passwordChangeSent: passwordChangeSent ?? this.passwordChangeSent,
    wipePending: wipePending ?? this.wipePending,
    lastSeenAt: identical(lastSeenAt, _keep)
        ? this.lastSeenAt
        : lastSeenAt as DateTime?,
    lastOwner: identical(lastOwner, _keep)
        ? this.lastOwner
        : lastOwner as PhoneOwner?,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionMeta &&
      other.phase == phase &&
      other.passwordNeededReason == passwordNeededReason &&
      other.updateMinVersion == updateMinVersion &&
      other.updateFromHeartbeat == updateFromHeartbeat &&
      other.sessionEnded == sessionEnded &&
      other.cleanTokenPending == cleanTokenPending &&
      other.passwordChangeSent == passwordChangeSent &&
      other.wipePending == wipePending &&
      other.lastSeenAt == lastSeenAt &&
      other.lastOwner == lastOwner;

  @override
  int get hashCode => Object.hash(
    phase,
    passwordNeededReason,
    updateMinVersion,
    updateFromHeartbeat,
    sessionEnded,
    cleanTokenPending,
    passwordChangeSent,
    wipePending,
    lastSeenAt,
    lastOwner,
  );

  @override
  String toString() =>
      'SessionMeta(${phase?.name}, reason: $passwordNeededReason, '
      'min: $updateMinVersion, ended: $sessionEnded, '
      'cleanTokenPending: $cleanTokenPending, '
      'changeSent: $passwordChangeSent, wipePending: $wipePending, '
      'owner: ${lastOwner?.code})';
}

/// Where the session, the install ID, the language, the PIN verifier, the
/// last online contact and the [SessionMeta] are kept.
///
/// The auth repository writes the session (login, refresh) and every other
/// repository reads the access token from it; the session controller reads
/// it at start and owns the PIN, meta, language and last-online fields.
/// Today only [InMemorySessionStore] exists; a `flutter_secure_storage`
/// implementation replaces it without other changes: every field is one
/// key (the session and PIN as JSON, the meta as in [SessionMeta]).
abstract interface class SessionStore {
  /// The saved session, or null when signed out.
  Future<StoredSession?> readSession();

  /// Saves [session], replacing any previous one.
  Future<void> writeSession(StoredSession session);

  /// The random install ID (`DeviceInfo.deviceKey`), made and saved on the
  /// first call and kept until [resetDeviceKey] or a [clear] with
  /// `wipeDeviceKey`.
  Future<String> deviceKey();

  /// Forgets the install ID (after a wipe): the next [deviceKey] makes a new
  /// one, so the phone registers as a new device.
  Future<void> resetDeviceKey();

  /// The app language the FA picked, or null before they picked one (the
  /// app then shows Telugu).
  Future<Language?> readLanguage();

  /// Saves the language choice.
  Future<void> writeLanguage(Language language);

  /// The PIN verifier, or null when no PIN is set.
  Future<PinRecord?> readPin();

  /// Saves the PIN verifier (a new PIN, or a new failed-attempts count).
  Future<void> writePin(PinRecord pin);

  /// Forgets the PIN (locked out, or the FA asked for a new one).
  Future<void> clearPin();

  /// UTC time of the last successful login or refresh, or null. The PIN
  /// works offline for `OfflinePolicy.offlineGraceDays` after it.
  ///
  /// Always the device clock (`clockProvider`), never the server's time:
  /// the session compares it with the device clock and with
  /// [SessionMeta.lastSeenAt].
  Future<DateTime?> readLastOnlineAt();

  /// Saves the last online contact.
  Future<void> writeLastOnlineAt(DateTime at);

  /// What the session controller saved last ([SessionMeta.empty] when
  /// nothing).
  Future<SessionMeta> readMeta();

  /// Saves [meta], replacing every field.
  Future<void> writeMeta(SessionMeta meta);

  /// Signs the phone out: forgets the session, PIN, last online contact and
  /// meta, but keeps [SessionMeta.lastOwner] (their unsynced records stay
  /// on the phone) and [SessionMeta.wipePending] (a wipe still owed). Keeps
  /// the language, and the install ID unless [wipeDeviceKey] (device
  /// revoked or wiped: the next sign-in registers a new device, and the
  /// owner is forgotten too).
  Future<void> clear({bool wipeDeviceKey = false});
}

/// A [SessionStore] that keeps everything in memory (lost on restart).
final class InMemorySessionStore implements SessionStore {
  /// Creates an empty store, or one that starts with a saved session.
  ///
  /// [random] makes generated install IDs repeatable in tests.
  InMemorySessionStore({
    this._session,
    this._pin,
    this._language,
    this._lastOnlineAt,
    this._deviceKey,
    math.Random? random,
  }) : _random = random ?? math.Random.secure();

  final math.Random _random;
  StoredSession? _session;
  PinRecord? _pin;
  Language? _language;
  DateTime? _lastOnlineAt;
  String? _deviceKey;
  SessionMeta _meta = SessionMeta.empty;

  @override
  Future<StoredSession?> readSession() async => _session;

  @override
  Future<void> writeSession(StoredSession session) async => _session = session;

  @override
  Future<String> deviceKey() async => _deviceKey ??= _newDeviceKey();

  @override
  Future<void> resetDeviceKey() async => _deviceKey = null;

  @override
  Future<Language?> readLanguage() async => _language;

  @override
  Future<void> writeLanguage(Language language) async => _language = language;

  @override
  Future<PinRecord?> readPin() async => _pin;

  @override
  Future<void> writePin(PinRecord pin) async => _pin = pin;

  @override
  Future<void> clearPin() async => _pin = null;

  @override
  Future<DateTime?> readLastOnlineAt() async => _lastOnlineAt;

  @override
  Future<void> writeLastOnlineAt(DateTime at) async =>
      _lastOnlineAt = at.toUtc();

  @override
  Future<SessionMeta> readMeta() async => _meta;

  @override
  Future<void> writeMeta(SessionMeta meta) async => _meta = meta;

  @override
  Future<void> clear({bool wipeDeviceKey = false}) async {
    _session = null;
    _pin = null;
    _lastOnlineAt = null;
    _meta = SessionMeta(
      lastOwner: wipeDeviceKey ? null : _meta.lastOwner,
      wipePending: _meta.wipePending,
    );
    if (wipeDeviceKey) _deviceKey = null;
  }

  /// `fa-` and 32 hex digits (matches `^[A-Za-z0-9._:-]{8,128}$`).
  String _newDeviceKey() =>
      'fa-${List.generate(32, (_) => _random.nextInt(16).toRadixString(16)).join()}';
}
