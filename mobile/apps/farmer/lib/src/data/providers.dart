/// Riverpod wiring for the farmer data layer.
///
/// Screens and controllers read only the repository interfaces through the
/// `*RepositoryProvider`s below; which implementation backs them (mock or
/// API) is decided once, from [OrbitEnv], in [buildFarmerRepositories].
///
/// Bootstrap (in `main.dart`):
///
/// ```dart
/// final env = orbitEnvFromBuild();
/// runApp(ProviderScope(
///   overrides: farmerDataOverrides(env: env),
///   retry: orbitRetry,
///   child: const FarmerApp(),
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
  // A release build without --flavor (e.g. iOS before its schemes exist)
  // would otherwise fall back to dev and ship mock data.
  if (kReleaseMode && (appFlavor ?? '').isEmpty) {
    throw StateError('Release builds need --flavor staging or prod.');
  }
  return _envFromBuild();
}

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

/// Where tokens, the install ID and the language choice are kept.
/// In memory for now; a secure-storage store replaces it later.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => InMemorySessionStore(),
);

/// Where repositories report failures that end or change the session (see
/// [AuthFailureHook]); `SessionController` listens to it.
final authFailureHookProvider = Provider<AuthFailureHook>(
  (ref) => AuthFailureHook(),
);

/// Time source for the data layer.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The mock backend, or null when the app uses the API. Dev tools (the
/// scenario switch) go through [mockScenarioProvider] instead.
///
/// The starting scenario and latency come from the dart-defines
/// `ORBIT_MOCK_SCENARIO` (a [MockScenario] name, e.g. `offline`) and
/// `ORBIT_MOCK_LATENCY_MS` (default 350).
final mockBackendProvider = Provider<MockBackend?>((ref) {
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
/// session or a deactivated farmer is handled in one place.
FarmerRepositories buildFarmerRepositories(
  OrbitEnv env,
  SessionStore store, {
  MockBackend? mock,
  AuthFailureHook? authFailures,
}) => switch (env.dataSource) {
  DataSource.mock => (mock ?? MockBackend()).repositories(
    store,
    authFailures: authFailures,
  ),
  DataSource.api => throw UnimplementedError(
    'ORBIT_DATA_SOURCE=api needs the Api*Repository set, which is not built '
    'yet. Follow "Swap to the real API" in '
    'apps/farmer/lib/src/data/README.md, or run with ORBIT_DATA_SOURCE=mock '
    '(dev flavour only).',
  ),
};

/// The full repository set for the current environment.
final farmerRepositoriesProvider = Provider<FarmerRepositories>((ref) {
  return buildFarmerRepositories(
    ref.watch(orbitEnvProvider),
    ref.watch(sessionStoreProvider),
    mock: ref.watch(mockBackendProvider),
    authFailures: ref.watch(authFailureHookProvider),
  );
});

/// Sign-in, tokens, heartbeat.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(farmerRepositoriesProvider).auth,
);

/// Home, profile, consents, plots, seasons.
final farmerProfileRepositoryProvider = Provider<FarmerProfileRepository>(
  (ref) => ref.watch(farmerRepositoriesProvider).profile,
);

/// FAs and call-backs.
final fieldAssistantRepositoryProvider = Provider<FieldAssistantRepository>(
  (ref) => ref.watch(farmerRepositoriesProvider).fieldAssistants,
);

/// My visits.
final visitsRepositoryProvider = Provider<VisitsRepository>(
  (ref) => ref.watch(farmerRepositoriesProvider).visits,
);

/// Crop advisory inbox.
final noticesRepositoryProvider = Provider<NoticesRepository>(
  (ref) => ref.watch(farmerRepositoriesProvider).notices,
);

/// Village picker.
final geoRepositoryProvider = Provider<GeoRepository>(
  (ref) => ref.watch(farmerRepositoriesProvider).geo,
);

/// Crops, season codes, dealers.
final mastersRepositoryProvider = Provider<MastersRepository>(
  (ref) => ref.watch(farmerRepositoriesProvider).masters,
);

/// Overrides for the app's root `ProviderScope`.
///
/// [store] replaces the in-memory session store (secure storage later).
/// [mockBackend] lets a test or demo start with a chosen backend (latency,
/// clock, scenario); ignored unless [env] uses mock data.
List<Override> farmerDataOverrides({
  required OrbitEnv env,
  SessionStore? store,
  MockBackend? mockBackend,
}) => [
  orbitEnvProvider.overrideWithValue(env),
  if (store != null) sessionStoreProvider.overrideWithValue(store),
  if (mockBackend != null && env.usesMock)
    mockBackendProvider.overrideWithValue(mockBackend),
];

/// The current mock scenario, for a dev-only switch. Null when the app uses
/// the API (hide the switch then).
///
/// ```dart
/// ref.read(mockScenarioProvider.notifier).select(MockScenario.offline);
/// ```
///
/// The change applies to the next repository call; refresh or invalidate the
/// screen's providers to see it.
final mockScenarioProvider =
    NotifierProvider<MockScenarioController, MockScenario?>(
      MockScenarioController.new,
    );

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

  /// Drops all mock changes (sign-ups, call-backs, consents, tokens) and
  /// reloads the seed. A signed-in farmer's next call then fails with 401,
  /// which signs the app out to phone entry.
  void resetData() => ref.read(mockBackendProvider)?.reset();
}

/// Retry policy for the root `ProviderScope(retry: orbitRetry)`.
///
/// Riverpod 3 retries every failing provider by default (10 times). This
/// retries only server-side failures (5xx, 429) twice, honouring
/// `Retry-After`; network errors and 4xx surface at once so the screen shows
/// its offline or error card and the farmer decides when to retry.
Duration? orbitRetry(int retryCount, Object error) {
  if (retryCount >= 2 || error is! ApiError) return null;
  if (error.isNetwork || !error.isRetryable) return null;
  return error.retryAfter ?? Duration(seconds: 1 << retryCount);
}
