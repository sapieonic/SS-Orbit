import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:orbit_core/orbit_core.dart';

import '../data/data.dart';
import 'farmer_text.dart';

/// Data several screens share. Feature-only data lives in the feature's own
/// `*_providers.dart`.
///
/// Writes that change Home (profile, plots, seasons) go through
/// [farmerEditsProvider], which refreshes it even when the screen that asked
/// is gone by then.
///
/// Every provider that loads the farmer's own data loads it through
/// [loadFarmerData], so a different farmer signing in on this phone (or a
/// dev-menu data reset) refetches it, and data loaded for an earlier farmer
/// never reaches a screen: Riverpod keeps a provider's last value while it
/// reloads (`isReloading`) and when that reload fails (`AsyncError` with
/// `hasValue`). Screens read these providers through `.fresh`
/// (`shared/async_view.dart`) or `AsyncValueView`, which drop such a value
/// ([holdsOtherScopeData]): a spinner while loading, the error card when the
/// load failed. The farmer's own data stays on screen while it refreshes,
/// and when a refresh fails.

/// The signed-in farmer's ID, or null when nobody is signed in. Every
/// farmer-scoped provider watches this (and nothing else from the session).
final currentFarmerIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider.select((s) => s.farmerId)),
);

/// Bumped to make every farmer-scoped provider load again without touching
/// the session (the dev menu does this after switching mock scenario).
final farmerDataGenerationProvider =
    NotifierProvider<FarmerDataGeneration, int>(FarmerDataGeneration.new);

/// See [farmerDataGenerationProvider].
class FarmerDataGeneration extends Notifier<int> {
  @override
  int build() => 0;

  /// Makes every farmer-scoped provider refetch.
  void bump() => state++;
}

/// What farmer-scoped data depends on: who is signed in, and the data
/// generation. A new scope starts whenever either changes, and the one
/// before it has [ended]. Providers watch it through [loadFarmerData].
final class FarmerDataScope {
  FarmerDataScope._(this.farmerId, this.generation);

  /// The signed-in farmer, or null.
  final String? farmerId;

  /// The [farmerDataGenerationProvider] value.
  final int generation;

  /// True once another scope replaced this one: data loaded for it is
  /// another farmer's (or from before a data reset).
  bool get ended => _ended;
  bool _ended = false;

  @override
  String toString() => 'FarmerDataScope($farmerId, $generation)';
}

/// The current [FarmerDataScope].
final farmerDataScopeProvider = Provider<FarmerDataScope>((ref) {
  final scope = FarmerDataScope._(
    ref.watch(currentFarmerIdProvider),
    ref.watch(farmerDataGenerationProvider),
  );
  ref.onDispose(() => scope._ended = true);
  return scope;
});

/// The scope of the data each farmer-scoped provider (by its
/// [loadFarmerData] key) holds: the scope of its last successful load.
/// Bookkeeping only: nothing watches it.
final _heldScopesProvider = Provider<Map<String, FarmerDataScope>>((ref) => {});

/// For a failed load's [ApiError]: the scope of the data its provider held
/// when it failed (see [loadFarmerData]).
final _heldScopeOfError = Expando<FarmerDataScope>('held farmer scope');

/// Loads the signed-in farmer's own data for the provider named [key]
/// (unique per provider, and per family argument): watches
/// [farmerDataScopeProvider], then runs [load].
///
/// A failure is tagged with the scope of the data the provider still holds,
/// so [holdsOtherScopeData] (and with it `.fresh`) drops that data once it
/// is another scope's, instead of showing it next to the error.
///
/// Call it first thing in the provider's build. [load] may `ref.watch` only
/// what does not change while the farmer uses the app (repositories, page
/// sizes), before its first `await`: [holdsOtherScopeData] takes every
/// reload for a new farmer. To build on another farmer-scoped provider's
/// data, read it with [followFarmerData].
Future<T> loadFarmerData<T>(
  Ref ref,
  String key,
  Future<T> Function() load,
) async {
  final scope = ref.watch(farmerDataScopeProvider);
  final held = ref.read(_heldScopesProvider);
  try {
    final value = await load();
    // A build that was replaced by a newer one, or that finished for a
    // scope that has ended, did not set this provider's data.
    if (ref.mounted && !scope.ended) held[key] = scope;
    return value;
  } on Object catch (error, stack) {
    final heldScope = held[key];
    // Nothing loaded yet: no data to hide.
    if (heldScope == null) rethrow;
    final tagged = switch (error) {
      // A copy of its own: errors are often const (one `ApiError.network()`
      // for every offline call), and tagging a shared one would tag this
      // farmer's next failed refresh too.
      ApiError() => ApiError(
        code: error.code,
        message: error.message,
        status: error.status,
        details: error.details,
        retryAfter: error.retryAfter,
      ),
      _ when identical(heldScope, scope) => error,
      _ => _OtherScopeFailure(error),
    };
    if (tagged is ApiError) _heldScopeOfError[tagged] = heldScope;
    Error.throwWithStackTrace(tagged, stack);
  }
}

/// Whether [scope], read from [farmerDataScopeProvider] before an `await`,
/// is still the current one. A controller action that stores the answer to
/// a write (a consent saved, a call-back asked for) checks it after the
/// `await`: the answer for a farmer who signed out meanwhile must not land
/// on the next farmer's data. (`ref.mounted` does not tell: a notifier
/// stays mounted when it rebuilds for a new scope.)
bool isCurrentScope(Ref ref, FarmerDataScope scope) =>
    ref.mounted && identical(ref.read(farmerDataScopeProvider), scope);

/// [future] of another farmer-scoped provider, for a provider that builds on
/// its data (a notice or visit on its list, a pin from Home): read without
/// watching it. A change there (a refresh, a page loaded, a notice marked
/// read) refreshes this provider instead of reloading it, so its data stays
/// on screen meanwhile. Call it inside [loadFarmerData]'s `load`, before
/// its first `await`.
Future<T> followFarmerData<T>(Ref ref, ProviderListenable<Future<T>> future) =>
    ref.listen(future, (_, _) => ref.invalidateSelf()).read();

/// A failure (other than an [ApiError]) of a load that ran while its
/// provider held another scope's data ([loadFarmerData]). Screens show it
/// like any unknown error.
final class _OtherScopeFailure implements Exception {
  _OtherScopeFailure(this.error);

  final Object error;

  @override
  String toString() => '$error';
}

/// True when [value] carries data loaded for an earlier farmer scope, which
/// must never be shown (`.fresh` drops it): it is reloading for a new
/// scope, or that load failed (also while Riverpod retries it, or the
/// farmer tries again).
///
/// A refresh (pull-to-refresh, `ref.invalidate`, [followFarmerData]) and a
/// refresh that failed keep the farmer's own data.
bool holdsOtherScopeData(AsyncValue<Object?> value) {
  if (!value.hasValue) return false;
  // A failed load knows whose data its provider held.
  final held = switch (value.error) {
    _OtherScopeFailure() => true,
    final ApiError error => _heldScopeOfError[error]?.ended,
    _ => null,
  };
  // Otherwise only a reload can be another scope's, and is: farmer-scoped
  // providers watch nothing else that changes ([loadFarmerData]).
  return held ?? value.isReloading;
}

/// Writes to the farmer's own data that change Home (`GET /v1/farmer/me`):
/// name, plots, seasons. Each refreshes Home once the server answered, also
/// when the screen or dialog that asked was closed meanwhile (back, a tab
/// tap), so My farm never keeps showing the old data.
///
/// Read it before the first `await` (`final edits =
/// ref.read(farmerEditsProvider);`): a widget's `ref` can't be used once it
/// is disposed, this one lives as long as the app.
final farmerEditsProvider = Provider<FarmerEdits>(FarmerEdits.new);

/// See [farmerEditsProvider]. Every method throws `ApiError` for the screen
/// to show.
class FarmerEdits {
  /// Creates the writer over [_ref].
  FarmerEdits(this._ref);

  final Ref _ref;

  FarmerProfileRepository get _profile =>
      _ref.read(farmerProfileRepositoryProvider);

  /// Reloads Home and everything read from it.
  void refreshHome() => _ref.invalidate(farmerHomeProvider);

  /// Saves the name the farmer [typed] over [farmer]'s name as shown in
  /// [language] (`PATCH /v1/farmer/me`, see [renamedProfile]): always as
  /// `name`, and also as `name_te` when it is in Telugu or replaces the
  /// Telugu spelling.
  Future<void> updateName(
    String typed, {
    required Farmer farmer,
    required Language language,
  }) async {
    final (:name, :nameTe) = renamedProfile(
      typed,
      language: language,
      nameTe: farmer.nameTe,
    );
    await _profile.updateProfile(name: name, nameTe: nameTe);
    refreshHome();
  }

  /// Adds a plot (`POST /v1/farmer/me/plots`).
  Future<void> addPlot({
    String? label,
    required LatLng pin,
    required double areaAcres,
  }) async {
    await _profile.addPlot(label: label, pin: pin, areaAcres: areaAcres);
    refreshHome();
  }

  /// Starts a season on [plotId]. On `active_season_exists` Home is
  /// refreshed too: it is missing the season someone else started.
  Future<void> startSeason({
    required String plotId,
    required String seasonCode,
    required String cropId,
    LocalDate? sowingDate,
    String? previousCropId,
  }) => _refreshingHome(
    () => _profile.startSeason(
      plotId: plotId,
      seasonCode: seasonCode,
      cropId: cropId,
      sowingDate: sowingDate,
      previousCropId: previousCropId,
    ),
    staleOn: ApiErrorCode.activeSeasonExists,
  );

  /// Closes [seasonId] with [outcome]. On `season_not_active` Home is
  /// refreshed too: it still shows the season as running.
  Future<void> closeSeason({
    required String seasonId,
    required SeasonOutcome outcome,
  }) => _refreshingHome(
    () => _profile.closeSeason(seasonId: seasonId, outcome: outcome),
    staleOn: ApiErrorCode.seasonNotActive,
  );

  /// Runs [write], then refreshes Home; also when it fails with [staleOn],
  /// which means Home is out of date.
  Future<void> _refreshingHome(
    Future<Object?> Function() write, {
    required String staleOn,
  }) async {
    try {
      await write();
    } on ApiError catch (e) {
      if (e.code == staleOn) refreshHome();
      rethrow;
    }
    refreshHome();
  }
}

/// The farmer's home payload (`GET /v1/farmer/me`): profile, village, plots
/// with active seasons and stages, FA card, next visit. Used by Home,
/// Calendar, My visits (plot names) and My farm.
///
/// The payload's `farmer.status` is the server's word on the account: when
/// it is not the phase the app is in (paused by HO, or a sign-up that is not
/// complete), the session re-routes.
final farmerHomeProvider = FutureProvider<FarmerHome>(
  (ref) => loadFarmerData(ref, 'farmerHome', () async {
    final clock = ref.watch(clockProvider);
    final home = await ref.watch(farmerProfileRepositoryProvider).getHome();
    _homeLoadedAt[home] = clock.now();
    if (ref.mounted) {
      unawaited(
        ref.read(sessionProvider.notifier).applyStatus(home.farmer.status),
      );
    }
    return home;
  }),
);

/// Crops with stages, and the open season codes (`GET /v1/farmer/crops`).
/// Used by the crop calendar and the start-season flow.
final cropsProvider = FutureProvider<FarmerCropList>(
  (ref) => loadFarmerData(
    ref,
    'crops',
    () => ref.watch(mastersRepositoryProvider).listCrops(),
  ),
);

/// Unread crop advisories (`GET /v1/farmer/notices/unread-count`), for the
/// bottom-bar badge and Home's "new advice" card (F5). Invalidate it after
/// marking a notice read or listened.
final unreadNoticesCountProvider = FutureProvider<int>(
  (ref) => loadFarmerData(
    ref,
    'unreadNotices',
    () => ref.watch(noticesRepositoryProvider).getUnreadCount(),
  ),
);

/// When the Home data on screen was loaded (UTC), for Home's offline banner
/// ("saved at 7:00 am") and the new-day refresh; null before the first load.
///
/// The time of a completed load: while Home refreshes, and when the refresh
/// failed (Riverpod keeps the data then), it stays the time of the data
/// still shown, so a refresh that failed on a new day is tried again on the
/// next resume. Another farmer signing in starts again from null.
final homeSavedAtProvider = Provider<DateTime?>((ref) {
  final home = ref.watch(farmerHomeProvider);
  if (!home.hasValue || holdsOtherScopeData(home)) return null;
  return _homeLoadedAt[home.requireValue];
});

/// When each [FarmerHome] that [farmerHomeProvider] loaded arrived.
final _homeLoadedAt = Expando<DateTime>('home loaded at');

/// Refetches Home when its presigned `photo_url` stopped working (it is
/// valid for minutes; Home is kept for the whole session).
final photoUrlRefreshProvider = Provider<PhotoUrlRefresh>(PhotoUrlRefresh.new);

/// See [photoUrlRefreshProvider].
class PhotoUrlRefresh {
  /// Creates the refresher over [_ref].
  PhotoUrlRefresh(this._ref);

  final Ref _ref;

  /// At most one refetch per photo in this window, so a photo that is
  /// broken for good does not reload Home again and again.
  static const window = Duration(minutes: 10);

  final Map<String, DateTime> _refetchedAt = {};

  /// The avatar could not load [home]'s photo: refetch Home for a fresh URL,
  /// once per photo per [window]. Ignored when [home] is no longer the
  /// loaded payload. Returns whether a refetch started.
  bool photoFailed(FarmerHome home) {
    final key = home.farmer.photoKey ?? home.photoUrl;
    if (key == null) return false;
    final current = _ref.read(farmerHomeProvider);
    if (current.isLoading || current.value?.photoUrl != home.photoUrl) {
      return false;
    }
    final now = _ref.read(clockProvider).now();
    final last = _refetchedAt[key];
    if (last != null && now.difference(last) < window) return false;
    _refetchedAt[key] = now;
    _ref.invalidate(farmerHomeProvider);
    return true;
  }
}
