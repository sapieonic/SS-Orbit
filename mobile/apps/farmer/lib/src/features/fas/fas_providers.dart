import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';

import '../../data/data.dart';
import '../../shared/farmer_data.dart';

/// The levels Look for FAs (F3) offers as tabs, most specific first.
const fasLevels = [AreaLevel.village, AreaLevel.mandal, AreaLevel.district];

/// FAs covering the farmer's village at one [AreaLevel] (one tab of F3).
final fasProvider = FutureProvider.autoDispose
    .family<List<FaOption>, AreaLevel>(
      (ref, level) => loadFarmerData(
        ref,
        'fas/${level.wire}',
        () => ref.watch(fieldAssistantRepositoryProvider).listFas(level: level),
      ),
    );

/// The farmer's open "call me back" request on F3, with the request and Undo
/// actions.
///
/// `null` when there is none. A failed load (offline) also counts as none so
/// the button still shows: asking again is safe, the server returns the open
/// request instead of a new one.
final openCallbackProvider =
    AsyncNotifierProvider.autoDispose<OpenCallbackController, Callback?>(
      OpenCallbackController.new,
    );

/// Requests and cancels the call-back. Actions throw [ApiError] for the
/// screen to show; the state changes only on success, and not when another
/// farmer signed in meanwhile.
class OpenCallbackController extends AsyncNotifier<Callback?> {
  FieldAssistantRepository get _repo =>
      ref.read(fieldAssistantRepositoryProvider);

  @override
  Future<Callback?> build() => loadFarmerData(
    ref,
    'openCallback',
    () => ref.watch(fieldAssistantRepositoryProvider).getOpenCallback(),
  );

  /// "Ask your FA to call you back" (`POST /v1/farmer/callbacks`).
  ///
  /// Safe to repeat: an open request comes back unchanged. On
  /// `no_fa_assigned` Home is refreshed, since its FA card is out of date
  /// (also when the farmer left Look for FAs meanwhile).
  Future<Callback> request() async {
    final edits = ref.read(farmerEditsProvider);
    final scope = ref.read(farmerDataScopeProvider);
    try {
      final callback = await _repo.requestCallback();
      if (isCurrentScope(ref, scope)) state = AsyncData(callback);
      return callback;
    } on ApiError catch (e) {
      if (e.code == ApiErrorCode.noFaAssigned) edits.refreshHome();
      rethrow;
    }
  }

  /// Undo: cancels the open request. On `callback_closed` (the FA already
  /// called back) the request is no longer open, so it is cleared too before
  /// the error goes to the screen.
  Future<void> cancel() async {
    final current = state.value;
    if (current == null) return;
    final scope = ref.read(farmerDataScopeProvider);
    try {
      await _repo.cancelCallback(current.id);
      if (isCurrentScope(ref, scope)) state = const AsyncData(null);
    } on ApiError catch (e) {
      if (e.code == ApiErrorCode.callbackClosed && isCurrentScope(ref, scope)) {
        state = const AsyncData(null);
      }
      rethrow;
    }
  }
}
