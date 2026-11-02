/// The FA app's data layer: domain models, repository interfaces, the
/// Riverpod providers that pick mock or API, and the session state.
///
/// Screens import this file (plus `local/local.dart` for the territory and
/// `FaActions`). From `mock/mock_backend.dart` it exports `MockScenario` (the
/// dev-only scenario switch) and `MockBackend` (the type of
/// `mockBackendProvider` and `faDataOverrides(mockBackend:)`, for bootstrap,
/// the dev screen and tests); no screen or controller uses the
/// `Mock*Repository` classes.
library;

export 'helpline.dart';
export 'mock/mock_backend.dart' show MockBackend, MockScenario;
export 'models/models.dart';
export 'providers.dart';
export 'repositories/repositories.dart';
export 'session/auth_failures.dart';
export 'session/local_data_guard.dart';
export 'session/pin_lock.dart';
export 'session/session_controller.dart';
export 'session/session_phase.dart';
export 'session/session_store.dart';
