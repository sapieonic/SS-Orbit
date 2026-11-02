import 'package:orbit_core/orbit_core.dart';

import '../models/models.dart';

/// The FA's alerts, online (`GET /v1/fa/alerts`).
///
/// The same alerts are in the offline snapshot (section `alerts`), which is
/// what the Alerts tab shows; acknowledge with the AckAlert command. Every
/// method needs an FA session and throws `ApiError`: `unauthorized` /
/// `device_revoked` (401), `password_change_required` (403), `forbidden`,
/// `network`, plus the codes listed.
abstract interface class AlertsRepository {
  /// `GET /v1/fa/alerts?status=&limit=&cursor=`: newest first.
  ///
  /// [status] filters (all when null); [limit] 1-200 (server default 50).
  /// Throws `invalid_cursor`, `validation_failed`.
  Future<CursorPage<FaAlert>> listAlerts({
    AlertStatus? status,
    int? limit,
    String? cursor,
  });
}
