import '../models/models.dart';

/// Crops, stage calendars, season codes and dealers (masters data).
///
/// Every method needs a farmer session and throws `ApiError`: `unauthorized`
/// / `device_revoked` (401), `forbidden`, `network`, plus the codes listed.
abstract interface class MastersRepository {
  /// `GET /v1/farmer/crops`: active crops with stages, and today's season
  /// codes. Cache it; refresh after `seasonCodes.validUntil`.
  Future<FarmerCropList> listCrops();

  /// `GET /v1/farmer/dealers?lat=&lng=&radius_km=&sku_id=&limit=`: active
  /// dealers nearest first.
  ///
  /// [radiusKm] 0.1-100 (server default 25), [skuId] only dealers stocking
  /// it, [limit] 1-50 (server default 20). Throws `validation_failed`.
  Future<List<NearbyDealer>> listNearbyDealers({
    required LatLng near,
    double? radiusKm,
    String? skuId,
    int? limit,
  });
}
