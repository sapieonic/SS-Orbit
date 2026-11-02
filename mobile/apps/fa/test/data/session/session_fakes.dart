/// Fakes for the session tests: an auth repository that behaves like the
/// real one towards the store and the auth-failure hook (and can fail, hold
/// or count calls), a local-data guard that records what the session asks
/// of it, and a bed that starts the app (a container) over shared fakes, so
/// each [SessionBed.start] is an app restart.
library;

import 'dart:async';

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/data/providers.dart';
import 'package:fa/src/data/repositories/fa_auth_repository.dart';
import 'package:fa/src/data/session/auth_failures.dart';
import 'package:fa/src/data/session/session_controller.dart';
import 'package:fa/src/data/session/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';

/// 2 Nov 2026, 10:00 IST.
final testStart = DateTime.utc(2026, 11, 2, 4, 30);

/// Suresh Kumar's login.
const sureshCode = 'FA-KDP-014';

/// Suresh's password.
const sureshPassword = 'orbit2026';

/// A login with a temporary password (must change).
const tempCode = 'FA-KDP-099';

/// Its temporary password.
const tempPassword = 'temp1234';

/// A login whose temporary password expired.
const expiredCode = 'FA-KDP-077';

/// Another FA (Chevella).
const otherCode = 'FA-CVL-002';

/// A PIN that is not weak.
const goodPin = '2580';

/// A wrong PIN.
const wrongPin = '1357';

/// Lets queued microtasks and unawaited work run.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A 401 the refresh could not fix.
const sessionEnded = ApiError(
  code: ApiErrorCode.unauthorized,
  message: 'session has ended',
  status: 401,
);

/// The refresh token was used twice.
const refreshReused = ApiError(
  code: ApiErrorCode.refreshReused,
  message: 'refresh token reused',
  status: 401,
);

/// HO removed this phone.
const deviceRevoked = ApiError(
  code: ApiErrorCode.deviceRevoked,
  message: 'revoked',
  status: 401,
);

/// The token still has the must-change flag.
const passwordChangeRequired = ApiError(
  code: ApiErrorCode.passwordChangeRequired,
  message: 'change your password first',
  status: 403,
);

/// The backend's answer to a wrong current password on the change.
const wrongCurrentPassword = ApiError(
  code: ApiErrorCode.validationFailed,
  message: 'current_password is not correct',
  status: 400,
  details: {
    'fields': {'current_password': 'is not correct'},
  },
);

/// The temporary password is over 72 hours old.
const tempPasswordExpired = ApiError(
  code: ApiErrorCode.tempPasswordExpired,
  message: 'temporary password expired',
  status: 401,
);

/// The FA profile for [code].
FieldAssistant faFor(String code) => FieldAssistant(
  id: 'fa-${code.toLowerCase()}',
  code: code,
  name: switch (code) {
    sureshCode => 'Suresh Kumar',
    otherCode => 'Mahesh B',
    _ => 'Test FA',
  },
  nameTe: code == sureshCode ? 'సురేష్ కుమార్' : null,
  phone: '+919848012345',
  level: AreaLevel.village,
  languages: const ['te', 'en'],
  workingHours: null,
  photoKey: null,
  status: FaStatus.active,
  mustChangePassword: code == tempCode,
  lastLoginAt: null,
  lastSyncAt: null,
  appVersion: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// An [FaAuthRepository] over the [store] like the real one: login and
/// refresh save to the store (and the last online contact), logout clears
/// it, signed-in calls report failures to [hook].
final class FakeAuth implements FaAuthRepository {
  /// Creates the fake.
  FakeAuth({required this.store, required this.clock, required this.hook});

  /// The session store it writes.
  final SessionStore store;

  /// Time source.
  final FixedClock clock;

  /// Where failures of signed-in calls go.
  final AuthFailureHook hook;

  /// Passwords by login ID (upper case).
  final passwords = <String, String>{
    sureshCode: sureshPassword,
    tempCode: tempPassword,
    expiredCode: 'temp5678',
    otherCode: 'chevella1',
  };

  /// Every call so far, by method name.
  final calls = <String>[];

  /// Device keys sent with each login.
  final deviceKeys = <String>[];

  final _failures = <String, List<ApiError>>{};
  final _holds = <String, List<Completer<void>>>{};
  var _tokens = 0;
  final _changed = <String>{};

  /// The next answer to [heartbeat].
  bool heartbeatWipe = false;

  /// The heartbeat says the app is too old.
  bool heartbeatUpdate = false;

  /// What the heartbeat sends as `server_time` minus the clock.
  Duration serverAhead = Duration.zero;

  /// `min_version` in app-config and heartbeat.
  String minVersion = '0.0.0';

  /// `latest_version` in app-config.
  String latestVersion = '0.1.0';

  /// Every call fails with `network`.
  bool offline = false;

  /// The next [call] throws [error] (after counting it).
  void failNext(String call, ApiError error) =>
      _failures.putIfAbsent(call, () => []).add(error);

  /// The next [call] is sent at once (counted, with the session it starts
  /// with), but the server answers only when the returned completer
  /// completes: what the answer writes to the store (a login's session, a
  /// refresh's pair) is written then, as a real repository does.
  Completer<void> holdNext(String call) {
    final gate = Completer<void>();
    _holds.putIfAbsent(call, () => []).add(gate);
    return gate;
  }

  /// The server handles the next [call], but its answer never arrives: the
  /// call throws `network` after the server did the work.
  void loseNextAnswer(String call) => _lost.add(call);

  final _lost = <String>{};

  /// How many times [call] was made.
  int count(String call) => calls.where((c) => c == call).length;

  Future<T> _run<T>(
    String call,
    Future<T> Function(StoredSession? sent) body, {
    bool signedIn = true,
  }) async {
    calls.add(call);
    final sent = await store.readSession();
    final gate = _take(_holds, call);
    final failure = _take(_failures, call);
    try {
      if (gate != null) await gate.future;
      if (failure != null) throw failure;
      if (offline) throw const ApiError.network();
      final result = await body(sent);
      if (_lost.remove(call)) throw const ApiError.network();
      return result;
    } on ApiError catch (e) {
      if (signedIn) {
        hook.report(e, faId: sent?.faId, sessionKey: sent?.signInKey);
      }
      rethrow;
    }
  }

  static V? _take<V extends Object>(Map<String, List<V>> next, String call) {
    final queue = next[call];
    if (queue == null || queue.isEmpty) return null;
    return queue.removeAt(0);
  }

  TokenPair _newTokens() {
    _tokens++;
    final now = clock.now();
    return TokenPair(
      accessToken: 'access-$_tokens',
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      refreshToken: 'refresh-$_tokens',
      refreshExpiresAt: now.add(const Duration(days: 30)),
    );
  }

  static const _unauthorized = ApiError(
    code: ApiErrorCode.unauthorized,
    message: 'wrong login ID or password',
    status: 401,
  );

  @override
  Future<AppConfig> getAppConfig() => _run(
    'getAppConfig',
    (_) async => AppConfig(
      app: 'fa',
      minVersion: minVersion,
      latestVersion: latestVersion,
      storeUrl: 'https://play.google.com/store/apps/details?id=fa',
      flags: const {},
    ),
    signedIn: false,
  );

  @override
  Future<FaSession> login({
    required String code,
    required String password,
    required DeviceInfo device,
  }) => _run('login', (_) async {
    deviceKeys.add(device.deviceKey);
    final id = code.trim().toUpperCase();
    if (id == expiredCode && passwords[id] == password) {
      throw tempPasswordExpired;
    }
    if (passwords[id] != password) throw _unauthorized;
    final fa = faFor(id);
    final session = FaSession(
      tokens: _newTokens(),
      deviceId: 'device-${device.deviceKey}',
      fieldAssistant: fa,
      mustChangePassword: id == tempCode && !_changed.contains(id),
      offlinePolicy: OfflinePolicy.standard,
    );
    await store.writeSession(StoredSession.fromLogin(session));
    await store.writeLastOnlineAt(clock.now());
    return session;
  }, signedIn: false);

  @override
  Future<TokenPair> refreshSession() => _run('refreshSession', (_) async {
    final saved = await store.readSession();
    if (saved == null) throw _unauthorized;
    final tokens = _newTokens();
    await store.writeSession(
      // The flag the new token carries, as the real repository saves it.
      saved.withTokens(
        tokens,
        mustChangePassword:
            saved.mustChangePassword &&
            !_changed.contains(saved.fieldAssistant.code),
      ),
    );
    await store.writeLastOnlineAt(clock.now());
    return tokens;
  });

  @override
  Future<void> logout() async {
    calls.add('logout');
    await store.clear();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _run('changePassword', (_) async {
    final code = (await store.readSession())!.fieldAssistant.code;
    // Like the backend: a wrong current password is a 400, not a 401.
    if (passwords[code] != currentPassword) throw wrongCurrentPassword;
    passwords[code] = newPassword;
    _changed.add(code);
  });

  @override
  Future<DeviceStatus> heartbeat({
    String? model,
    String? osVersion,
    String? appVersion,
    String? pushToken,
  }) => _run('heartbeat', (sent) async {
    // Answered for the token the request was sent with.
    final saved = sent;
    if (saved == null) throw _unauthorized;
    return DeviceStatus(
      deviceId: saved.deviceId,
      wipe: heartbeatWipe,
      serverTime: clock.now().add(serverAhead),
      minVersion: minVersion,
      updateRequired: heartbeatUpdate,
    );
  });
}

/// A [LocalDataGuard] that records what the session asks of it.
final class FakeGuard implements LocalDataGuard {
  /// Unsynced records.
  int pending = 0;

  /// What [pushPending] returns (and whether it clears [pending]).
  bool pushWorks = true;

  /// When set, [pushPending] waits for it.
  Completer<void>? pushGate;

  /// [wipe] throws this many more times (a full disk, a locked database).
  int wipeFailures = 0;

  /// [pendingCount] throws (the local database cannot be read).
  bool countFails = false;

  /// Calls in order: `count`, `push`, `wipe`.
  final log = <String>[];

  /// Times [wipe] ran.
  int get wipes => log.where((e) => e == 'wipe').length;

  /// Times [pushPending] ran.
  int get pushes => log.where((e) => e == 'push').length;

  @override
  Future<int> pendingCount() async {
    log.add('count');
    if (countFails) throw StateError('local database unreadable');
    return pending;
  }

  @override
  Future<bool> pushPending() async {
    log.add('push');
    if (pushGate case final gate?) await gate.future;
    if (pushWorks) pending = 0;
    return pushWorks;
  }

  @override
  Future<void> wipe() async {
    log.add('wipe');
    if (wipeFailures > 0) {
      wipeFailures--;
      throw StateError('disk full');
    }
    pending = 0;
  }
}

/// Fakes shared by every container a test starts.
class SessionBed {
  /// Creates a bed at [testStart] with an empty store.
  SessionBed() : clock = FixedClock(testStart) {
    auth = FakeAuth(store: store, clock: clock, hook: hook);
  }

  /// The app's and the fake server's clock.
  final FixedClock clock;

  /// The session store (survives restarts).
  final store = InMemorySessionStore();

  /// The auth-failure hook (shared so the fake reports into the app).
  final hook = AuthFailureHook();

  /// The local data.
  final guard = FakeGuard();

  /// The fake server.
  late final FakeAuth auth;

  /// This build's version.
  String appVersion = '0.1.0';

  /// Starts the app (over [store] instead of the shared one when given) and
  /// waits for the restore and the start-up checks.
  Future<ProviderContainer> start({SessionStore? store}) async {
    final c = startUnrestored(store: store);
    await c.read(sessionProvider.notifier).restored;
    await settle();
    return c;
  }

  /// Starts the app without waiting.
  ProviderContainer startUnrestored({SessionStore? store}) =>
      ProviderContainer.test(
        overrides: [
          sessionStoreProvider.overrideWithValue(store ?? this.store),
          faAuthRepositoryProvider.overrideWithValue(auth),
          authFailureHookProvider.overrideWithValue(hook),
          clockProvider.overrideWithValue(clock),
          localDataGuardProvider.overrideWithValue(guard),
          pinLockProvider.overrideWithValue(PinLock(iterations: 50)),
          appVersionProvider.overrideWithValue(appVersion),
        ],
        retry: (_, _) => null,
      );

  /// Starts the app, logs Suresh in and sets [goodPin]: active.
  Future<ProviderContainer> active() async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.login(sureshCode, sureshPassword);
    await session.setPin(goodPin);
    await settle();
    return c;
  }
}

/// The phase of [c]'s session.
SessionPhase phaseOf(ProviderContainer c) => c.read(sessionProvider).phase;

/// A store whose every call fails (e.g. a keystore lost after a restore).
final class ThrowingStore implements SessionStore {
  static Never _fail() => throw StateError('keystore unavailable');

  @override
  Future<void> clear({bool wipeDeviceKey = false}) async => _fail();

  @override
  Future<void> clearPin() async => _fail();

  @override
  Future<String> deviceKey() async => _fail();

  @override
  Future<Language?> readLanguage() async => _fail();

  @override
  Future<DateTime?> readLastOnlineAt() async => _fail();

  @override
  Future<SessionMeta> readMeta() async => _fail();

  @override
  Future<PinRecord?> readPin() async => _fail();

  @override
  Future<StoredSession?> readSession() async => _fail();

  @override
  Future<void> resetDeviceKey() async => _fail();

  @override
  Future<void> writeLanguage(Language language) async => _fail();

  @override
  Future<void> writeLastOnlineAt(DateTime at) async => _fail();

  @override
  Future<void> writeMeta(SessionMeta meta) async => _fail();

  @override
  Future<void> writePin(PinRecord pin) async => _fail();

  @override
  Future<void> writeSession(StoredSession session) async => _fail();
}
