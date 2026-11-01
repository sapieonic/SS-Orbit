/// Helpers for session tests: a mock backend, store and clock that outlive
/// the containers a test starts (each [SessionTestBed.start] is an app
/// restart), stores that count or fail, and [CallScript] to fail, hold or
/// watch single repository calls so races can be played out step by step.
library;

import 'dart:async';

import 'package:farmer/src/data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:orbit_core/orbit_core.dart';

import 'harness.dart' show newTestClock;

/// A backend, store and clock shared by every container a test starts.
class SessionTestBed {
  /// Creates a bed at the test clock's start, with an empty [CountingStore].
  SessionTestBed() : clock = newTestClock() {
    backend = MockBackend(clock: clock, latency: Duration.zero);
  }

  /// The clock of the app and the backend.
  final FixedClock clock;

  /// The mock backend (switch its scenario mid-test).
  late final MockBackend backend;

  /// The session store every container uses (unless [start] gets another).
  final store = CountingStore();

  /// Scripts auth and profile calls of containers started with it.
  final script = CallScript();

  /// Starts the app over the shared backend and store (or [store]) and
  /// waits until the saved session is restored.
  Future<ProviderContainer> start({SessionStore? store}) async {
    final c = startUnrestored(store: store);
    await c.read(sessionProvider.notifier).restored;
    return c;
  }

  /// Like [start], without waiting for the restore.
  ProviderContainer startUnrestored({SessionStore? store}) =>
      ProviderContainer.test(
        overrides: [
          ...farmerDataOverrides(
            env: OrbitEnv.devMock,
            store: store ?? this.store,
            mockBackend: backend,
          ),
          clockProvider.overrideWithValue(clock),
          script.override,
        ],
        retry: (_, _) => null,
      );

  /// Starts the app and signs [phone] in with the dev OTP.
  Future<ProviderContainer> signedIn(String phone) async {
    final c = await start();
    await signInOn(c, phone);
    return c;
  }
}

/// Signs [phone] in on [c] with the dev OTP.
Future<void> signInOn(ProviderContainer c, String phone) async {
  final session = c.read(sessionProvider.notifier);
  await session.requestOtp(phone);
  await session.verifyOtp(MockBackend.fixedOtp);
}

/// Lets reported failures, re-checks and held calls run.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A 401 the refresh could not fix.
const sessionEnded = ApiError(
  code: ApiErrorCode.unauthorized,
  message: 'session has ended',
  status: 401,
);

/// HO revoked this phone.
const deviceRevoked = ApiError(
  code: ApiErrorCode.deviceRevoked,
  message: 'revoked',
  status: 401,
);

// ---------------------------------------------------------------------------
// Scripted calls.

/// Fails, holds or counts single calls of the auth and profile repositories
/// (by method name, e.g. `getHome`); everything else reaches the mock.
class CallScript {
  final _failures = <String, List<Object>>{};
  final _holds = <String, List<Completer<void>>>{};

  /// Every scripted-repository call so far, by method name.
  final calls = <String>[];

  /// The next [call] throws [error] without reaching the backend.
  void failNext(String call, Object error) =>
      _failures.putIfAbsent(call, () => []).add(error);

  /// The next [call] reaches the backend at once, but its result (or error)
  /// is handed back only when the returned completer completes, like a slow
  /// response.
  Completer<void> holdNext(String call) {
    final gate = Completer<void>();
    _holds.putIfAbsent(call, () => []).add(gate);
    return gate;
  }

  /// Runs [proceed], the real [call], as scripted.
  Future<T> run<T>(String call, Future<T> Function() proceed) async {
    calls.add(call);
    final failure = _take(_failures, call);
    if (failure != null) throw failure;
    final gate = _take(_holds, call);
    if (gate == null) return proceed();
    final result = await proceed().then<(T?, Object?)>(
      (value) => (value, null),
      onError: (Object e) => (null, e),
    );
    await gate.future;
    if (result.$2 case final error?) throw error;
    return result.$1 as T;
  }

  static V? _take<V extends Object>(Map<String, List<V>> next, String call) {
    final queue = next[call];
    if (queue == null || queue.isEmpty) return null;
    return queue.removeAt(0);
  }

  /// Replaces the repository set with the usual one (reporting to the
  /// auth-failure hook) whose auth and profile calls go through [run].
  Override get override => farmerRepositoriesProvider.overrideWith((ref) {
    final base = buildFarmerRepositories(
      ref.watch(orbitEnvProvider),
      ref.watch(sessionStoreProvider),
      mock: ref.watch(mockBackendProvider),
      authFailures: ref.watch(authFailureHookProvider),
    );
    return FarmerRepositories(
      auth: _ScriptedAuth(base.auth, this),
      profile: _ScriptedProfile(base.profile, this),
      fieldAssistants: base.fieldAssistants,
      visits: base.visits,
      notices: base.notices,
      geo: base.geo,
      masters: base.masters,
    );
  });
}

final class _ScriptedAuth implements AuthRepository {
  _ScriptedAuth(this._inner, this._script);

  final AuthRepository _inner;
  final CallScript _script;

  @override
  Future<AppConfig> getAppConfig() =>
      _script.run('getAppConfig', _inner.getAppConfig);

  @override
  Future<OtpSent> requestOtp({
    required String phone,
    required Language language,
  }) => _script.run(
    'requestOtp',
    () => _inner.requestOtp(phone: phone, language: language),
  );

  @override
  Future<FarmerSession> verifyOtp({
    required String phone,
    required String code,
    required DeviceInfo device,
  }) => _script.run(
    'verifyOtp',
    () => _inner.verifyOtp(phone: phone, code: code, device: device),
  );

  @override
  Future<TokenPair> refreshSession() =>
      _script.run('refreshSession', _inner.refreshSession);

  @override
  Future<void> logout() => _script.run('logout', _inner.logout);

  @override
  Future<DeviceStatus> heartbeat({
    String? model,
    String? osVersion,
    String? appVersion,
    String? pushToken,
  }) => _script.run(
    'heartbeat',
    () => _inner.heartbeat(
      model: model,
      osVersion: osVersion,
      appVersion: appVersion,
      pushToken: pushToken,
    ),
  );
}

final class _ScriptedProfile implements FarmerProfileRepository {
  _ScriptedProfile(this._inner, this._script);

  final FarmerProfileRepository _inner;
  final CallScript _script;

  @override
  Future<FarmerHome> getHome() => _script.run('getHome', _inner.getHome);

  @override
  Future<Farmer> updateProfile({
    String? name,
    String? nameTe,
    Language? language,
    String? photoKey,
  }) => _script.run(
    'updateProfile',
    () => _inner.updateProfile(
      name: name,
      nameTe: nameTe,
      language: language,
      photoKey: photoKey,
    ),
  );

  @override
  Future<Farmer> completeProfile({
    required String name,
    String? nameTe,
    required Language language,
    required String villageId,
  }) => _script.run(
    'completeProfile',
    () => _inner.completeProfile(
      name: name,
      nameTe: nameTe,
      language: language,
      villageId: villageId,
    ),
  );

  @override
  Future<List<CurrentConsent>> listConsents() =>
      _script.run('listConsents', _inner.listConsents);

  @override
  Future<List<CurrentConsent>> setConsent({
    required ConsentPurpose purpose,
    required bool granted,
    required String noticeVersion,
    bool? audioPlayed,
  }) => _script.run(
    'setConsent',
    () => _inner.setConsent(
      purpose: purpose,
      granted: granted,
      noticeVersion: noticeVersion,
      audioPlayed: audioPlayed,
    ),
  );

  @override
  Future<FarmerPhotoUpload> createPhotoUpload({
    required PhotoContentType contentType,
    required int bytes,
  }) => _script.run(
    'createPhotoUpload',
    () => _inner.createPhotoUpload(contentType: contentType, bytes: bytes),
  );

  @override
  Future<Plot> addPlot({
    String? label,
    required LatLng pin,
    required double areaAcres,
  }) => _script.run(
    'addPlot',
    () => _inner.addPlot(label: label, pin: pin, areaAcres: areaAcres),
  );

  @override
  Future<Season> startSeason({
    required String plotId,
    required String seasonCode,
    required String cropId,
    LocalDate? sowingDate,
    String? previousCropId,
  }) => _script.run(
    'startSeason',
    () => _inner.startSeason(
      plotId: plotId,
      seasonCode: seasonCode,
      cropId: cropId,
      sowingDate: sowingDate,
      previousCropId: previousCropId,
    ),
  );

  @override
  Future<Season> closeSeason({
    required String seasonId,
    required SeasonOutcome outcome,
  }) => _script.run(
    'closeSeason',
    () => _inner.closeSeason(seasonId: seasonId, outcome: outcome),
  );
}

// ---------------------------------------------------------------------------
// Stores.

/// An in-memory store that counts [clearSession] calls and can fail reads,
/// clears and language saves.
final class CountingStore implements SessionStore {
  final _inner = InMemorySessionStore();

  /// [clearSession] calls so far.
  int clears = 0;

  /// When set, [readSession] throws (e.g. the keystore is busy right after
  /// an update); the install ID still reads.
  bool failSessionReads = false;

  /// When set, [clearSession] throws (after counting the call).
  bool failClears = false;

  /// When set, [writeLanguage] throws.
  bool failLanguageWrites = false;

  @override
  Future<void> clearSession({bool wipe = false}) async {
    clears++;
    if (failClears) throw StateError('keystore busy');
    return _inner.clearSession(wipe: wipe);
  }

  @override
  Future<String?> readDeviceKey() => _inner.readDeviceKey();

  @override
  Future<Language?> readLanguage() => _inner.readLanguage();

  @override
  Future<SessionPhase?> readPhase() => _inner.readPhase();

  @override
  Future<StoredSession?> readSession() async {
    if (failSessionReads) throw StateError('keystore busy');
    return _inner.readSession();
  }

  @override
  Future<void> writeDeviceKey(String deviceKey) =>
      _inner.writeDeviceKey(deviceKey);

  @override
  Future<void> writeLanguage(Language language) async {
    if (failLanguageWrites) throw StateError('keystore busy');
    return _inner.writeLanguage(language);
  }

  @override
  Future<void> writePhase(SessionPhase phase) => _inner.writePhase(phase);

  @override
  Future<void> writeSession(StoredSession session) =>
      _inner.writeSession(session);
}

/// A store whose every call fails (e.g. a keystore lost after a restore).
final class ThrowingStore implements SessionStore {
  static Never _fail() => throw StateError('keystore unavailable');

  @override
  Future<void> clearSession({bool wipe = false}) async => _fail();

  @override
  Future<String?> readDeviceKey() async => _fail();

  @override
  Future<Language?> readLanguage() async => _fail();

  @override
  Future<SessionPhase?> readPhase() async => _fail();

  @override
  Future<StoredSession?> readSession() async => _fail();

  @override
  Future<void> writeDeviceKey(String deviceKey) async => _fail();

  @override
  Future<void> writeLanguage(Language language) async => _fail();

  @override
  Future<void> writePhase(SessionPhase phase) async => _fail();

  @override
  Future<void> writeSession(StoredSession session) async => _fail();
}
