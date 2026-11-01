import '../models/models.dart';

/// FAs for the farmer's area and "Ask your FA to call you back" (F3).
///
/// Every method needs a farmer session and throws `ApiError`: `unauthorized`
/// / `device_revoked` (401), `forbidden`, `network`, plus the codes listed.
abstract interface class FieldAssistantRepository {
  /// `GET /v1/farmer/fas?level=village|mandal|district`.
  ///
  /// Most specific level first, leads first; [level] narrows to one tab
  /// (null = all levels; never pass `AreaLevel.unknown`). Empty while the
  /// farmer has no village. Throws `validation_failed`, `not_found`.
  Future<List<FaOption>> listFas({AreaLevel? level});

  /// `POST /v1/farmer/callbacks` (no body).
  ///
  /// One open request at a time: when one is open it is returned unchanged
  /// (200), otherwise a new one is created (201) and the FA is alerted. Safe
  /// to retry from an outbox. Throws `no_fa_assigned` (409).
  Future<Callback> requestCallback();

  /// `GET /v1/farmer/callbacks/current`: the open request, or null.
  Future<Callback?> getOpenCallback();

  /// `POST /v1/farmer/callbacks/{callback_id}/cancel`: Undo.
  ///
  /// Idempotent (cancelling twice returns the cancelled request). Throws
  /// `callback_closed` (409, the FA already closed it), `not_found`.
  Future<Callback> cancelCallback(String callbackId);
}
