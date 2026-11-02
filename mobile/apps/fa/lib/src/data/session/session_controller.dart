import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';

import '../models/models.dart';
import '../providers.dart'
    show
        authFailureHookProvider,
        clockProvider,
        faAuthRepositoryProvider,
        sessionStoreProvider;
import '../repositories/fa_auth_repository.dart';
import 'auth_failures.dart';
import 'local_data_guard.dart';
import 'pin_lock.dart';
import 'session_phase.dart';
import 'session_store.dart';

export 'local_data_guard.dart';
export 'pin_lock.dart' show PinLock, PinProblem, pinLockProvider;
export 'session_phase.dart';

/// Why [SessionPhase.passwordNeeded] was entered
/// ([SessionState.passwordNeededReason]; null when the FA chose "Use
/// password instead").
abstract final class PasswordNeededReason {
  /// The PIN's offline grace ended: "Session ended. Log in with your
  /// password once you have network."
  static const expired = 'expired';

  /// Too many wrong PINs: the PIN is disabled; after the password login the
  /// FA picks a new one.
  static const lockedOut = 'lockedOut';

  /// The server session ended for good (refresh failed, `refresh_reused`,
  /// login deactivated). While the grace lasts the PIN still opens local
  /// data ([SessionState.canUsePin], "Unlock with your PIN to keep working
  /// offline"); sync needs the password.
  static const sessionEnded = 'sessionEnded';

  /// 401 `temp_password_expired`: "Your temporary password has expired.
  /// Call HO for a new one."
  static const tempPasswordExpired = 'tempPasswordExpired';
}

/// The session as the app sees it: routing phase, the FA, the offline
/// rules, language and release state. Tokens and the PIN never appear here.
@immutable
class SessionState {
  /// Creates a state.
  const SessionState({
    required this.phase,
    this.fa,
    this.policy = OfflinePolicy.standard,
    this.language = Language.te,
    this.pinAttemptsLeft,
    this.graceEndsAt,
    this.passwordNeededReason,
    this.appConfig,
    this.updateAvailable = false,
    this.canUsePin = false,
    this.syncNeedsPassword = false,
    this.clockOffset = Duration.zero,
  });

  /// The routing phase.
  final SessionPhase phase;

  /// The FA of the session on this phone (from the last login), also while
  /// [SessionPhase.locked] or [SessionPhase.passwordNeeded] (to greet them
  /// and prefill the login ID). Null when signed out.
  final FieldAssistant? fa;

  /// PIN length, offline grace and PIN tries (from the last login).
  final OfflinePolicy policy;

  /// The app language; the locale follows it (Telugu default).
  final Language language;

  /// Wrong PINs left before the lock-out, or null when no PIN is set. Show
  /// "N tries left" when it is below `policy.pinMaxAttempts`.
  final int? pinAttemptsLeft;

  /// When the PIN stops working offline (last online contact + grace), or
  /// null when signed out. Me shows "6 days left".
  final DateTime? graceEndsAt;

  /// Why the password is needed ([PasswordNeededReason]), only in
  /// [SessionPhase.passwordNeeded].
  final String? passwordNeededReason;

  /// Release settings from the last `GET /v1/auth/app-config`, or null.
  final AppConfig? appConfig;

  /// A newer version than this one is out (the dismissable "New version"
  /// card); only when [appConfig] is known.
  final bool updateAvailable;

  /// A PIN is set, not locked out, and the offline grace still runs: in
  /// [SessionPhase.passwordNeeded], offer "Enter PIN" (`usePin`).
  final bool canUsePin;

  /// The server session ended while the FA kept working offline: local
  /// work goes on, but nothing syncs until a password login. Sync and Me
  /// say "Log in with your password to sync".
  final bool syncNeedsPassword;

  /// `server_time - device time` from the last heartbeat (zero before one).
  /// Use [serverClockProvider] for `visited_at` and `client_created_at`.
  final Duration clockOffset;

  /// True when a session (live or ended) for [fa] is on this phone.
  bool get isSignedIn => fa != null;

  @override
  bool operator ==(Object other) =>
      other is SessionState &&
      other.phase == phase &&
      other.fa == fa &&
      other.policy == policy &&
      other.language == language &&
      other.pinAttemptsLeft == pinAttemptsLeft &&
      other.graceEndsAt == graceEndsAt &&
      other.passwordNeededReason == passwordNeededReason &&
      other.appConfig == appConfig &&
      other.updateAvailable == updateAvailable &&
      other.canUsePin == canUsePin &&
      other.syncNeedsPassword == syncNeedsPassword &&
      other.clockOffset == clockOffset;

  @override
  int get hashCode => Object.hash(
    phase,
    fa,
    policy,
    language,
    pinAttemptsLeft,
    graceEndsAt,
    passwordNeededReason,
    appConfig,
    updateAvailable,
    canUsePin,
    syncNeedsPassword,
    clockOffset,
  );

  @override
  String toString() =>
      'SessionState(${phase.name}, ${fa?.code}, ${language.wire}'
      '${passwordNeededReason == null ? '' : ', $passwordNeededReason'})';
}

/// Thrown by [SessionController.login] when another FA's unsynced records
/// are on this phone. Show "This phone has [unsynced] unsynced records of
/// [previousCode]. Logging in as another FA deletes them." and, when the FA
/// confirms, call `login` again with `replaceOtherFa: true`.
///
/// When the other FA has nothing unsynced, `login` does not ask: their saved
/// farmers are deleted after the new login succeeds.
final class OtherFaOnPhone extends StateError {
  /// Creates the error.
  OtherFaOnPhone({
    required this.previousCode,
    required this.previousName,
    required this.unsynced,
  }) : super('$previousCode has $unsynced unsynced records on this phone');

  /// Login ID of the FA whose data is on the phone.
  final String previousCode;

  /// Their name, when known.
  final String? previousName;

  /// Their records not yet synced (deleted if the login goes ahead).
  final int unsynced;
}

/// Thrown by [SessionController.login] when another FA's local data could
/// not be deleted after the new login: the new login is signed out again
/// (their data must not reach this FA's sync) and the phone stays signed
/// out. The screen says "try again".
final class LocalDataWipeFailed implements Exception {
  /// Creates the error.
  const LocalDataWipeFailed(this.cause);

  /// What the wipe threw.
  final Object cause;

  @override
  String toString() => 'LocalDataWipeFailed($cause)';
}

/// The password rules of `POST /v1/fa/me/password`, checked on the phone
/// first (the same rules and messages as the backend), so A1c can show a
/// live checklist and nothing weak is sent.
@immutable
final class PasswordCheck {
  /// Checks [password] against the rules; [current] and [loginId] are the
  /// FA's current password and login ID when known.
  factory PasswordCheck(String password, {String? current, String? loginId}) {
    final id = loginId?.trim().toLowerCase();
    return PasswordCheck._(
      longEnough: password.runes.length >= 8,
      hasLetterAndDigit:
          RegExp(r'\p{L}', unicode: true).hasMatch(password) &&
          RegExp(r'\p{Nd}', unicode: true).hasMatch(password),
      notLoginId:
          id == null || id.isEmpty || !password.toLowerCase().contains(id),
      notCurrent: current == null || password != current,
    );
  }

  const PasswordCheck._({
    required this.longEnough,
    required this.hasLetterAndDigit,
    required this.notLoginId,
    required this.notCurrent,
  });

  /// At least 8 characters.
  final bool longEnough;

  /// At least one letter and one digit.
  final bool hasLetterAndDigit;

  /// Does not contain the login ID (any case).
  final bool notLoginId;

  /// Not the current password.
  final bool notCurrent;

  /// Every rule holds.
  bool get ok => problem == null;

  /// The first broken rule in the backend's words, or null.
  String? get problem {
    if (!longEnough) return 'must be at least 8 characters';
    if (!hasLetterAndDigit) return 'must contain a letter and a digit';
    if (!notCurrent) return 'must be different from the current password';
    if (!notLoginId) return 'must not contain your login ID or email';
    return null;
  }
}

/// This build's version (`ORBIT_APP_VERSION` dart-define, else the
/// pubspec version). Compared with `min_version` / `latest_version`.
final appVersionProvider = Provider<String>(
  (ref) =>
      const String.fromEnvironment('ORBIT_APP_VERSION', defaultValue: '0.1.0'),
);

/// Compares dotted versions (`1.0.3` < `1.0.10`; a `+build` suffix and
/// anything that is not a number count as 0).
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// The session state; the router's source of truth.
final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// The app locale's language (follows [SessionState.language]; Telugu by
/// default).
final appLanguageProvider = Provider<Language>(
  (ref) => ref.watch(sessionProvider.select((s) => s.language)),
);

/// The device clock corrected by the last heartbeat's `server_time`
/// ([SessionState.clockOffset]). Use it for times the server checks
/// (`visited_at` must not be in the future; cheap phones' clocks drift).
final serverClockProvider = Provider<Clock>(
  (ref) => _OffsetClock(
    ref.watch(clockProvider),
    ref.watch(sessionProvider.select((s) => s.clockOffset)),
  ),
);

final class _OffsetClock implements Clock {
  const _OffsetClock(this._device, this._offset);

  final Clock _device;
  final Duration _offset;

  @override
  DateTime now() => _device.now().add(_offset);
}

/// How long the app may sit in the background before [SessionController.lock]
/// should be called (the app layer owns the timer).
const autoLockAfter = Duration(minutes: 5);

/// How far the device clock may go back behind the latest time the session
/// saw ([SessionMeta.lastSeenAt]) before the PIN's offline grace counts as
/// over (a small network-time correction is fine; a clock set back by
/// hours or days is not).
const clockBackTolerance = Duration(minutes: 10);

/// Sign-in, password change, setup, PIN lock and the device's standing with
/// the server. Actions throw `ApiError` for the screen (wrong password,
/// offline, weak PIN); the state changes only on success.
///
/// Any await can outlive the session it started on: the FA logs out while a
/// login is in flight, HO removes the phone while a heartbeat runs, a late
/// failure of the previous FA's call arrives. So every sign-in, sign-out,
/// wipe and block starts a new generation, and work started in an older one
/// never writes the state. The server's word wins: a wipe or update block
/// from the server overrides whatever the FA is doing.
class SessionController extends Notifier<SessionState> {
  late SessionStore _store;
  late FaAuthRepository _auth;
  late Clock _clock;
  late LocalDataGuard _guard;
  late PinLock _pinLock;
  late String _appVersion;

  int _generation = 0;
  Future<void>? _restoring;
  Future<void>? _wiping;
  ({int generation, Future<void> future})? _rechecking;
  ({int generation, Future<bool> future})? _cleanRefresh;
  Future<void> _storeQueue = Future<void>.value();
  Future<void> _pinQueue = Future<void>.value();
  bool _languagePicked = false;

  // What the state is built from (mirrors the store).
  StoredSession? _session;
  PinRecord? _pin;
  DateTime? _lastOnlineAt;
  Language _language = Language.te;
  AppConfig? _appConfig;
  Duration _clockOffset = Duration.zero;
  SessionMeta _meta = SessionMeta.empty;

  @override
  SessionState build() {
    _store = ref.watch(sessionStoreProvider);
    _auth = ref.watch(faAuthRepositoryProvider);
    _clock = ref.watch(clockProvider);
    _guard = ref.watch(localDataGuardProvider);
    _pinLock = ref.watch(pinLockProvider);
    _appVersion = ref.watch(appVersionProvider);
    _generation++;
    _rechecking = null;
    _cleanRefresh = null;
    _wiping = null;
    _languagePicked = false;
    ref.onDispose(ref.watch(authFailureHookProvider).listen(_onAuthFailure));
    _restoring = _restore();
    unawaited(_restoring!.then((_) => _startupChecks()));
    return const SessionState(phase: SessionPhase.restoring);
  }

  /// Completes when the saved session has been read and routed (no network
  /// involved).
  Future<void> get restored => _restoring ?? Future<void>.value();

  /// True while work started in [generation] may still write the state.
  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  // -------------------------------------------------------------------------
  // State and persistence.

  DateTime get _now => _clock.now();

  OfflinePolicy get _policy =>
      _session?.offlinePolicy ?? OfflinePolicy.standard;

  DateTime? get _graceEndsAt =>
      _session == null ? null : _lastOnlineAt?.add(_policy.offlineGrace);

  /// The PIN's offline grace is over (or there was never an online
  /// contact), or the device clock went back more than
  /// [clockBackTolerance] behind the latest time seen (set back to stretch
  /// the grace). One time base: the device clock, for [_lastOnlineAt] and
  /// [SessionMeta.lastSeenAt] alike.
  bool get _graceOver {
    final now = _now;
    final seen = _meta.lastSeenAt;
    if (seen != null && now.isBefore(seen.subtract(clockBackTolerance))) {
      return true;
    }
    final ends = _graceEndsAt;
    return ends == null || !now.isBefore(ends);
  }

  /// Moves [SessionMeta.lastSeenAt] up to now (never back); saved with the
  /// next meta write.
  void _markSeen() {
    final now = _now.toUtc();
    final seen = _meta.lastSeenAt;
    if (seen == null || now.isAfter(seen)) {
      _meta = _meta.copyWith(lastSeenAt: now);
    }
  }

  /// The token still carries the must-change flag and no password change
  /// is known to have gone through.
  bool get _mustChangeOutstanding =>
      (_session?.mustChangePassword ?? false) && !_meta.cleanTokenPending;

  bool get _pinLockedOut =>
      _pin != null && PinLock.isLockedOut(_pin!, _policy.pinMaxAttempts);

  bool get _pinUsable =>
      _session != null && _pin != null && !_pinLockedOut && !_graceOver;

  SessionState _stateFor(SessionPhase phase, {String? reason}) {
    final pin = _pin;
    final config = _appConfig;
    return SessionState(
      phase: phase,
      fa: _session?.fieldAssistant,
      policy: _policy,
      language: _language,
      pinAttemptsLeft: pin == null
          ? null
          : PinLock.attemptsLeft(pin, _policy.pinMaxAttempts),
      graceEndsAt: _graceEndsAt,
      passwordNeededReason: phase == SessionPhase.passwordNeeded
          ? reason
          : null,
      appConfig: config,
      updateAvailable:
          config != null &&
          compareVersions(_appVersion, config.latestVersion) < 0,
      canUsePin: _pinUsable && !_mustChangeOutstanding,
      syncNeedsPassword: _meta.sessionEnded,
      clockOffset: _clockOffset,
    );
  }

  /// Moves to [phase] (a new generation when [fresh]) and saves it.
  void _go(SessionPhase phase, {String? reason, bool fresh = false}) {
    if (fresh) _generation++;
    _markSeen();
    _meta = _meta.copyWith(phase: phase, passwordNeededReason: reason);
    state = _stateFor(phase, reason: reason);
    _persist();
  }

  /// Rebuilds the state in the same phase (e.g. a new clock offset).
  void _refreshState() =>
      state = _stateFor(state.phase, reason: state.passwordNeededReason);

  /// Runs store writes one after the other, in call order.
  Future<void> _serial(Future<void> Function() write) {
    final next = _storeQueue.then((_) => write());
    _storeQueue = next.catchError((Object e) {
      debugPrint('SessionStore write failed: $e');
    });
    return next;
  }

  void _persist() => unawaited(_persistNow());

  /// Saves the meta as it is now; completes when written (never throws).
  Future<void> _persistNow() {
    final meta = _meta;
    return _serial(() => _store.writeMeta(meta)).catchError((Object _) {});
  }

  /// Whose local data is on the phone: the signed-in FA, else the one saved
  /// at the last logout.
  PhoneOwner? get _owner => switch (_session) {
    final s? => PhoneOwner(
      faId: s.faId,
      code: s.fieldAssistant.code,
      name: s.fieldAssistant.name,
    ),
    null => _meta.lastOwner,
  };

  // -------------------------------------------------------------------------
  // Start.

  Future<void> _restore() async {
    final generation = _generation;
    try {
      final language = await _store.readLanguage();
      if (!_languagePicked) _language = language ?? Language.te;
      _session = await _store.readSession();
      _pin = await _store.readPin();
      _lastOnlineAt = await _store.readLastOnlineAt();
      _meta = await _store.readMeta();
    } on Object catch (e) {
      // An unreadable store (e.g. a keystore lost after a backup restore)
      // must never leave the app on the splash: sign in again. Local data
      // and the install ID stay (a read that failed once must not wipe).
      debugPrint('SessionStore read at start failed: $e');
      _session = null;
      _pin = null;
      _lastOnlineAt = null;
      _meta = SessionMeta.empty;
      if (_isCurrent(generation)) _go(SessionPhase.signedOut, fresh: true);
      return;
    }
    if (!_isCurrent(generation)) return;
    if (_meta.wipePending) {
      // HO removed the phone and the wipe did not finish: finish it before
      // routing anywhere.
      await _wipe();
      return;
    }
    final (phase, reason) = _routeSaved();
    _go(phase, reason: reason, fresh: true);
  }

  /// The phase for what the store holds (also after an update block lifts).
  (SessionPhase, String?) _routeSaved() {
    final saved = _meta;
    final blockedAt = saved.updateMinVersion;
    if (blockedAt != null && compareVersions(_appVersion, blockedAt) < 0) {
      return (SessionPhase.updateRequired, null);
    }
    _meta = saved.copyWith(updateMinVersion: null, updateFromHeartbeat: false);
    final session = _session;
    if (session == null) {
      return (
        saved.phase == SessionPhase.removed
            ? SessionPhase.removed
            : SessionPhase.signedOut,
        null,
      );
    }
    if (saved.phase == SessionPhase.mustChangePassword ||
        (session.mustChangePassword && !saved.cleanTokenPending)) {
      return (SessionPhase.mustChangePassword, null);
    }
    if (_graceOver) {
      return (SessionPhase.passwordNeeded, PasswordNeededReason.expired);
    }
    if (saved.phase == SessionPhase.passwordNeeded) {
      return (SessionPhase.passwordNeeded, saved.passwordNeededReason);
    }
    if (saved.sessionEnded) {
      return (SessionPhase.passwordNeeded, PasswordNeededReason.sessionEnded);
    }
    if (_pin == null) return (SessionPhase.setup, null);
    if (_pinLockedOut) {
      return (SessionPhase.passwordNeeded, PasswordNeededReason.lockedOut);
    }
    return (SessionPhase.locked, null);
  }

  /// After the restore: release settings, then the heartbeat. Both need
  /// network and are skipped quietly without it.
  Future<void> _startupChecks() async {
    try {
      await refreshAppConfig();
    } on Object catch (e) {
      debugPrint('app-config at start failed: $e');
    }
    try {
      await recheck();
    } on Object catch (e) {
      debugPrint('heartbeat at start failed: $e');
    }
  }

  void _expect(Set<SessionPhase> phases, String action) {
    if (!phases.contains(state.phase)) {
      throw StateError('$action is not allowed in ${state.phase.name}');
    }
  }

  // -------------------------------------------------------------------------
  // Release settings and heartbeat.

  /// Reads `GET /v1/auth/app-config?app=fa`. Below `min_version`: pushes the
  /// outbox (when online) and blocks ([SessionPhase.updateRequired]). When a
  /// block saved earlier no longer applies, routes as at start. Throws
  /// `ApiError` (e.g. `network`); a saved block then stays.
  Future<void> refreshAppConfig() async {
    final config = await _auth.getAppConfig();
    await restored;
    if (!ref.mounted) return;
    _appConfig = config;
    if (compareVersions(_appVersion, config.minVersion) < 0) {
      return _blockForUpdate(config.minVersion);
    }
    // A block from a heartbeat is fresher than this answer (cacheable for 5
    // minutes): only a heartbeat lifts it.
    final saved = _meta.updateMinVersion;
    final heartbeatBlock =
        _meta.updateFromHeartbeat &&
        saved != null &&
        compareVersions(_appVersion, saved) < 0;
    if (state.phase == SessionPhase.updateRequired && !heartbeatBlock) {
      _liftUpdateBlock();
    } else {
      _refreshState();
    }
  }

  /// The update block no longer applies: route as at start.
  void _liftUpdateBlock() {
    if (_wiping != null || _meta.wipePending) return;
    _meta = _meta.copyWith(updateMinVersion: null, updateFromHeartbeat: false);
    final (phase, reason) = _routeSaved();
    _go(phase, reason: reason, fresh: true);
  }

  /// The heartbeat (`PUT /v1/fa/devices/me`): on `wipe` wipes the phone
  /// ([SessionPhase.removed]); on `update_required` pushes the outbox first,
  /// then blocks; otherwise lifts an update block it set earlier; always
  /// keeps the server clock offset. The server's verdict (wipe, block)
  /// applies even when the FA moved on meanwhile (a logout, another block),
  /// unless another sign-in replaced the one the heartbeat was sent with.
  /// Concurrent calls share one request. Retries a wipe that did not finish.
  /// Does nothing else without a live session (signed out, temporary
  /// password, or a session that ended). Throws `ApiError` (e.g.
  /// `network`); the phase is unchanged then.
  Future<void> recheck() {
    final running = _rechecking;
    if (running != null && running.generation == _generation) {
      return running.future;
    }
    late final Future<void> future;
    future = _recheck(_generation).whenComplete(() {
      if (identical(_rechecking?.future, future)) _rechecking = null;
    });
    _rechecking = (generation: _generation, future: future);
    return future;
  }

  Future<void> _recheck(int generation) async {
    if (_meta.wipePending) return _wipe();
    if (_session == null || _meta.sessionEnded) return;
    // A password change whose clean token is still owed, or one sent before
    // a restart whose outcome is unknown: refresh and read the new flag.
    if (_meta.cleanTokenPending ||
        (_meta.passwordChangeSent &&
            state.phase == SessionPhase.mustChangePassword)) {
      await _refreshForCleanToken();
    }
    if (!_isCurrent(generation)) return;
    final session = _session;
    if (session == null || _meta.sessionEnded) return;
    // A must-change token gets 403 everywhere but the password change.
    if (session.mustChangePassword ||
        state.phase == SessionPhase.mustChangePassword) {
      return;
    }
    final key = session.signInKey;
    final DeviceStatus status;
    try {
      status = await _auth.heartbeat(appVersion: _appVersion);
    } on ApiError catch (e) {
      if (e.isDeviceRevoked && ref.mounted && _sameSignIn(key)) {
        return _wipe();
      }
      rethrow;
    }
    if (!ref.mounted) return;
    if (status.wipe && _sameSignIn(key)) return _wipe();
    if (status.updateRequired) {
      return _blockForUpdate(status.minVersion, fromHeartbeat: true);
    }
    if (!_isCurrent(generation)) return;
    _clockOffset = status.serverTime.difference(_now);
    await _reloadLastOnline();
    if (!_isCurrent(generation)) return;
    if (state.phase == SessionPhase.updateRequired) {
      final config = _appConfig;
      if (config == null ||
          compareVersions(_appVersion, config.minVersion) >= 0) {
        return _liftUpdateBlock();
      }
    }
    _refreshState();
  }

  /// True when the sign-in [key] named is still the one on the phone, or
  /// none is (signed out since): a server verdict about it applies.
  bool _sameSignIn(String? key) {
    final current = _session;
    return current == null ||
        key == null ||
        current.signInKey == null ||
        current.signInKey == key;
  }

  /// Pushes the outbox (best effort, never drops it), then blocks for the
  /// update. A wipe meanwhile wins. [fromHeartbeat]: the block came from a
  /// heartbeat (see [SessionMeta.updateFromHeartbeat]). An existing block
  /// with a higher `min_version` stays.
  Future<void> _blockForUpdate(
    String minVersion, {
    bool fromHeartbeat = false,
  }) async {
    if (state.phase == SessionPhase.removed ||
        _wiping != null ||
        _meta.wipePending) {
      return;
    }
    if (_session != null) {
      try {
        await _guard.pushPending();
      } on Object catch (e) {
        debugPrint('pushPending before the update block failed: $e');
      }
    }
    if (!ref.mounted || state.phase == SessionPhase.removed) return;
    if (_wiping != null || _meta.wipePending) return;
    final current = _meta.updateMinVersion;
    final keep =
        state.phase == SessionPhase.updateRequired &&
        current != null &&
        compareVersions(current, minVersion) > 0;
    if (!keep) {
      _meta = _meta.copyWith(
        updateMinVersion: minVersion,
        updateFromHeartbeat: fromHeartbeat,
      );
    }
    _go(SessionPhase.updateRequired, fresh: true);
  }

  // -------------------------------------------------------------------------
  // Login and password.

  /// Logs in with the login ID from HO and the password (A1): from
  /// [SessionPhase.signedOut], [SessionPhase.passwordNeeded] or
  /// [SessionPhase.removed] to [SessionPhase.mustChangePassword] (temporary
  /// password), [SessionPhase.setup] (no PIN yet) or [SessionPhase.active].
  ///
  /// The same FA keeps the PIN set earlier (a locked-out PIN is dropped and
  /// set again). When another FA's data is on the phone it is deleted after
  /// the login succeeds; if they have unsynced records this throws
  /// [OtherFaOnPhone] first (nothing is sent), and the screen asks before
  /// calling again with [replaceOtherFa].
  ///
  /// When the other FA's data cannot be counted, nothing is sent and the
  /// error that count threw is rethrown ("try again"): the login never
  /// deletes records it could not count. When it cannot be deleted after the
  /// login, the new login is signed out again and [LocalDataWipeFailed] is
  /// thrown.
  ///
  /// Throws `ApiError` `unauthorized` (one message for a wrong ID or
  /// password), `temp_password_expired` ("call HO for a new one"),
  /// `device_revoked` (the phone is wiped first), `rate_limited`, `network`.
  Future<void> login(
    String code,
    String password, {
    bool replaceOtherFa = false,
  }) async {
    _expect({
      SessionPhase.signedOut,
      SessionPhase.passwordNeeded,
      SessionPhase.removed,
    }, 'login');
    final generation = _generation;
    final loginId = code.trim();
    final previous = _owner;
    if (previous != null &&
        previous.code.toUpperCase() != loginId.toUpperCase() &&
        !replaceOtherFa) {
      // Throws when they cannot be counted: nothing is deleted unasked.
      final unsynced = await _guard.pendingCount();
      if (unsynced > 0) {
        throw OtherFaOnPhone(
          previousCode: previous.code,
          previousName: previous.name,
          unsynced: unsynced,
        );
      }
    }
    final deviceKey = await _store.deviceKey();
    if (!_isCurrent(generation)) return;
    final FaSession session;
    try {
      session = await _auth.login(
        code: loginId,
        password: password,
        device: DeviceInfo(deviceKey: deviceKey, appVersion: _appVersion),
      );
    } on ApiError catch (e) {
      if (e.isDeviceRevoked && _isCurrent(generation)) await _wipe();
      rethrow;
    }
    if (!ref.mounted) return;
    if (generation != _generation) return _dropStaleLogin(session);

    final faId = session.fieldAssistant.id;
    if (previous != null && previous.faId != faId) {
      // Another FA's farmers and outbox must not reach this FA's sync: if
      // they cannot be deleted, this login does not go ahead.
      try {
        await _guard.wipe();
      } on Object catch (e) {
        debugPrint('wiping the previous FA data failed: $e');
        await _abortLogin(previous);
        throw LocalDataWipeFailed(e);
      }
      await _serial(_store.clearPin).catchError((Object _) {});
      _pin = null;
    } else if (_pinLockedOut) {
      await _serial(_store.clearPin).catchError((Object _) {});
      _pin = null;
    } else if (_pin case final pin? when pin.failedAttempts > 0) {
      // The password proves who it is: the wrong tries start over.
      final reset = pin.withFailedAttempts(0);
      await _serial(() => _store.writePin(reset)).catchError((Object _) {});
      _pin = reset;
    }
    final now = _now;
    await _serial(() => _store.writeLastOnlineAt(now))
        .catchError((Object _) {});
    StoredSession? stored;
    try {
      stored = await _store.readSession();
    } on Object catch (e) {
      debugPrint('SessionStore.readSession after login failed: $e');
    }
    if (!ref.mounted) return;
    if (generation != _generation) return _dropStaleLogin(session);
    _session = stored ?? StoredSession.fromLogin(session);
    _lastOnlineAt = now;
    _meta = SessionMeta(
      lastOwner: PhoneOwner(
        faId: faId,
        code: session.fieldAssistant.code,
        name: session.fieldAssistant.name,
      ),
    );
    _go(
      session.mustChangePassword
          ? SessionPhase.mustChangePassword
          : _pin == null
          ? SessionPhase.setup
          : SessionPhase.active,
      fresh: true,
    );
    if (!session.mustChangePassword) {
      unawaited(
        recheck().catchError((Object e) {
          debugPrint('heartbeat after login failed: $e');
        }),
      );
    }
  }

  /// Signs a login out again whose FA may not use the phone yet ([previous]'s
  /// data is still on it): signed out, [previous] still the owner.
  Future<void> _abortLogin(PhoneOwner previous) async {
    try {
      await _serial(_auth.logout);
    } on Object catch (e) {
      debugPrint('signing the new login out failed: $e');
    }
    await _serial(_store.clear).catchError((Object _) {});
    _session = null;
    _pin = null;
    _lastOnlineAt = null;
    _meta = SessionMeta(lastOwner: previous);
    if (ref.mounted) _go(SessionPhase.signedOut, fresh: true);
  }

  /// The FA moved on (logout, wipe, update block) while [session]'s login
  /// was in flight and the repository saved it anyway: sign it out again
  /// (unless a newer login replaced it), so a restart cannot open a session
  /// the app never showed.
  Future<void> _dropStaleLogin(FaSession session) async {
    try {
      final saved = await _store.readSession();
      if (saved?.tokens == session.tokens) {
        await _serial(_auth.logout);
        // logout cleared the saved phase too (e.g. removed): write it again.
        if (ref.mounted) _persist();
      }
    } on Object catch (e) {
      debugPrint('Dropping a stale login failed: $e');
    }
  }

  /// Sets the FA's own password (A1c; also Me's Change password):
  /// [SessionPhase.mustChangePassword] -> [SessionPhase.setup] (or
  /// [SessionPhase.active] when a PIN is already set). Checks [PasswordCheck]
  /// first, then `POST /v1/fa/me/password`, then (first login only)
  /// refreshes for a token without the must-change flag. A failed refresh
  /// (offline) is retried by [recheck] and on the next
  /// `password_change_required`; the FA is not asked again. When the answer
  /// to the change itself is lost (offline, or the app killed), the next
  /// [recheck] finds out from a refresh whether it went through.
  ///
  /// Throws `ApiError` `validation_failed` (`fields.new_password`, checked
  /// on the phone first; `fields.current_password` for a wrong current
  /// password), `temp_password_expired`, `rate_limited`, `network`. A 401
  /// `unauthorized` means the session ended (the hook moves the phase on).
  Future<void> changePassword(String current, String next) async {
    _expect({
      SessionPhase.mustChangePassword,
      SessionPhase.active,
    }, 'changePassword');
    final check = PasswordCheck(
      next,
      current: current,
      loginId: _session?.fieldAssistant.code,
    );
    if (check.problem case final problem?) {
      throw ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'new_password $problem',
        status: 400,
        details: {
          'fields': {'new_password': problem},
        },
      );
    }
    final generation = _generation;
    final firstLogin = state.phase == SessionPhase.mustChangePassword;
    if (firstLogin) {
      // Saved before the call: if the answer is lost, a restart finds out.
      _meta = _meta.copyWith(passwordChangeSent: true);
      await _persistNow();
    }
    try {
      await _auth.changePassword(currentPassword: current, newPassword: next);
    } on ApiError catch (e) {
      // Refused by the server: it did not happen. A lost answer (network)
      // may have, so the marker stays for the next recheck.
      if (firstLogin && !e.isNetwork && _isCurrent(generation)) {
        _meta = _meta.copyWith(passwordChangeSent: false);
        _persist();
      }
      rethrow;
    }
    if (!_isCurrent(generation) || !firstLogin) return;
    _meta = _meta.copyWith(cleanTokenPending: true, passwordChangeSent: false);
    _persist();
    await _refreshForCleanToken();
    if (!_isCurrent(generation)) return;
    if (state.phase == SessionPhase.mustChangePassword) {
      _go(_pin == null ? SessionPhase.setup : SessionPhase.active);
    }
  }

  /// `POST /v1/auth/refresh` after the password change (or to find out
  /// whether one sent before a restart went through). True when the session
  /// now has a clean token; failures are left to the hook (a 401) or a later
  /// retry (offline). Concurrent calls share one refresh.
  ///
  /// The repository saves the rotated pair with the must-change flag the
  /// new token carries; this only reads it back (it never writes tokens,
  /// which could overwrite a newer pair from the HTTP layer).
  Future<bool> _refreshForCleanToken() {
    final running = _cleanRefresh;
    if (running != null && running.generation == _generation) {
      return running.future;
    }
    late final Future<bool> future;
    future = _doRefreshForCleanToken(_generation).whenComplete(() {
      if (identical(_cleanRefresh?.future, future)) _cleanRefresh = null;
    });
    _cleanRefresh = (generation: _generation, future: future);
    return future;
  }

  Future<bool> _doRefreshForCleanToken(int generation) async {
    try {
      await _auth.refreshSession();
    } on ApiError catch (e) {
      debugPrint('refresh after the password change failed: ${e.code}');
      return false;
    }
    if (!_isCurrent(generation)) return false;
    StoredSession? stored;
    try {
      stored = await _store.readSession();
    } on Object catch (e) {
      debugPrint('reading the refreshed session failed: $e');
    }
    await _reloadLastOnline();
    if (!_isCurrent(generation)) return false;
    if (stored != null) _session = stored;
    if (_session?.mustChangePassword ?? true) {
      // The new token still has the flag: a change sent before a restart
      // did not go through (ask again), or one that did is not on the
      // token yet (keep [SessionMeta.cleanTokenPending] and retry later).
      if (_meta.passwordChangeSent && !_meta.cleanTokenPending) {
        _meta = _meta.copyWith(passwordChangeSent: false);
        _persist();
      }
      _refreshState();
      return false;
    }
    _meta = _meta.copyWith(cleanTokenPending: false, passwordChangeSent: false);
    if (state.phase == SessionPhase.mustChangePassword) {
      _go(_pin == null ? SessionPhase.setup : SessionPhase.active);
    } else {
      _go(state.phase, reason: state.passwordNeededReason);
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // Setup, PIN and lock.

  /// Sets the app language (A1d step 1, Me). Saved on the phone only (the
  /// FA profile has no language field); allowed in every phase.
  Future<void> setLanguage(Language language) async {
    _languagePicked = true;
    _language = language;
    state = _stateFor(state.phase, reason: state.passwordNeededReason);
    await _serial(() => _store.writeLanguage(language));
  }

  /// Sets the PIN (A1d step 2): [SessionPhase.setup] -> [SessionPhase.active].
  /// The screen asks for it twice; this checks [PinLock.problem] again.
  /// Throws `ApiError` `validation_failed` (`fields.pin` = a [PinProblem]
  /// name) without saving anything.
  Future<void> setPin(String pin) async {
    _expect({SessionPhase.setup}, 'setPin');
    final generation = _generation;
    final record = _newPin(pin);
    await _serial(() => _store.writePin(record));
    if (!_isCurrent(generation)) return;
    _pin = record;
    _go(SessionPhase.active);
  }

  PinRecord _newPin(String pin) {
    if (PinLock.problem(pin, length: _policy.pinLength) case final problem?) {
      throw ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'pin is ${problem.name}',
        status: 400,
        details: {
          'fields': {'pin': problem.name},
        },
      );
    }
    return _pinLock.create(pin);
  }

  /// Unlocks with the PIN (A1b), offline: [SessionPhase.locked] ->
  /// [SessionPhase.active]. True when unlocked.
  ///
  /// False otherwise, and then: a wrong PIN leaves [SessionPhase.locked] with
  /// [SessionState.pinAttemptsLeft] one lower; the last wrong try, or a
  /// grace that ended, moves to [SessionPhase.passwordNeeded]
  /// ([PasswordNeededReason.lockedOut] / [PasswordNeededReason.expired]).
  /// Unsynced records are always kept.
  Future<bool> unlock(String pin) async {
    _expect({SessionPhase.locked}, 'unlock');
    return _withPin(() async {
      if (state.phase != SessionPhase.locked) return false;
      final verdict = await _checkPin(pin);
      if (verdict == PinVerdict.correct) _go(SessionPhase.active);
      return verdict == PinVerdict.correct;
    });
  }

  /// Changes the PIN from Me (A1d again): checks [current] like [unlock]
  /// (wrong tries count; the last one locks out), then saves [next]. True
  /// when changed; false for a wrong [current]. Throws `ApiError`
  /// `validation_failed` for a weak [next] before checking anything.
  Future<bool> changePin(String current, String next) async {
    _expect({SessionPhase.active}, 'changePin');
    final record = _newPin(next);
    return _withPin(() async {
      final generation = _generation;
      final verdict = await _checkPin(current);
      if (verdict != PinVerdict.correct || !_isCurrent(generation)) {
        return false;
      }
      await _serial(() => _store.writePin(record));
      if (!_isCurrent(generation)) return false;
      _pin = record;
      _refreshState();
      return true;
    });
  }

  /// Reads the last online contact again: the HTTP layer's refreshes move
  /// it forward without telling the session.
  Future<void> _reloadLastOnline() async {
    try {
      final saved = await _store.readLastOnlineAt();
      final known = _lastOnlineAt;
      if (saved != null && (known == null || saved.isAfter(known))) {
        _lastOnlineAt = saved;
      }
    } on Object catch (e) {
      debugPrint('SessionStore.readLastOnlineAt failed: $e');
    }
  }

  /// PIN checks one at a time (a double tap must not lose a wrong try).
  Future<bool> _withPin(Future<bool> Function() check) {
    final result = _pinQueue.then((_) => check());
    _pinQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Checks [entered], saves the count and moves to
  /// [SessionPhase.passwordNeeded] when the grace ended or the tries ran
  /// out; a wrong try leaves the phase with one try fewer.
  Future<PinVerdict> _checkPin(String entered) async {
    final generation = _generation;
    await _reloadLastOnline();
    if (!_isCurrent(generation)) return PinVerdict.lockedOut;
    final pin = _pin;
    if (_graceOver) {
      _go(SessionPhase.passwordNeeded, reason: PasswordNeededReason.expired);
      return PinVerdict.lockedOut;
    }
    if (pin == null) {
      _go(SessionPhase.setup);
      return PinVerdict.lockedOut;
    }
    final result = _pinLock.check(
      pin,
      entered,
      maxAttempts: _policy.pinMaxAttempts,
    );
    // Counted in memory first: a failed store write must not give a free
    // try.
    _pin = result.record;
    _markSeen();
    if (result.record != pin) {
      try {
        await _serial(() => _store.writePin(result.record));
      } on Object catch (e) {
        debugPrint('saving the PIN tries failed: $e');
      }
    }
    if (!_isCurrent(generation)) return PinVerdict.lockedOut;
    switch (result.verdict) {
      case PinVerdict.correct:
        break;
      case PinVerdict.wrong:
        _refreshState();
      case PinVerdict.lockedOut:
        _go(
          SessionPhase.passwordNeeded,
          reason: PasswordNeededReason.lockedOut,
        );
    }
    return result.verdict;
  }

  /// Locks the app ([SessionPhase.active] -> [SessionPhase.locked]), e.g.
  /// when it comes back after [autoLockAfter] in the background (the app
  /// layer calls it). Goes to [SessionPhase.passwordNeeded] instead when the
  /// server session ended meanwhile, and (a moment later, once the store is
  /// read) when the grace ended. Elsewhere a no-op.
  void lock() {
    if (state.phase != SessionPhase.active) return;
    if (_meta.sessionEnded) {
      _go(
        SessionPhase.passwordNeeded,
        reason: PasswordNeededReason.sessionEnded,
      );
    } else if (_pin != null) {
      _go(SessionPhase.locked);
    } else {
      return;
    }
    // A refresh by the HTTP layer may have moved the grace on: check it
    // against the store, not the copy here.
    final generation = _generation;
    unawaited(
      _reloadLastOnline().then((_) {
        if (!_isCurrent(generation) || !_graceOver) return;
        final s = state;
        if (s.phase == SessionPhase.locked ||
            s.passwordNeededReason == PasswordNeededReason.sessionEnded) {
          _go(
            SessionPhase.passwordNeeded,
            reason: PasswordNeededReason.expired,
          );
        }
      }),
    );
  }

  /// "Use password instead" (A1b): [SessionPhase.locked] ->
  /// [SessionPhase.passwordNeeded] (no reason). The PIN, local data and
  /// outbox stay; [usePin] goes back.
  void usePassword() {
    _expect({SessionPhase.locked}, 'usePassword');
    _go(SessionPhase.passwordNeeded);
  }

  /// "Enter PIN" from [SessionPhase.passwordNeeded] when
  /// [SessionState.canUsePin] (e.g. the "Session ended" card): back to
  /// [SessionPhase.locked].
  void usePin() {
    _expect({SessionPhase.passwordNeeded}, 'usePin');
    if (!state.canUsePin) throw StateError('the PIN cannot be used now');
    _go(SessionPhase.locked);
  }

  /// "Log in with a new password" on the removed screen (A12):
  /// [SessionPhase.removed] -> [SessionPhase.signedOut].
  void startOver() {
    _expect({SessionPhase.removed}, 'startOver');
    _go(SessionPhase.signedOut);
  }

  // -------------------------------------------------------------------------
  // Logout and wipe.

  /// Records on this phone not yet synced (outbox rows and photos). Me asks
  /// before [logout]: "3 records are not synced yet. Sync first." Throws
  /// what the local data threw when they cannot be counted (never "0").
  Future<int> unsyncedCount() => _guard.pendingCount();

  /// Logs out (Me): to [SessionPhase.signedOut] from any phase. Revokes the
  /// session on the server (best effort, also offline) and forgets tokens,
  /// PIN and the grace on the phone. Returns the unsynced records counted
  /// first ([unsyncedCount]).
  ///
  /// The outbox and the saved farmers stay ("they stay on this phone and go
  /// up when you log in again"), unless [discardUnsynced] (the FA confirmed
  /// deleting them). The phone remembers whose they are, so another FA's
  /// login asks first ([OtherFaOnPhone]).
  Future<int> logout({bool discardUnsynced = false}) async {
    var unsynced = 0;
    try {
      unsynced = await _guard.pendingCount();
    } on Object catch (e) {
      debugPrint('pendingCount at logout failed: $e');
    }
    final generation = ++_generation;
    final owner = _owner;
    try {
      await _serial(_auth.logout);
    } on Object catch (e) {
      debugPrint('logout failed, signing out anyway: $e');
    }
    // The repository clears the store; make sure even if it did not.
    await _serial(_store.clear).catchError((Object _) {});
    if (discardUnsynced) {
      try {
        await _guard.wipe();
      } on Object catch (e) {
        debugPrint('wiping local data at logout failed: $e');
      }
    }
    _session = null;
    _pin = null;
    _lastOnlineAt = null;
    _meta = SessionMeta(lastOwner: discardUnsynced ? null : owner);
    if (ref.mounted && generation == _generation) {
      _go(SessionPhase.signedOut);
    }
    return unsynced;
  }

  /// HO removed the phone (`device_revoked`, heartbeat `wipe`): delete local
  /// data, tokens, PIN and the install ID, then [SessionPhase.removed].
  /// Many reports together wipe once.
  ///
  /// [SessionMeta.wipePending] is saved first and cleared only once the
  /// local data is gone. Until then the app shows the splash
  /// ([SessionPhase.restoring]: no removed screen, no sign-in over the old
  /// data) and retries at the next start and the next [recheck] (resume).
  Future<void> _wipe() => _wiping ??= _doWipe();

  Future<void> _doWipe() async {
    try {
      _generation++;
      _session = null;
      _pin = null;
      _lastOnlineAt = null;
      _meta = const SessionMeta(wipePending: true);
      if (ref.mounted) state = _stateFor(SessionPhase.restoring);
      await _persistNow();
      try {
        await _serial(() => _store.clear(wipeDeviceKey: true));
        await _serial(_store.resetDeviceKey);
      } on Object catch (e) {
        debugPrint('clearing the session store failed: $e');
      }
      try {
        await _guard.wipe();
      } on Object catch (e) {
        debugPrint('LocalDataGuard.wipe failed, retried later: $e');
        return;
      }
      _meta = SessionMeta.empty;
      if (ref.mounted) _go(SessionPhase.removed, fresh: true);
    } finally {
      _wiping = null;
    }
  }

  // -------------------------------------------------------------------------
  // Failures reported by the data layer.

  /// A failed call reported through [AuthFailureHook] (see the plan's error
  /// table):
  ///
  /// - `device_revoked`: wipe, [SessionPhase.removed];
  /// - `password_change_required`: back to [SessionPhase.mustChangePassword]
  ///   (or, right after a password change, retry the clean-token refresh);
  /// - `temp_password_expired`: [SessionPhase.passwordNeeded] with
  ///   [PasswordNeededReason.tempPasswordExpired];
  /// - any other 401 (refresh failed, `refresh_reused`, expired refresh):
  ///   the server session is over. In [SessionPhase.active] the FA keeps
  ///   working offline ([SessionState.syncNeedsPassword]) until the next
  ///   lock; from [SessionPhase.locked] or [SessionPhase.setup] it is
  ///   [SessionPhase.passwordNeeded] with [PasswordNeededReason.sessionEnded]
  ///   (the PIN still opens local data within the grace).
  ///
  /// Calls made with another sign-in (in flight across a logout and a new
  /// login, of another FA or the same one) are ignored.
  void _onAuthFailure(ApiError error, {String? faId, String? sessionKey}) {
    if (!_concernsCurrent(faId, sessionKey)) return;
    if (AuthFailureHook.isDeviceRevoked(error)) {
      unawaited(_wipe());
      return;
    }
    if (_session == null || _wiping != null || _meta.wipePending) return;
    final phase = state.phase;
    if (phase == SessionPhase.removed ||
        phase == SessionPhase.signedOut ||
        phase == SessionPhase.restoring) {
      return;
    }
    if (AuthFailureHook.needsPasswordChange(error)) {
      if (_meta.cleanTokenPending) {
        unawaited(_refreshForCleanToken());
      } else if (phase == SessionPhase.setup ||
          phase == SessionPhase.locked ||
          phase == SessionPhase.active) {
        _go(SessionPhase.mustChangePassword, fresh: true);
      }
      return;
    }
    if (!AuthFailureHook.endsSession(error)) return;
    const signedInPhases = {
      SessionPhase.mustChangePassword,
      SessionPhase.setup,
      SessionPhase.locked,
      SessionPhase.active,
    };
    if (error.code == ApiErrorCode.tempPasswordExpired) {
      if (signedInPhases.contains(phase)) {
        _go(
          SessionPhase.passwordNeeded,
          reason: PasswordNeededReason.tempPasswordExpired,
          fresh: true,
        );
      }
      return;
    }
    // Already known, or not signed in far enough to matter (a wrong
    // password on the login screen is the screen's; a wrong current
    // password on the change is a 400, not a 401).
    if (_meta.sessionEnded || !signedInPhases.contains(phase)) return;
    _meta = _meta.copyWith(sessionEnded: true);
    if (phase == SessionPhase.active) {
      _refreshState();
      _persist();
    } else {
      _go(
        SessionPhase.passwordNeeded,
        reason: PasswordNeededReason.sessionEnded,
        fresh: true,
      );
    }
  }

  /// True when a failure reported for [sessionKey] / [faId] is about the
  /// sign-in on the phone (or none is signed in).
  bool _concernsCurrent(String? faId, String? sessionKey) {
    final current = _session;
    if (current == null) return true;
    final key = current.signInKey;
    if (sessionKey != null && key != null) return sessionKey == key;
    return faId == null || faId == current.faId;
  }
}
