import 'dart:typed_data';

import '../models/models.dart';

/// Sends file bytes to a presigned URL ([PresignedUpload]): a plain request
/// with exactly the target's method, URL and headers, without the API's auth
/// header or interceptors.
abstract interface class PhotoUploader {
  /// Uploads [bytes] to [target].
  ///
  /// Throws `ApiError`: `network` / `timeout` (retry later), `forbidden`
  /// (URL expired or signature rejected: ask for a new URL), `unavailable`
  /// (storage 5xx).
  Future<void> upload(PresignedUpload target, Uint8List bytes);
}
