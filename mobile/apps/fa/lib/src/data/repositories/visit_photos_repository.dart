import '../models/models.dart';

/// Visit photo uploads, after the LogVisit command is applied
/// (`/v1/fa/visits/{visit_id}/photos/{photo_id}/*`).
///
/// Used by the offline engine's photo queue. Every method needs an FA session
/// and throws `ApiError`: `unauthorized` / `device_revoked` (401),
/// `password_change_required` (403), `network`, plus the codes listed.
abstract interface class VisitPhotosRepository {
  /// `POST .../upload-url {content_type, bytes}`.
  ///
  /// [contentType] must match `LogVisitPhoto.content_type`; [bytes] 1 to
  /// 10 MB. Throws `not_found` (LogVisit not synced yet, or rejected: drop the
  /// photo then), `photo_already_uploaded` (409: treat as done and confirm),
  /// `validation_failed`, `forbidden` (another FA's visit).
  Future<VisitPhotoUpload> createUploadUrl({
    required String visitId,
    required String photoId,
    required PhotoContentType contentType,
    required int bytes,
  });

  /// `POST .../confirm {sha256}` (idempotent).
  ///
  /// [sha256] is the lowercase hex digest of the uploaded file. Throws
  /// `upload_missing` (409: the object is not in storage, PUT again),
  /// `not_found`, `validation_failed`, `forbidden`.
  Future<VisitPhoto> confirmUpload({
    required String visitId,
    required String photoId,
    String? sha256,
  });
}
