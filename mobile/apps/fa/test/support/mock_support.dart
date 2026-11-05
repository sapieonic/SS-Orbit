/// Helpers for tests that need the FA mock server: a backend with no latency
/// and a fixed clock, a signed-in repository set over it, and the provider
/// overrides that point an app container at them.
///
/// ```dart
/// final m = await MockWorld.signedIn();            // Suresh, FA-KDP-014
/// final snap = await m.repos.sync.getSnapshot();
/// final c = ProviderContainer.test(overrides: m.overrides());
/// ```
library;

import 'dart:math' as math;

import 'package:fa/src/data/data.dart';
import 'package:fa/src/local/commands.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:orbit_core/orbit_core.dart';

/// 2 Nov 2026, 10:30 IST (05:00 UTC), a Monday: the default test "now".
DateTime get mockTestNow => DateTime.utc(2026, 11, 2, 5);

/// The device the helpers sign in with (app version 0.1.0).
const mockTestDevice = DeviceInfo(
  deviceKey: 'mock-test-device-1',
  model: 'Redmi 9A',
  osVersion: 'Android 11',
  appVersion: '0.1.0',
);

/// One mock server plus a session store and hook over it.
class MockWorld {
  /// Creates a world at [now] (default [mockTestNow]) in [scenario], with no
  /// latency and repeatable IDs.
  MockWorld({
    DateTime? now,
    MockScenario scenario = MockScenario.normal,
    int seed = 7,
  }) : clock = FixedClock(now ?? mockTestNow),
       store = InMemorySessionStore(random: math.Random(seed)) {
    backend = MockBackend(
      clock: clock,
      latency: Duration.zero,
      slowLatency: const Duration(milliseconds: 50),
      scenario: scenario,
      random: math.Random(seed),
    );
    repos = backend.repositories(store, authFailures: hook);
    hook.listen((error, {faId}) => reported.add((error.code, faId)));
  }

  /// A world with [code] signed in (Suresh by default).
  static Future<MockWorld> signedIn({
    String code = MockBackend.sureshCode,
    String password = MockBackend.sureshPassword,
    DateTime? now,
    MockScenario scenario = MockScenario.normal,
  }) async {
    final w = MockWorld(now: now, scenario: scenario);
    await w.login(code: code, password: password);
    return w;
  }

  /// The server's and the app's clock.
  final FixedClock clock;

  /// The session store the repositories use.
  final InMemorySessionStore store;

  /// The hook the repositories report to.
  final AuthFailureHook hook = AuthFailureHook();

  /// What reached [hook]: (error code, FA ID).
  final reported = <(String, String?)>[];

  /// The mock server.
  late final MockBackend backend;

  /// The repositories over [backend] and [store].
  late final FaRepositories repos;

  /// Signs [code] in with [mockTestDevice].
  Future<FaSession> login({
    String code = MockBackend.sureshCode,
    String password = MockBackend.sureshPassword,
    DeviceInfo device = mockTestDevice,
  }) => repos.auth.login(code: code, password: password, device: device);

  /// The current snapshot (a fresh pull, no ETag).
  Future<Snapshot> snapshot() async {
    final r = await repos.sync.getSnapshot();
    return (r as SnapshotFetched).snapshot;
  }

  /// Sends [payloads] as one batch with IDs `cmd-<n>` style UUIDs and
  /// returns the results.
  Future<CommandBatchResult> push(List<CommandPayload> payloads) =>
      repos.sync.submitCommands([
        for (final p in payloads)
          p.toCommandIn(id: newId(), clientCreatedAt: clock.now()),
      ]);

  int _ids = 0;

  /// A new, unique UUID-shaped ID (repeatable per world).
  String newId() {
    final n = (_ids++).toRadixString(16).padLeft(12, '0');
    return '0190a5b2-7c1e-7d4a-9b3f-$n';
  }

  /// Overrides for a `ProviderContainer` or `ProviderScope` that use this
  /// world's backend, store, hook and clock.
  List<Override> overrides() => [
    ...faDataOverrides(
      env: OrbitEnv.devMock,
      store: store,
      mockBackend: backend,
    ),
    clockProvider.overrideWithValue(clock),
    authFailureHookProvider.overrideWithValue(hook),
  ];
}
