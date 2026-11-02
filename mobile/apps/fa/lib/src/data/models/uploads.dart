import 'common.dart';
import 'enums.dart';

/// Where and how to PUT a file (the shared part of `FarmerPhotoUpload` and
/// `PhotoUpload`). Upload with exactly [method], [url] and [headers], without
/// the API's auth header (`PhotoUploader`).
abstract interface class PresignedUpload {
  /// Presigned URL.
  String get url;

  /// HTTP method (`PUT`).
  String get method;

  /// Headers the phone must send with the upload.
  Map<String, String> get headers;

  /// UTC time the URL stops working; ask for a new one after it.
  DateTime get expiresAt;

  /// The object key in storage.
  String get storageKey;
}

/// A presigned upload for a farmer's photo (`FarmerPhotoUpload`,
/// `POST /v1/fa/farmers/{farmer_id}/photo/upload-url`).
///
/// After the PUT, send [storageKey] as `EnrolFarmerPayload.photo_key` or
/// `UpdateFarmerFields.photo_key`.
final class FarmerPhotoUpload implements PresignedUpload {
  /// Creates an upload target.
  const FarmerPhotoUpload({
    required this.storageKey,
    required this.url,
    required this.method,
    required this.headers,
    required this.expiresAt,
  });

  /// `farmers/{farmer_id}/photo-{uuid}.jpg`.
  @override
  final String storageKey;

  @override
  final String url;

  @override
  final String method;

  @override
  final Map<String, String> headers;

  @override
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is FarmerPhotoUpload &&
      other.storageKey == storageKey &&
      other.url == url &&
      other.method == method &&
      mapEquals(other.headers, headers) &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      Object.hash(storageKey, url, method, jsonHash(headers), expiresAt);
}

/// A presigned upload for a visit photo (`PhotoUpload`,
/// `POST /v1/fa/visits/{visit_id}/photos/{photo_id}/upload-url`).
final class VisitPhotoUpload implements PresignedUpload {
  /// Creates an upload target.
  const VisitPhotoUpload({
    required this.photoId,
    required this.storageKey,
    required this.url,
    required this.method,
    required this.headers,
    required this.expiresAt,
  });

  /// The photo (`LogVisitPhoto.photo_id`).
  final String photoId;

  @override
  final String storageKey;

  @override
  final String url;

  @override
  final String method;

  @override
  final Map<String, String> headers;

  @override
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is VisitPhotoUpload &&
      other.photoId == photoId &&
      other.storageKey == storageKey &&
      other.url == url &&
      other.method == method &&
      mapEquals(other.headers, headers) &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(
    photoId,
    storageKey,
    url,
    method,
    jsonHash(headers),
    expiresAt,
  );
}

/// A visit photo after confirm (`VisitPhoto`,
/// `POST /v1/fa/visits/{visit_id}/photos/{photo_id}/confirm`).
final class VisitPhoto {
  /// Creates a photo.
  const VisitPhoto({
    required this.id,
    required this.visitId,
    required this.contentType,
    required this.bytes,
    required this.uploadedAt,
    required this.url,
  });

  /// Photo ID.
  final String id;

  /// Visit.
  final String visitId;

  /// Image type.
  final PhotoContentType contentType;

  /// Size in bytes, or null.
  final int? bytes;

  /// UTC upload time; null until uploaded.
  final DateTime? uploadedAt;

  /// Presigned GET URL (HO only), null for the FA.
  final String? url;

  @override
  bool operator ==(Object other) =>
      other is VisitPhoto &&
      other.id == id &&
      other.visitId == visitId &&
      other.contentType == contentType &&
      other.bytes == bytes &&
      other.uploadedAt == uploadedAt &&
      other.url == url;

  @override
  int get hashCode =>
      Object.hash(id, visitId, contentType, bytes, uploadedAt, url);
}
