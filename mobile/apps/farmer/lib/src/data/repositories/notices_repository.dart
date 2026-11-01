import 'package:orbit_core/orbit_core.dart';

import '../models/models.dart';

/// My Crop Advisory inbox (F5).
///
/// Every method needs a farmer session and throws `ApiError`: `unauthorized`
/// / `device_revoked` (401), `forbidden`, `network`, plus the codes listed.
abstract interface class NoticesRepository {
  /// `GET /v1/farmer/notices?limit=&cursor=`: newest first.
  ///
  /// [limit] 1-100 (server default 30). Sort `pinned` first on screen.
  /// Throws `invalid_cursor`, `validation_failed`.
  Future<CursorPage<Notice>> listNotices({int? limit, String? cursor});

  /// `GET /v1/farmer/notices/unread-count`: the badge number.
  Future<int> getUnreadCount();

  /// `POST /v1/farmer/notices/{notice_id}/read` (idempotent, 204).
  ///
  /// Call when the card is opened. Safe to retry from an outbox.
  /// Throws `not_found`.
  Future<void> markRead(String noticeId);

  /// `POST /v1/farmer/notices/{notice_id}/listened` (idempotent, 204; also
  /// marks read).
  ///
  /// Call when the voice note played to the end. Throws `not_found`.
  Future<void> markListened(String noticeId);
}
