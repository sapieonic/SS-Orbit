import '../models/models.dart';

/// Village picker data (self sign-up).
///
/// Works with a `pending_profile` session. Every method throws `ApiError`:
/// `unauthorized` / `device_revoked` (401), `forbidden`, `network`, plus the
/// codes listed.
abstract interface class GeoRepository {
  /// `GET /v1/farmer/villages?q=&mandal_id=&district_id=&limit=`.
  ///
  /// [query] matches English or Telugu names, prefix matches first, then
  /// fuzzy. Without [query], villages matching the filters sorted by name.
  /// [limit] 1-50 (server default 20); no paging.
  /// Throws `validation_failed`.
  Future<List<Village>> searchVillages({
    String? query,
    String? mandalId,
    String? districtId,
    int? limit,
  });

  /// `GET /v1/farmer/geo/tree`: districts and mandals to browse, then
  /// [searchVillages] with `mandalId`.
  Future<GeoTree> getGeoTree();
}
