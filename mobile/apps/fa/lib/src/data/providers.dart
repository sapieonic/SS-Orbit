/// Riverpod wiring for the FA data layer.
///
/// Controllers and the offline engine read only the repository interfaces
/// through the `*RepositoryProvider`s below; which implementation backs them
/// (mock or API) is decided once, from [OrbitEnv], in [buildFaRepositories].
/// Screens mostly read the territory and write through `FaActions`
/// (`local/`), not these.
///
/// Bootstrap (in `main.dart`):
///
/// ```dart
/// final env = orbitEnvFromBuild();
/// runApp(ProviderScope(
///   overrides: faDataOverrides(env: env),
///   retry: orbitRetry,
///   child: const FaApp(),
/// ));
/// ```
library;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:orbit_core/orbit_core.dart';

import 'mock/mock_backend.dart';
import 'repositories/repositories.dart';
import 'session/auth_failures.dart';
import 'session/session_store.dart';

/// Reads the environment from the build: the flavour (`--flavor`, via
/// [appFlavor]) and the dart-defines `ORBIT_DATA_SOURCE` (`mock` | `api`) and
/// `ORBIT_API_BASE_URL`. Throws when staging or prod asks for mock data.
OrbitEnv orbitEnvFromBuild() {
  // A release build without --flavor would otherwise fall back to dev and
  // ship mock data.
  if (kReleaseMode && (appFlavor ?? '').isEmpty) {
    throw StateError('Release builds need --flavor staging or prod.');
  }
  return _envFromBuild();
}

/// False in a `--flavor staging` or `--flavor prod` build. [appFlavor] is a
/// compile-time constant, so there every branch that builds a [MockBackend]
/// is dead code and the tree shaker leaves the mock (its seed and logins) out
/// of the APK. [OrbitEnv.parse] refuses mock data there anyway.
const bool mockBuildAllowed = appFlavor != 'staging' && appFlavor != 'prod';

OrbitEnv _envFromBuild() => OrbitEnv.parse(
  // appFlavor is a compile-time constant that is null when analysed without
  // --flavor, which the lint mistakes for a redundant default.
  // ignore: avoid_redundant_argument_values
  flavor: appFlavor,
  dataSource: const String.fromEnvironment('ORBIT_DATA_SOURCE'),
  apiBaseUrl: const String.fromEnvironment('ORBIT_API_BASE_URL'),
);

/// The runtime environment. Defaults to [orbitEnvFromBuild]; override it at
/// bootstrap or in tests.
final orbitEnvProvider = Provider<OrbitEnv>((ref) => orbitEnvFromBuild());

/// Where tokens, the install ID, the PIN verifier, the language and the
/// last online contact are kept. In memory for now; a secure-storage store
/// replaces it later.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => InMemorySessionStore(),
);

/// Where repositories report failures that end or change the session (see
/// [AuthFailureHook]); `SessionController` listens to it.
final authFailureHookProvider = Provider<AuthFailureHook>(
  (ref) => AuthFailureHook(),
);

/// Time source for the data layer and the offline engine.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The mock backend, or null when the app uses the API. Dev tools (the
/// scenario switch) go through [mockScenarioProvider] instead.
///
/// The starting scenario and latency come from the dart-defines
/// `ORBIT_MOCK_SCENARIO` (a [MockScenario] name, e.g. `offline`) and
/// `ORBIT_MOCK_LATENCY_MS` (default 350).
final mockBackendProvider = Provider<MockBackend?>((ref) {
  // Two ifs, so the compiler folds the constant one and drops the rest.
  if (!mockBuildAllowed) return null;
  final env = ref.watch(orbitEnvProvider);
  if (!env.usesMock) return null;
  const scenario = String.fromEnvironment('ORBIT_MOCK_SCENARIO');
  const latencyMs = int.fromEnvironment(
    'ORBIT_MOCK_LATENCY_MS',
    defaultValue: -1,
  );
  final backend = MockBackend(
    clock: ref.watch(clockProvider),
    scenario:
        MockScenario.values.where((s) => s.name == scenario).firstOrNull ??
        MockScenario.normal,
  );
  if (latencyMs >= 0) backend.latency = const Duration(milliseconds: latencyMs);
  return backend;
});

/// Builds the repository set for [env].
///
/// Mock: the `Mock*Repository` set over [mock] (a new [MockBackend] when
/// null). API: not built yet; throws [UnimplementedError] until the
/// `Api*Repository` set exists (see `lib/src/data/README.md`).
///
/// Both report every failed signed-in call to [authFailures], so a revoked
/// phone, an ended session or a pending password change is handled in one
/// place.
FaRepositories buildFaRepositories(
  OrbitEnv env,
  SessionStore store, {
  MockBackend? mock,
  AuthFailureHook? authFailures,
}) {
  switch (env.dataSource) {
    case DataSource.mock:
      // A constant condition: in staging and prod the mock branch is dead
      // code and the tree shaker drops MockBackend.
      if (mockBuildAllowed) {
        return (mock ?? MockBackend()).repositories(
          store,
          authFailures: authFailures,
        );
      }
      throw StateError('Mock data is not built into staging or prod.');
    case DataSource.api:
      throw UnimplementedError(
        'ORBIT_DATA_SOURCE=api needs the Api*Repository set, which is not '
        'built yet. Follow "Swap to the real API" in '
        'apps/fa/lib/src/data/README.md, or run with ORBIT_DATA_SOURCE=mock '
        '(dev flavour only).',
      );
  }
}

/// The full repository set for the current environment.
final faRepositoriesProvider = Provider<FaRepositories>((ref) {
  return buildFaRepositories(
    ref.watch(orbitEnvProvider),
    ref.watch(sessionStoreProvider),
    mock: ref.watch(mockBackendProvider),
    authFailures: ref.watch(authFailureHookProvider),
  );
});

/// Sign-in, tokens, password change, heartbeat.
final faAuthRepositoryProvider = Provider<FaAuthRepository>(
  (ref) => ref.watch(faRepositoriesProvider).auth,
);

/// Snapshot, status, command push (the sync engine only).
final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => ref.watch(faRepositoriesProvider).sync,
);

/// Phone lookup, consent OTP, farmer photo URL.
final enrolmentRepositoryProvider = Provider<EnrolmentRepository>(
  (ref) => ref.watch(faRepositoriesProvider).enrolment,
);

/// Visit photo upload URL and confirm (the photo queue only).
final visitPhotosRepositoryProvider = Provider<VisitPhotosRepository>(
  (ref) => ref.watch(faRepositoriesProvider).visitPhotos,
);

/// PUT to presigned URLs (farmer and visit photos).
final photoUploaderProvider = Provider<PhotoUploader>(
  (ref) => ref.watch(faRepositoriesProvider).photoUploader,
);

/// The online alerts list.
final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => ref.watch(faRepositoriesProvider).alerts,
);

/// Overrides for the app's root `ProviderScope`.
///
/// [store] replaces the in-memory session store (secure storage later).
/// [mockBackend] lets a test or demo start with a chosen backend (latency,
/// clock, scenario); ignored unless [env] uses mock data.
List<Override> faDataOverrides({
  required OrbitEnv env,
  SessionStore? store,
  MockBackend? mockBackend,
}) => [
  orbitEnvProvider.overrideWithValue(env),
  if (store != null) sessionStoreProvider.overrideWithValue(store),
  if (mockBackend != null && env.usesMock)
    mockBackendProvider.overrideWithValue(mockBackend),
];

/// The current mock scenario, for the dev screen. Null when the app uses the
/// API (hide the switch then).
///
/// ```dart
/// ref.read(mockScenarioProvider.notifier).select(MockScenario.offline);
/// ```
///
/// The change applies to the next repository call (the sync engine's next
/// run, the next heartbeat).
final mockScenarioProvider =
    NotifierProvider<MockScenarioController, MockScenario?>(
      MockScenarioController.new,
    );

/// True for the [MockScenario.offline] value of [mockScenarioProvider]
/// (false on the API, where it is null). The mock `connectivityProvider`
/// listens to `mockScenarioProvider.select(isMockOffline)`, so the device
/// layer needs no mock import.
bool isMockOffline(MockScenario? scenario) => scenario == MockScenario.offline;

/// Switches the [MockBackend] scenario at runtime.
class MockScenarioController extends Notifier<MockScenario?> {
  @override
  MockScenario? build() => ref.watch(mockBackendProvider)?.scenario;

  /// Makes every following mock call behave as [scenario]. Does nothing when
  /// the app uses the API.
  void select(MockScenario scenario) {
    final backend = ref.read(mockBackendProvider);
    if (backend == null) return;
    backend.scenario = scenario;
    state = scenario;
  }

  /// Drops all server-side mock changes (enrolments, visits, tokens, stored
  /// commands) and reloads the seed. A signed-in FA's next call then fails
  /// with 401, which asks for the password; the phone's local data is not
  /// touched (wipe it separately in the dev screen).
  void resetData() => ref.read(mockBackendProvider)?.reset();
}

/// Retry policy for the root `ProviderScope(retry: orbitRetry)`.
///
/// Riverpod 3 retries every failing provider by default (10 times). This
/// retries only server-side failures (5xx, 429) twice, honouring
/// `Retry-After`; network errors and 4xx surface at once so the screen shows
/// its offline or error state (the sync engine has its own backoff).
Duration? orbitRetry(int retryCount, Object error) {
  if (retryCount >= 2 || error is! ApiError) return null;
  if (error.isNetwork || !error.isRetryable) return null;
  return error.retryAfter ?? Duration(seconds: 1 << retryCount);
}
