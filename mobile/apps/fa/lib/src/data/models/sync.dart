import 'common.dart';

/// Current snapshot versions (`SyncStatus`, `GET /v1/fa/sync/status`).
///
/// Pull a snapshot only when [etag] differs from the one the app holds.
final class SyncStatus {
  /// Creates a status.
  const SyncStatus({
    required this.territoryVersion,
    required this.mastersVersion,
    required this.etag,
  });

  /// Reads a `SyncStatus` object.
  factory SyncStatus.fromJson(Map<String, Object?> json) => SyncStatus(
    territoryVersion: json.reqInt('territory_version'),
    mastersVersion: json.reqInt('masters_version'),
    etag: json.reqString('etag'),
  );

  /// Territory version.
  final int territoryVersion;

  /// Masters version.
  final int mastersVersion;

  /// The current snapshot's ETag, `"t12-m3"` (with the quotes).
  final String etag;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.territoryVersion == territoryVersion &&
      other.mastersVersion == mastersVersion &&
      other.etag == etag;

  @override
  int get hashCode => Object.hash(territoryVersion, mastersVersion, etag);

  @override
  String toString() => 'SyncStatus($etag)';
}

/// One command sent up (`CommandIn` in `POST /v1/fa/sync/commands`).
///
/// The offline engine builds these from outbox rows; the typed payloads live
/// in `local/commands.dart` (`CommandPayload.toJson()` gives [payload]).
final class CommandIn {
  /// Creates a command.
  const CommandIn({
    required this.id,
    required this.type,
    required this.payload,
    this.clientCreatedAt,
  });

  /// Reads a `CommandIn` object.
  factory CommandIn.fromJson(Map<String, Object?> json) => CommandIn(
    id: json.reqString('id'),
    type: json.reqString('type'),
    payload: json.reqMap('payload'),
    clientCreatedAt: json.optDateTime('client_created_at'),
  );

  /// UUIDv7 minted on the phone; the idempotency key. Never reuse it for a
  /// different payload.
  final String id;

  /// Command type, e.g. `LogVisit` (`CommandType.wire`).
  final String type;

  /// The snake_case `<Type>Payload` JSON.
  final Map<String, Object?> payload;

  /// UTC time the FA did this on the phone, or null.
  final DateTime? clientCreatedAt;

  /// `{id, type, payload, client_created_at}`.
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'client_created_at': clientCreatedAt == null
        ? null
        : utcIso(clientCreatedAt!),
  };

  @override
  bool operator ==(Object other) =>
      other is CommandIn &&
      other.id == id &&
      other.type == type &&
      mapEquals(other.payload, payload) &&
      other.clientCreatedAt == clientCreatedAt;

  @override
  int get hashCode => Object.hash(id, type, jsonHash(payload), clientCreatedAt);

  @override
  String toString() => 'CommandIn($type, $id)';
}

/// How the server handled a command (`CommandStatus`).
enum CommandStatus implements WireEnum {
  /// Applied as sent.
  applied('applied'),

  /// Merged into an existing entity (EnrolFarmer for a known phone): use
  /// `CommandResult.mergedInto`.
  merged('merged'),

  /// The server's value changed since the FA's version (SavePlot,
  /// UpdateFarmer): see `CommandResult.conflict`.
  conflict('conflict'),

  /// Not applied: `CommandResult.error` says why. Drop it and its dependents.
  rejected('rejected'),

  /// A status this app version does not know (treat as rejected).
  unknown('');

  const CommandStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static CommandStatus fromWire(String? wire) =>
      enumFromWire(values, wire, CommandStatus.unknown);
}

/// A field that changed on the server since the FA's version (`Conflict`).
final class Conflict {
  /// Creates a conflict.
  const Conflict({
    required this.field,
    required this.yours,
    required this.theirs,
  });

  /// Reads a `Conflict` object.
  factory Conflict.fromJson(Map<String, Object?> json) => Conflict(
    field: json.reqString('field'),
    yours: json['yours'],
    theirs: json['theirs'],
  );

  /// The field name, e.g. `area_acres` or `name`.
  final String field;

  /// The value the FA sent (decoded JSON: string, number, map, ...).
  final Object? yours;

  /// The value on the server (decoded JSON).
  final Object? theirs;

  /// `{field, yours, theirs}`.
  Map<String, Object?> toJson() => {
    'field': field,
    'yours': yours,
    'theirs': theirs,
  };

  @override
  bool operator ==(Object other) =>
      other is Conflict &&
      other.field == field &&
      jsonEquals(other.yours, yours) &&
      jsonEquals(other.theirs, theirs);

  @override
  int get hashCode => Object.hash(field, jsonHash(yours), jsonHash(theirs));

  @override
  String toString() => 'Conflict($field: $yours vs $theirs)';
}

/// Outcome of one command, as stored on the server (`CommandResult`).
final class CommandResult {
  /// Creates a result.
  const CommandResult({
    required this.id,
    required this.status,
    this.entityId,
    this.mergedInto,
    this.conflict,
    this.error,
  });

  /// Reads a `CommandResult` object.
  factory CommandResult.fromJson(Map<String, Object?> json) => CommandResult(
    id: json.reqString('id'),
    status: CommandStatus.fromWire(json.optString('status')),
    entityId: json.optString('entity_id'),
    mergedInto: json.optString('merged_into'),
    conflict: switch (json.optMap('conflict')) {
      final Map<String, Object?> m => Conflict.fromJson(m),
      null => null,
    },
    error: json.optString('error'),
  );

  /// The command ID.
  final String id;

  /// What happened.
  final CommandStatus status;

  /// The entity created or changed; null when rejected before it was known.
  /// A `registered_with_another_fa` rejection still carries the farmer ID
  /// the phone minted.
  final String? entityId;

  /// For [CommandStatus.merged], the existing entity to use instead.
  final String? mergedInto;

  /// For [CommandStatus.conflict], the field that clashed.
  final Conflict? conflict;

  /// For [CommandStatus.rejected], why: a code the app maps to text
  /// (`registered_with_another_fa`, `not_in_your_area`,
  /// `server_could_not_apply`; see `ApiErrorCode`) or an English sentence.
  final String? error;

  /// `{id, status, entity_id, merged_into, conflict, error}`.
  Map<String, Object?> toJson() => {
    'id': id,
    'status': status.wire,
    'entity_id': entityId,
    'merged_into': mergedInto,
    'conflict': conflict?.toJson(),
    'error': error,
  };

  @override
  bool operator ==(Object other) =>
      other is CommandResult &&
      other.id == id &&
      other.status == status &&
      other.entityId == entityId &&
      other.mergedInto == mergedInto &&
      other.conflict == conflict &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(id, status, entityId, mergedInto, conflict, error);

  @override
  String toString() => 'CommandResult($id, ${status.wire})';
}

/// Results of a pushed batch (`CommandBatchResult`,
/// `POST /v1/fa/sync/commands`).
final class CommandBatchResult {
  /// Creates a batch result.
  const CommandBatchResult({
    required this.results,
    required this.retryFrom,
    required this.territoryVersion,
    required this.mastersVersion,
  });

  /// Reads a `CommandBatchResult` object.
  factory CommandBatchResult.fromJson(Map<String, Object?> json) =>
      CommandBatchResult(
        results: json.objects('results', CommandResult.fromJson),
        retryFrom: json.optInt('retry_from'),
        territoryVersion: json.reqInt('territory_version'),
        mastersVersion: json.reqInt('masters_version'),
      );

  /// Results of the processed commands, in request order (covers
  /// `[0, retryFrom)` when [retryFrom] is set).
  final List<CommandResult> results;

  /// Index of the first command not processed (server-side failure): resend
  /// from here after backoff. Null when every command was processed.
  final int? retryFrom;

  /// The FA's territory version now.
  final int territoryVersion;

  /// The masters version now.
  final int mastersVersion;

  /// True when every command in the batch was processed.
  bool get complete => retryFrom == null;

  /// `{results, retry_from, territory_version, masters_version}`.
  Map<String, Object?> toJson() => {
    'results': [for (final r in results) r.toJson()],
    'retry_from': retryFrom,
    'territory_version': territoryVersion,
    'masters_version': mastersVersion,
  };

  @override
  bool operator ==(Object other) =>
      other is CommandBatchResult &&
      listEquals(other.results, results) &&
      other.retryFrom == retryFrom &&
      other.territoryVersion == territoryVersion &&
      other.mastersVersion == mastersVersion;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(results),
    retryFrom,
    territoryVersion,
    mastersVersion,
  );
}
