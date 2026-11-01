import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data.dart';

/// Most villages one search or one mandal returns (the API allows 1-50 and
/// has no paging).
const villageListLimit = 50;

/// Village search for the picker: Telugu or English, prefix matches first
/// (`GET /v1/farmer/villages?q=`). The argument is the trimmed query.
final villageSearchProvider = FutureProvider.autoDispose
    .family<List<Village>, String>(
      (ref, query) => ref
          .watch(geoRepositoryProvider)
          .searchVillages(query: query, limit: villageListLimit),
    );

/// Districts and their mandals, for browsing when search finds nothing
/// (`GET /v1/farmer/geo/tree`).
final geoTreeProvider = FutureProvider.autoDispose<GeoTree>(
  (ref) => ref.watch(geoRepositoryProvider).getGeoTree(),
);

/// The villages of one mandal, by name (`GET /v1/farmer/villages?mandal_id=`).
final mandalVillagesProvider = FutureProvider.autoDispose
    .family<List<Village>, String>(
      (ref, mandalId) => ref
          .watch(geoRepositoryProvider)
          .searchVillages(mandalId: mandalId, limit: villageListLimit),
    );
