// Local-only rows of the FA offline engine: the command outbox, the visit
// photo queue, the sync log, sync metadata and settings. Pure Dart, no
// Flutter import: this file moves to packages/orbit_sync later.
//
// Every row is an immutable value with `copyWith`, so a Drift implementation
// of `LocalStore` can map each class to one table 1:1 (no object identity is
// relied on anywhere; a row is found again by its key).

import 'dart:typed_data';

import 'package:orbit_core/orbit_core.dart';

import '../data/models/models.dart';
import 'commands.dart';

/// Where an outbox entry is in its life (implementation plan, "Command
/// outbox").
///
/// ```text
/// queued -> sending -> applied | merged | conflict | rejected
///   ^         |                            |          |
///   +---------+ (network, 5xx, retry_from) |          +-> dependents: dropped
///                                          +-> resolved (Keep HO's, or Keep
///                                              mine, which queues a new entry)
/// ```
enum OutboxState implements WireEnum {
  /// Waiting to be sent (or to be sent again after a failure).
  queued('queued'),

  /// In a batch that is on its way. A run that dies leaves these behind; the
  /// next run puts them back to [queued] (command IDs are idempotency keys,
  /// so resending is safe).
  sending('sending'),

  /// The server applied it. Kept until a snapshot carries it, then deleted.
  applied('applied'),

  /// An EnrolFarmer the server merged into an existing farmer
  /// (`CommandResult.mergedInto`). Kept like [applied].
  merged('merged'),

  /// The server's value changed since the FA's version: waits for the FA to
  /// pick Keep mine or Keep HO's. Not replayed.
  conflict('conflict'),

  /// The server (or the app, for a client bug) refused it. Not replayed; stays
  /// on the Sync screen until the FA taps it away (30 days max).
  rejected('rejected'),

  /// Never sent because a command it depends on was rejected.
  dropped('dropped'),

  /// A conflict the FA closed (Keep HO's, or Keep mine with a new entry).
  resolved('resolved');

  const OutboxState(this.wire);

  @override
  final String wire;

  /// Parses a wire value; null when unknown.
  static OutboxState? fromWire(String? wire) {
    for (final v in values) {
      if (v.wire == wire) return v;
    }
    return null;
  }

  /// Not yet answered by the server: [queued] or [sending].
  bool get isPending => this == queued || this == sending;

  /// The server has it: [applied] or [merged].
  bool get isSynced => this == applied || this == merged;

  /// Needs the FA on the Sync screen: [conflict], [rejected] or [dropped].
  bool get needsAttention =>
      this == conflict || this == rejected || this == dropped;

  /// Its local effect has been taken back: [rejected], [dropped], [resolved].
  bool get isDiscarded =>
      this == rejected || this == dropped || this == resolved;
}

/// Keys of [OutboxEntry.meta] (local-only facts about an entry).
abstract final class OutboxMeta {
  /// UTC time after which the consent proof in an EnrolFarmer or
  /// RecordConsent is refused by the server (`ConsentProof.expiresAt`, ISO).
  static const consentProofExpiresAt = 'consent_proof_expires_at';

  /// True once an expired proof was taken out of an EnrolFarmer before
  /// sending (the farmer is enrolled consent pending; RecordConsent later).
  static const consentProofDropped = 'consent_proof_dropped';

  /// On a merged EnrolFarmer: the farmer ID the phone minted, now replaced by
  /// `merged_into` everywhere.
  static const mergedFrom = 'merged_from';

  /// On a resolved conflict: `mine` or `theirs`.
  static const resolution = 'resolution';

  /// On a conflict resolved with Keep mine: the new entry's ID.
  static const replacedBy = 'replaced_by';

  /// On the entry Keep mine queued: the conflicted entry's ID.
  static const replaces = 'replaces';

  /// On a local rejection: the server's message (e.g. the 400 body) for
  /// support; the reason code is in `CommandResult.error`.
  static const detail = 'detail';

  /// On a SavePlot update or UpdateFarmer queued while an earlier edit of
  /// the same plot / farmer was already sent and not answered: that earlier
  /// entry's ID. Its `expected_version` assumes the earlier edit applies, so
  /// the two never go in one batch, and when the earlier one comes back as a
  /// conflict this one is folded into it (one card, the FA's latest values).
  static const versionParent = 'version_parent';

  /// How many runs in a row this command, sent alone, got a 400 that could
  /// not be pinned on it (no other command could be sent to compare).
  static const lone400 = 'lone_400';

  /// On a StartSeason conflict (`active_season`): the server's active
  /// season, which the queued commands that used this season now use.
  static const seasonReplacedBy = 'season_replaced_by';

  /// On a conflicted edit: the IDs of later edits of the same entity folded
  /// into it (their values are in this entry's payload now).
  static const folded = 'folded';
}

/// Reason codes the app itself writes into a rejected or dropped entry's
/// `CommandResult.error` (the server's codes are in `ApiErrorCode`).
abstract final class LocalReason {
  /// The server refused the whole batch (400) and bisecting found this
  /// command: a client bug.
  static const clientInvalid = 'client_invalid';

  /// A command this one depends on was rejected.
  static const parentRejected = 'parent_rejected';

  /// The consent proof of a RecordConsent expired before it could be sent:
  /// take a new consent OTP.
  static const consentProofExpired = 'consent_proof_expired';

  /// A visit photo the server keeps answering "not found" for although its
  /// LogVisit was applied (the server never stored this photo ID).
  static const photoNotOnServer = 'photo_not_on_server';
}

/// Why a command was refused, for the Sync screen's red row. The UI maps
/// [code] to Telugu / English text; [RejectionCode.other] shows [message]
/// (an English sentence from the server) under a generic heading.
enum RejectionCode {
  /// "This farmer is with another FA. Call HO." (no farmer ID comes back).
  registeredWithAnotherFa,

  /// "Village is outside your area".
  notInYourArea,

  /// "Could not save. HO has been told." (failed 5 times on the server).
  serverCouldNotApply,

  /// The app sent something the server could not read (a client bug).
  clientInvalid,

  /// Not sent because a command it needed was rejected.
  parentRejected,

  /// The consent code expired before it was sent: record consent again.
  consentProofExpired,

  /// Any other reason: show [Rejection.message].
  other,
}

/// A rejection reason ([code]) with the raw text the server sent.
final class Rejection {
  /// Creates a rejection.
  const Rejection(this.code, this.message);

  /// Maps a `CommandResult.error` to a [Rejection].
  factory Rejection.fromError(String? error) => Rejection(switch (error) {
    ApiErrorCode.registeredWithAnotherFa =>
      RejectionCode.registeredWithAnotherFa,
    ApiErrorCode.notInYourArea => RejectionCode.notInYourArea,
    ApiErrorCode.serverCouldNotApply => RejectionCode.serverCouldNotApply,
    LocalReason.clientInvalid => RejectionCode.clientInvalid,
    LocalReason.parentRejected => RejectionCode.parentRejected,
    LocalReason.consentProofExpired => RejectionCode.consentProofExpired,
    _ => RejectionCode.other,
  }, error ?? '');

  /// What the UI says.
  final RejectionCode code;

  /// The raw reason (a code or an English sentence).
  final String message;

  @override
  bool operator ==(Object other) =>
      other is Rejection && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'Rejection(${code.name}: $message)';
}

/// One row of the command outbox (`outbox` table).
final class OutboxEntry {
  /// Creates an entry. A new entry passes `seq: 0`; the store assigns the
  /// real one on insert.
  const OutboxEntry({
    required this.seq,
    required this.id,
    required this.type,
    required this.payload,
    required this.entityType,
    required this.entityId,
    this.dependsOnId,
    this.state = OutboxState.queued,
    this.attempts = 0,
    this.nextAttemptAt,
    this.batchTerritoryVersion,
    this.result,
    required this.createdAt,
    required this.clientCreatedAt,
    this.meta = const {},
  });

  /// A new queued entry for [command] (seq assigned by the store).
  factory OutboxEntry.create({
    required String id,
    required CommandPayload command,
    String? dependsOnId,
    required DateTime now,
    DateTime? clientCreatedAt,
    Map<String, Object?> meta = const {},
  }) => OutboxEntry(
    seq: 0,
    id: id,
    type: command.type,
    payload: command.toJson(),
    entityType: command.entityType,
    entityId: command.entityId,
    dependsOnId: dependsOnId,
    createdAt: now.toUtc(),
    clientCreatedAt: (clientCreatedAt ?? now).toUtc(),
    meta: meta,
  );

  /// Insertion order; commands are sent in this order.
  final int seq;

  /// Command ID (UUIDv7, the server's idempotency key).
  final String id;

  /// Command type.
  final CommandType type;

  /// The `<Type>Payload` JSON.
  final Map<String, Object?> payload;

  /// The kind of entity it creates or changes.
  final EntityType entityType;

  /// The entity it creates or changes.
  final String entityId;

  /// The command it depends on (`depends_on_id`): the latest earlier entry
  /// that creates an ID this command needs. When that one is rejected, this
  /// one is dropped.
  final String? dependsOnId;

  /// Where it is.
  final OutboxState state;

  /// How many times it was sent.
  final int attempts;

  /// Not to be sent before this UTC time (backoff), or null.
  final DateTime? nextAttemptAt;

  /// The territory version the server reported for the batch that applied
  /// it. Once a snapshot at least this new is stored, the snapshot carries
  /// the change and the row is deleted.
  final int? batchTerritoryVersion;

  /// The server's answer (or the app's, for a local rejection), or null.
  final CommandResult? result;

  /// UTC time the row was written.
  final DateTime createdAt;

  /// UTC time the FA did it (`client_created_at`).
  final DateTime clientCreatedAt;

  /// Local-only facts (keys in [OutboxMeta]).
  final Map<String, Object?> meta;

  /// The typed payload.
  CommandPayload get command => CommandPayload.decode(type, payload);

  /// The farmer it belongs to, or null when the payload does not say
  /// (CancelVisit, CloseCallback, AckAlert: ask the territory).
  String? get farmerId => command.farmerId;

  /// The wire command for the batch.
  CommandIn toCommandIn() => CommandIn(
    id: id,
    type: type.wire,
    payload: payload,
    clientCreatedAt: clientCreatedAt,
  );

  /// The clash, for a [OutboxState.conflict] entry.
  Conflict? get conflict => result?.conflict;

  /// Why it was refused, for a rejected or dropped entry.
  Rejection? get rejection =>
      state == OutboxState.rejected || state == OutboxState.dropped
      ? Rejection.fromError(result?.error)
      : null;

  /// True when Keep mine can resend it (SavePlot and UpdateFarmer carry a
  /// version; a StartSeason clash on an active season can only be accepted).
  bool get canKeepMine =>
      state == OutboxState.conflict &&
      (type == CommandType.savePlot || type == CommandType.updateFarmer);

  /// A copy with the given fields replaced. Pass [clearNextAttempt] to set
  /// [nextAttemptAt] to null.
  OutboxEntry copyWith({
    int? seq,
    Map<String, Object?>? payload,
    String? entityId,
    OutboxState? state,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    int? batchTerritoryVersion,
    CommandResult? result,
    Map<String, Object?>? meta,
  }) => OutboxEntry(
    seq: seq ?? this.seq,
    id: id,
    type: type,
    payload: payload ?? this.payload,
    entityType: entityType,
    entityId: entityId ?? this.entityId,
    dependsOnId: dependsOnId,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: clearNextAttempt
        ? null
        : (nextAttemptAt ?? this.nextAttemptAt),
    batchTerritoryVersion: batchTerritoryVersion ?? this.batchTerritoryVersion,
    result: result ?? this.result,
    createdAt: createdAt,
    clientCreatedAt: clientCreatedAt,
    meta: meta ?? this.meta,
  );

  @override
  bool operator ==(Object other) =>
      other is OutboxEntry &&
      other.seq == seq &&
      other.id == id &&
      other.type == type &&
      mapEquals(other.payload, payload) &&
      other.entityType == entityType &&
      other.entityId == entityId &&
      other.dependsOnId == dependsOnId &&
      other.state == state &&
      other.attempts == attempts &&
      other.nextAttemptAt == nextAttemptAt &&
      other.batchTerritoryVersion == batchTerritoryVersion &&
      other.result == result &&
      other.createdAt == createdAt &&
      other.clientCreatedAt == clientCreatedAt &&
      mapEquals(other.meta, meta);

  @override
  int get hashCode => Object.hash(
    seq,
    id,
    type,
    jsonHash(payload),
    entityId,
    dependsOnId,
    state,
    attempts,
    nextAttemptAt,
    batchTerritoryVersion,
    result,
    createdAt,
    clientCreatedAt,
    jsonHash(meta),
  );

  @override
  String toString() => 'OutboxEntry(#$seq ${type.wire} ${state.wire} $id)';
}

/// Upload state of a visit photo (`photo_queue.state`).
enum PhotoUploadState implements WireEnum {
  /// The LogVisit it belongs to is not applied yet.
  waiting('waiting'),

  /// The LogVisit is applied: ask for an upload URL and PUT the bytes.
  ready('ready'),

  /// The bytes are in storage; confirm with the SHA-256.
  uploaded('uploaded'),

  /// Confirmed. The bytes are let go (a thumbnail is kept later).
  done('done'),

  /// Will never upload (its LogVisit was rejected or dropped, or the photo was
  /// removed while the visit was still queued).
  dropped('dropped');

  const PhotoUploadState(this.wire);

  @override
  final String wire;

  /// True while it still has to go up.
  bool get isWaiting => this == waiting || this == ready || this == uploaded;
}

/// One visit photo waiting to go up (`photo_queue` table).
///
/// The in-memory store keeps [bytes]; the Drift store keeps a file path in
/// app storage instead (the compressed ~200 KB JPEG).
final class PhotoQueueEntry {
  /// Creates a row.
  const PhotoQueueEntry({
    required this.photoId,
    required this.visitId,
    required this.commandId,
    required this.contentType,
    required this.bytes,
    required this.byteCount,
    required this.sha256,
    this.state = PhotoUploadState.waiting,
    this.attempts = 0,
    this.nextAttemptAt,
    this.storageKey,
    this.lastError,
    required this.createdAt,
  });

  /// `LogVisit.photos[].photo_id`.
  final String photoId;

  /// The visit.
  final String visitId;

  /// The LogVisit outbox entry that carries it.
  final String commandId;

  /// `LogVisit.photos[].content_type`.
  final PhotoContentType contentType;

  /// The image (empty once [PhotoUploadState.done]). Treat as read-only.
  final Uint8List bytes;

  /// Size of the image in bytes (kept after [bytes] is let go).
  final int byteCount;

  /// Lowercase hex SHA-256 of [bytes], sent on confirm.
  final String sha256;

  /// Where it is.
  final PhotoUploadState state;

  /// Failed tries so far.
  final int attempts;

  /// Not to be tried before this UTC time, or null.
  final DateTime? nextAttemptAt;

  /// `PhotoUpload.storageKey` once uploaded, or null.
  final String? storageKey;

  /// The last error code, or null.
  final String? lastError;

  /// UTC time it was taken into the queue.
  final DateTime createdAt;

  /// A copy with the given fields replaced.
  PhotoQueueEntry copyWith({
    String? commandId,
    Uint8List? bytes,
    PhotoUploadState? state,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    String? storageKey,
    String? lastError,
  }) => PhotoQueueEntry(
    photoId: photoId,
    visitId: visitId,
    commandId: commandId ?? this.commandId,
    contentType: contentType,
    bytes: bytes ?? this.bytes,
    byteCount: byteCount,
    sha256: sha256,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: clearNextAttempt
        ? null
        : (nextAttemptAt ?? this.nextAttemptAt),
    storageKey: storageKey ?? this.storageKey,
    lastError: lastError ?? this.lastError,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is PhotoQueueEntry &&
      other.photoId == photoId &&
      other.visitId == visitId &&
      other.commandId == commandId &&
      other.contentType == contentType &&
      other.byteCount == byteCount &&
      other.sha256 == sha256 &&
      other.state == state &&
      other.attempts == attempts &&
      other.nextAttemptAt == nextAttemptAt &&
      other.storageKey == storageKey &&
      other.lastError == lastError &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    photoId,
    visitId,
    commandId,
    contentType,
    byteCount,
    sha256,
    state,
    attempts,
    nextAttemptAt,
    storageKey,
    lastError,
    createdAt,
  );

  @override
  String toString() => 'PhotoQueueEntry($photoId, ${state.wire})';
}

/// What a sync log line records.
enum SyncLogKind implements WireEnum {
  /// A command was applied.
  applied('applied'),

  /// An EnrolFarmer was merged into an existing farmer.
  merged('merged'),

  /// A command came back as a conflict.
  conflict('conflict'),

  /// A command was rejected (by the server or the app).
  rejected('rejected'),

  /// A command was dropped because its parent was rejected.
  dropped('dropped'),

  /// The FA kept their version of a conflict (a new command was queued).
  keptMine('kept_mine'),

  /// The FA accepted HO's version of a conflict.
  keptTheirs('kept_theirs'),

  /// The FA tapped a rejected / dropped / resolved row away.
  dismissed('dismissed'),

  /// A visit photo was uploaded and confirmed.
  photoUploaded('photo_uploaded'),

  /// A visit photo will never upload.
  photoDropped('photo_dropped');

  const SyncLogKind(this.wire);

  @override
  final String wire;
}

/// One line of the sync log (`sync_log` table, 30 days): "records synced
/// today" and the history of rejected items.
final class SyncLogEntry {
  /// Creates a line. A new line passes `id: 0`; the store assigns one.
  const SyncLogEntry({
    required this.id,
    required this.at,
    required this.kind,
    this.commandId,
    this.commandType,
    this.entityId,
    this.farmerId,
    this.message,
  });

  /// Row ID (insertion order).
  final int id;

  /// UTC time.
  final DateTime at;

  /// What happened.
  final SyncLogKind kind;

  /// The command, or null.
  final String? commandId;

  /// Its type, or null.
  final CommandType? commandType;

  /// The entity, or null.
  final String? entityId;

  /// The farmer, or null.
  final String? farmerId;

  /// A reason or note, or null.
  final String? message;

  /// A copy with [id] replaced (used by the store on insert).
  SyncLogEntry withId(int id) => SyncLogEntry(
    id: id,
    at: at,
    kind: kind,
    commandId: commandId,
    commandType: commandType,
    entityId: entityId,
    farmerId: farmerId,
    message: message,
  );

  /// True for a command the server now has (counts as "synced").
  bool get isSynced =>
      kind == SyncLogKind.applied || kind == SyncLogKind.merged;

  @override
  bool operator ==(Object other) =>
      other is SyncLogEntry &&
      other.id == id &&
      other.at == at &&
      other.kind == kind &&
      other.commandId == commandId &&
      other.commandType == commandType &&
      other.entityId == entityId &&
      other.farmerId == farmerId &&
      other.message == message;

  @override
  int get hashCode => Object.hash(
    id,
    at,
    kind,
    commandId,
    commandType,
    entityId,
    farmerId,
    message,
  );

  @override
  String toString() => 'SyncLogEntry(${kind.wire} $commandId)';
}

/// The one `sync_meta` row.
final class SyncMeta {
  /// Creates the row; every field defaults to "never".
  const SyncMeta({
    this.etag,
    this.territoryVersion,
    this.mastersVersion,
    this.generatedAt,
    this.lastPullAt,
    this.lastPushAt,
    this.lastOnlineAt,
    this.pushFailures = 0,
    this.idAliases = const {},
  });

  /// ETag of the stored snapshot (`"t12-m3"`), or null before the first pull.
  final String? etag;

  /// Territory version of the stored snapshot.
  final int? territoryVersion;

  /// Masters version of the stored snapshot.
  final int? mastersVersion;

  /// UTC time the server built the stored snapshot.
  final DateTime? generatedAt;

  /// UTC time of the last successful pull (200 or 304).
  final DateTime? lastPullAt;

  /// UTC time of the last successful push.
  final DateTime? lastPushAt;

  /// UTC time the server last answered a sync call.
  final DateTime? lastOnlineAt;

  /// Push failures in a row (picks the backoff step); 0 after a success,
  /// a connectivity change or Sync now.
  final int pushFailures;

  /// IDs the phone minted that the server replaced: a merged farmer
  /// (`merged_from` -> `merged_into`) and a season that clashed with the
  /// plot's active one (-> the active season). The projection reads every
  /// payload through these, so the screens show one farmer and one season;
  /// queued payloads keep the farmer IDs they were written with (the server
  /// follows farmer aliases). Kept until the local data is wiped.
  final Map<String, String> idAliases;

  /// A copy with the given fields replaced.
  SyncMeta copyWith({
    String? etag,
    int? territoryVersion,
    int? mastersVersion,
    DateTime? generatedAt,
    DateTime? lastPullAt,
    DateTime? lastPushAt,
    DateTime? lastOnlineAt,
    int? pushFailures,
    Map<String, String>? idAliases,
  }) => SyncMeta(
    etag: etag ?? this.etag,
    territoryVersion: territoryVersion ?? this.territoryVersion,
    mastersVersion: mastersVersion ?? this.mastersVersion,
    generatedAt: generatedAt ?? this.generatedAt,
    lastPullAt: lastPullAt ?? this.lastPullAt,
    lastPushAt: lastPushAt ?? this.lastPushAt,
    lastOnlineAt: lastOnlineAt ?? this.lastOnlineAt,
    pushFailures: pushFailures ?? this.pushFailures,
    idAliases: idAliases ?? this.idAliases,
  );

  @override
  bool operator ==(Object other) =>
      other is SyncMeta &&
      other.etag == etag &&
      other.territoryVersion == territoryVersion &&
      other.mastersVersion == mastersVersion &&
      other.generatedAt == generatedAt &&
      other.lastPullAt == lastPullAt &&
      other.lastPushAt == lastPushAt &&
      other.lastOnlineAt == lastOnlineAt &&
      other.pushFailures == pushFailures &&
      mapEquals(other.idAliases, idAliases);

  @override
  int get hashCode => Object.hash(
    etag,
    territoryVersion,
    mastersVersion,
    generatedAt,
    lastPullAt,
    lastPushAt,
    lastOnlineAt,
    pushFailures,
    jsonHash(idAliases),
  );

  @override
  String toString() => 'SyncMeta($etag, failures $pushFailures)';
}

/// FA settings kept with the local data (wiped with it).
final class LocalSettings {
  /// Creates the settings.
  const LocalSettings({this.photosOnWifiOnly = true});

  /// "Upload photos on Wi-Fi only" (records still sync on mobile data).
  final bool photosOnWifiOnly;

  /// A copy with the given fields replaced.
  LocalSettings copyWith({bool? photosOnWifiOnly}) => LocalSettings(
    photosOnWifiOnly: photosOnWifiOnly ?? this.photosOnWifiOnly,
  );

  @override
  bool operator ==(Object other) =>
      other is LocalSettings && other.photosOnWifiOnly == photosOnWifiOnly;

  @override
  int get hashCode => photosOnWifiOnly.hashCode;
}
