import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data.dart';
import '../../shared/farmer_data.dart';
import '../../shared/paged_list.dart';

/// The API's largest `limit` for `GET /v1/farmer/visits`.
const maxVisitsPageSize = 50;

/// Pages fetched at most when looking for one visit that is not loaded yet
/// (50 visits a page: far more than a farmer has in several seasons).
const _maxLookupPages = 20;

/// Nearby dealers to show under a product.
const _dealerLimit = 5;

/// Visits per page on My visits (1-50). Tests override it to page sooner.
final visitsPageSizeProvider = Provider<int>((ref) => 20);

/// What My visits (F4) shows: the next planned visit and the logged visits
/// loaded so far, newest first.
@immutable
class VisitsState {
  /// Creates the state.
  const VisitsState({required this.nextVisit, required this.visits});

  /// The next planned visit, or null when none is planned.
  final NextVisit? nextVisit;

  /// Logged visits loaded so far.
  final PagedList<FarmerVisit> visits;

  /// A copy with [visits] replaced.
  VisitsState withVisits(PagedList<FarmerVisit> visits) =>
      VisitsState(nextVisit: nextVisit, visits: visits);
}

/// Loads My visits: the next visit and the first page together (both must
/// succeed, so the screen shows one error card, not half a screen), then
/// further pages on [loadMore].
class VisitsController extends AsyncNotifier<VisitsState> {
  /// Bumped on every (re)build; a page that arrives for an older build is
  /// dropped instead of being mixed into fresh data.
  int _generation = 0;

  @override
  Future<VisitsState> build() {
    _generation++;
    // Another farmer signing in on this phone must never see these visits.
    return loadFarmerData(ref, 'visits', () async {
      final repo = ref.watch(visitsRepositoryProvider);
      final pageSize = ref.watch(visitsPageSizeProvider);
      assert(pageSize >= 1 && pageSize <= maxVisitsPageSize, 'limit 1-50');
      final nextVisit = repo.getNextVisit();
      final page = repo.listVisits(limit: pageSize);
      // Both in parallel; Future.wait handles both errors, throws the first.
      await Future.wait<Object?>([nextVisit, page]);
      return VisitsState(
        nextVisit: await nextVisit,
        visits: PagedList.firstPage(await page),
      );
    });
  }

  /// Loads the next page of visits. Does nothing while loading, refreshing
  /// or when every visit is loaded. A failure shows on the list footer.
  Future<void> loadMore() async {
    final current = state;
    final loaded = current.value;
    if (current.isLoading || loaded == null || !loaded.visits.canLoadMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(loaded.withVisits(loaded.visits.loading()));
    final repo = ref.read(visitsRepositoryProvider);
    try {
      final page = await repo.listVisits(
        limit: ref.read(visitsPageSizeProvider),
        cursor: loaded.visits.nextCursor,
      );
      _apply(generation, (v) => v.append(page, (visit) => visit.id));
    } on Object catch (error) {
      _apply(generation, (v) => v.failed(error));
    }
  }

  void _apply(
    int generation,
    PagedList<FarmerVisit> Function(PagedList<FarmerVisit> visits) update,
  ) {
    if (!ref.mounted || generation != _generation) return;
    final now = state.value;
    if (now == null) return;
    state = AsyncData(now.withVisits(update(now.visits)));
  }
}

/// My visits (F4).
final visitsControllerProvider =
    AsyncNotifierProvider<VisitsController, VisitsState>(VisitsController.new);

/// One logged visit by ID, for the advice screen.
///
/// Uses the visits My visits already loaded; when the visit is not among
/// them (a deep link, or an old visit), fetches further pages until it is
/// found. Null when the farmer has no such visit. Refreshes with My visits,
/// keeping the visit on screen meanwhile.
final visitByIdProvider = FutureProvider.autoDispose
    .family<FarmerVisit?, String>(
      (ref, visitId) =>
          loadFarmerData(ref, 'visit/$visitId', () => _visitById(ref, visitId)),
    );

Future<FarmerVisit?> _visitById(Ref ref, String visitId) async {
  final repo = ref.watch(visitsRepositoryProvider);
  final loaded = await followFarmerData(ref, visitsControllerProvider.future);
  final hit = _findVisit(loaded.visits.items, visitId);
  if (hit != null) return hit;
  var cursor = loaded.visits.nextCursor;
  for (var i = 0; cursor != null && i < _maxLookupPages; i++) {
    final page = await repo.listVisits(
      limit: maxVisitsPageSize,
      cursor: cursor,
    );
    final found = _findVisit(page.items, visitId);
    if (found != null) return found;
    cursor = page.nextCursor;
  }
  return null;
}

FarmerVisit? _findVisit(List<FarmerVisit> visits, String id) {
  for (final v in visits) {
    if (v.id == id) return v;
  }
  return null;
}

/// Which dealers to look up: shops near [near] that stock [skuId].
typedef DealerQuery = ({LatLng near, String skuId});

/// Dealers stocking the advised product near the farmer's plot, nearest
/// first (at most a handful).
final nearbyDealersProvider = FutureProvider.autoDispose
    .family<List<NearbyDealer>, DealerQuery>(
      (ref, query) => ref
          .watch(mastersRepositoryProvider)
          .listNearbyDealers(
            near: query.near,
            skuId: query.skuId,
            limit: _dealerLimit,
          ),
    );
