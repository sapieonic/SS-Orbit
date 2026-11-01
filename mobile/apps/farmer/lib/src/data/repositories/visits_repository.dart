import 'package:orbit_core/orbit_core.dart';

import '../models/models.dart';

/// My visits (F4).
///
/// Every method needs a farmer session and throws `ApiError`: `unauthorized`
/// / `device_revoked` (401), `forbidden`, `network`, plus the codes listed.
abstract interface class VisitsRepository {
  /// `GET /v1/farmer/visits?limit=&cursor=`: logged visits, newest first.
  ///
  /// [limit] 1-50 (server default 20). Pass the previous page's
  /// `nextCursor` as [cursor]. Throws `invalid_cursor`, `validation_failed`.
  Future<CursorPage<FarmerVisit>> listVisits({int? limit, String? cursor});

  /// `GET /v1/farmer/visits/next`: the next planned visit, or null.
  Future<NextVisit?> getNextVisit();
}
