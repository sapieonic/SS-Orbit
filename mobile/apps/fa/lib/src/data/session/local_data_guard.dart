import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the session needs from the offline engine's local data, without
/// depending on it: count and push the unsynced records, and wipe them.
///
/// The session controller calls [pendingCount] before a logout (so Me can
/// warn "3 records are not synced yet"), [pushPending] before blocking for
/// an update, and [wipe] when HO removes the phone or another FA takes it
/// over. The app wires [localDataGuardProvider] to the engine; the default
/// does nothing, so the session works (and is tested) on its own.
abstract interface class LocalDataGuard {
  /// Outbox rows not yet accepted by the server (queued, sending, conflict)
  /// plus photos waiting to upload.
  Future<int> pendingCount();

  /// Tries to push the outbox now. True when nothing is left unsynced;
  /// false when offline or some rows stayed. Never throws.
  Future<bool> pushPending();

  /// Deletes every local table, the outbox and queued photo files.
  Future<void> wipe();
}

/// A [LocalDataGuard] with no local data: nothing pending, nothing to wipe.
final class NoLocalData implements LocalDataGuard {
  /// Creates the no-op guard.
  const NoLocalData();

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<bool> pushPending() async => true;

  @override
  Future<void> wipe() async {}
}

/// The engine's guard (overridden by the app; [NoLocalData] by default).
final localDataGuardProvider = Provider<LocalDataGuard>(
  (ref) => const NoLocalData(),
);
