/// Riverpod wiring of the FA offline engine.
///
/// Screens read [territoryProvider] (the read model) and [syncStateProvider]
/// (the Sync screen, header badge), and write only through
/// [faActionsProvider]. The engine itself ([syncEngineProvider]) is started
/// by the app shell while the session is active and the app is in the
/// foreground (`start()` / `stop()`).
///
/// Bootstrap adds [localEngineOverrides] so the session controller's
/// `LocalDataGuard` counts, pushes and wipes through the engine:
///
/// ```dart
/// ProviderScope(
///   overrides: [...faDataOverrides(env: env), ...localEngineOverrides()],
///   child: const FaApp(),
/// )
/// ```
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:orbit_core/orbit_core.dart' show Clock;

import '../data/providers.dart'
    show
        clockProvider,
        photoUploaderProvider,
        syncRepositoryProvider,
        visitPhotosRepositoryProvider;
import '../data/session/local_data_guard.dart';
import '../data/session/session_controller.dart' show serverClockProvider;
import '../device/connectivity.dart';
import 'fa_actions.dart';
import 'local_store.dart';
import 'sync_engine.dart';
import 'territory.dart';

/// The local database. In memory until Drift lands; override in tests.
final localStoreProvider = Provider<LocalStore>((ref) => InMemoryLocalStore());

/// The sync engine (push, pull, photos). Not started by itself: call
/// `start()` when the session is active and the app is in the foreground,
/// `stop()` when it goes to the background.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    store: ref.watch(localStoreProvider),
    sync: ref.watch(syncRepositoryProvider),
    visitPhotos: ref.watch(visitPhotosRepositoryProvider),
    uploader: ref.watch(photoUploaderProvider),
    connectivity: ref.watch(connectivityProvider),
    // The device clock: the session (which owns the server offset) depends
    // on the engine through its LocalDataGuard, so the engine cannot read
    // the session. Nothing the engine stamps is checked by the server.
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

/// Every write the UI makes. Each one nudges the engine.
final faActionsProvider = Provider<FaActions>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return FaActions(
    store: ref.watch(localStoreProvider),
    clock: _ServerClock(ref),
    onWrite: engine.nudge,
  );
});

/// The device clock corrected by the server's time ([serverClockProvider]),
/// read at each `now()` so the actions follow every heartbeat without being
/// rebuilt. `visited_at`, `client_created_at`, the "not in the future" check
/// and the consent proof check use it: the server checks them against its own
/// clock.
final class _ServerClock implements Clock {
  _ServerClock(this._ref);

  final Ref _ref;

  @override
  DateTime now() => _ref.read(serverClockProvider).now();
}

/// The territory read model, rebuilt after every write to the local store
/// (snapshot, action, sync result).
final territoryProvider = AsyncNotifierProvider<TerritoryController, Territory>(
  TerritoryController.new,
);

/// Loads the [Territory] and reloads it on every store change.
class TerritoryController extends AsyncNotifier<Territory> {
  int _generation = 0;

  @override
  Future<Territory> build() async {
    final store = ref.watch(localStoreProvider);
    final sub = store.changes.listen((_) => unawaited(reload()));
    ref.onDispose(sub.cancel);
    return _load();
  }

  Future<Territory> _load() => Territory.load(
    ref.read(localStoreProvider),
    asOf: ref.read(serverClockProvider).now(),
  );

  /// Reads the store again (also moves "today" on after midnight).
  Future<void> reload() async {
    final generation = ++_generation;
    final territory = await _load();
    if (!ref.mounted || generation != _generation) return;
    state = AsyncData(territory);
  }
}

/// The engine's state for the Sync screen, the header badge and the PIN
/// screen.
final syncStateProvider = NotifierProvider<SyncStateController, SyncState>(
  SyncStateController.new,
);

/// Follows [SyncEngine.states].
class SyncStateController extends Notifier<SyncState> {
  @override
  SyncState build() {
    final engine = ref.watch(syncEngineProvider);
    final sub = engine.states.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return engine.state;
  }
}

/// Whether the phone has a network now, following changes
/// ([SyncState.online]). Screens also treat a failed call
/// (`ApiError.network`) as offline.
final phoneOnlineProvider = Provider<bool>(
  (ref) => ref.watch(syncStateProvider.select((s) => s.online)),
);

/// IDs with a change not synced yet (farmers, plots, seasons, visits), for
/// "not synced yet" badges. Empty while the territory loads.
final pendingEntityIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(territoryProvider).value?.pendingEntityIds ?? const {},
);

/// The session's [LocalDataGuard] backed by the engine.
final engineLocalDataGuardProvider = Provider<LocalDataGuard>(
  (ref) => EngineLocalDataGuard(ref.watch(syncEngineProvider)),
);

/// Overrides that connect the session to the engine (add them to the root
/// `ProviderScope`).
List<Override> localEngineOverrides() => [
  localDataGuardProvider.overrideWith(
    (ref) => ref.watch(engineLocalDataGuardProvider),
  ),
];

/// [LocalDataGuard] over a [SyncEngine].
final class EngineLocalDataGuard implements LocalDataGuard {
  /// Wraps [engine].
  const EngineLocalDataGuard(this.engine);

  /// The engine.
  final SyncEngine engine;

  @override
  Future<int> pendingCount() => engine.pendingCount();

  @override
  Future<bool> pushPending() => engine.pushPending();

  @override
  Future<void> wipe() => engine.wipe();
}
