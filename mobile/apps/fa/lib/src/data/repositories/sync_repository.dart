import '../models/models.dart';

/// Snapshot down, commands up (`/v1/fa/sync/*`).
///
/// Used only by the offline engine (`local/sync_engine.dart`), never by
/// screens. Every method needs an FA session and throws `ApiError`:
/// `unauthorized` / `device_revoked` (401), `password_change_required`
/// (403), `forbidden`, `network`, `timeout`, `unavailable`, plus the codes
/// listed.
abstract interface class SyncRepository {
  /// `GET /v1/fa/sync/snapshot` with `If-None-Match: [ifNoneMatch]`.
  ///
  /// Returns [SnapshotNotModified] on 304 and [SnapshotFetched] (with the
  /// response's ETag) on 200. The body is gzip; implementations inflate and
  /// parse it off the UI isolate.
  Future<SnapshotResult> getSnapshot({String? ifNoneMatch});

  /// `GET /v1/fa/sync/status`: the current versions and ETag (cheap poll).
  ///
  /// Pull a snapshot only when `SyncStatus.etag` differs from the stored one.
  Future<SyncStatus> getStatus();

  /// `POST /v1/fa/sync/commands {commands}` (1-200 commands, body well under
  /// 5 MiB).
  ///
  /// Processed in order; a command ID already stored returns its stored
  /// result. Per-command outcomes are in the results, not errors. Throws
  /// `validation_failed` / `invalid_request` (the batch itself is malformed:
  /// a client bug, bisect it), `payload_too_large` (halve the batch).
  Future<CommandBatchResult> submitCommands(List<CommandIn> commands);
}
