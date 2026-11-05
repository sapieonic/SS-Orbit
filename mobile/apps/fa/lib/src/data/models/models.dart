/// FA app domain models. Immutable app models, not JSON DTOs: the API layer
/// maps generated `orbit_api` DTOs to these, so screens never see wire types.
/// Names mirror the OpenAPI schemas (`FASession` -> `FaSession`, `SnapSKU` ->
/// `SnapSku`).
///
/// Pure Dart (no Flutter import): the offline engine in `local/` uses them
/// and moves to `packages/orbit_sync` later. The snapshot and sync results
/// have `fromJson` (their JSON is not generated: the snapshot sections are
/// documentation-only schemas) and `toJson`, which writes the same JSON back
/// for the local store (`fromJson(toJson())` is equal). `TokenPair`,
/// `FieldAssistant` and `OfflinePolicy` have both for the session store.
library;

export 'alerts.dart';
export 'auth.dart';
export 'common.dart';
export 'enrolment.dart';
export 'enums.dart';
export 'masters.dart';
export 'snapshot.dart';
export 'sync.dart';
export 'uploads.dart';
