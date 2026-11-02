/// The FA offline engine: what screens import besides `data/data.dart`.
///
/// Read the territory with `territoryProvider`, the sync state with
/// `syncStateProvider`, and write only through `faActionsProvider`. See
/// `README.md` next to this file for how the engine works.
library;

export '../device/connectivity.dart';
export 'commands.dart' show CommandType, EntityType;
export 'fa_actions.dart';
export 'geo.dart';
export 'local_store.dart';
export 'outbox.dart';
export 'providers.dart';
export 'sync_engine.dart';
export 'territory.dart';
