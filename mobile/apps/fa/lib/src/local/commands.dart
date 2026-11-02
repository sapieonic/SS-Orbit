// Typed sync command payloads (`<Type>Payload` in contracts/openapi/sync.yaml,
// backend CONVENTIONS section 6). Pure Dart, no Flutter import: this file
// moves to packages/orbit_sync later.
//
// JSON is snake_case exactly as the Go decoders read it
// (backend/internal/farmers/commands_payloads.go, visits/service_log.go
// `logVisitPayload`, visits/commands.go, messaging `alert_id`). Optional
// fields that are null are left out of `toJson()`; `fromJson()` accepts them
// absent or null.

import 'dart:convert';

import 'package:orbit_core/orbit_core.dart';

import '../data/models/models.dart';

/// What kind of entity a command creates or changes (the outbox's
/// `entity_type`).
enum EntityType implements WireEnum {
  /// A farmer.
  farmer('farmer'),

  /// A plot.
  plot('plot'),

  /// A crop season.
  season('season'),

  /// A visit.
  visit('visit'),

  /// A call-back request.
  callback('callback'),

  /// An FA alert.
  alert('alert');

  const EntityType(this.wire);

  @override
  final String wire;

  /// Parses a wire value; null when unknown.
  static EntityType? fromWire(String? wire) {
    for (final v in values) {
      if (v.wire == wire) return v;
    }
    return null;
  }
}

/// The 10 command types (`CommandIn.type`). The server rejects unknown types,
/// so there is no `unknown` value: [fromWire] returns null instead.
enum CommandType implements WireEnum {
  /// Enrol a farmer (farmers module). Creates a farmer.
  enrolFarmer('EnrolFarmer', EntityType.farmer),

  /// Consent captured after an enrolment without a valid proof.
  recordConsent('RecordConsent', EntityType.farmer),

  /// Create or update a plot.
  savePlot('SavePlot', EntityType.plot),

  /// Start a crop season on a plot.
  startSeason('StartSeason', EntityType.season),

  /// Change a farmer's profile.
  updateFarmer('UpdateFarmer', EntityType.farmer),

  /// Plan a visit (visits module).
  planVisit('PlanVisit', EntityType.visit),

  /// Record a visit.
  logVisit('LogVisit', EntityType.visit),

  /// Cancel a planned visit.
  cancelVisit('CancelVisit', EntityType.visit),

  /// Close a call-back request.
  closeCallback('CloseCallback', EntityType.callback),

  /// Acknowledge an alert (messaging module).
  ackAlert('AckAlert', EntityType.alert);

  const CommandType(this.wire, this.entityType);

  /// The type as the API spells it (`LogVisit`).
  @override
  final String wire;

  /// The kind of entity it creates or changes.
  final EntityType entityType;

  /// Parses a wire value; null for a type this app does not know.
  static CommandType? fromWire(String? wire) {
    for (final v in values) {
      if (v.wire == wire) return v;
    }
    return null;
  }
}

/// Value equality from `toJson()`, for the payload classes.
mixin _JsonValue {
  Map<String, Object?> toJson();

  @override
  bool operator ==(Object other) =>
      other is _JsonValue &&
      other.runtimeType == runtimeType &&
      mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => jsonHash(toJson());

  @override
  String toString() => '$runtimeType${toJson()}';
}

/// The payload of one sync command.
///
/// Outbox bookkeeping comes from the payload itself:
/// * [entityType] / [entityId]: the entity the command creates or changes.
/// * [farmerId]: the farmer it belongs to (null when the payload does not say:
///   CancelVisit, CloseCallback, AckAlert; look it up in the territory).
/// * [createdIds]: IDs this command may create (minted on the phone).
/// * [dependsOnIds]: IDs that must exist on the server first. A command's
///   parent (`depends_on_id`) is the latest earlier outbox entry whose
///   [createdIds] meet these, which gives the chain EnrolFarmer -> SavePlot ->
///   StartSeason -> PlanVisit / LogVisit -> CancelVisit. When the parent is
///   rejected, the child is dropped.
sealed class CommandPayload with _JsonValue {
  const CommandPayload();

  /// Decodes a stored or received payload of [type].
  ///
  /// Throws [FormatException] when a required field is missing, has the wrong
  /// type or an enum value this app does not know.
  static CommandPayload decode(CommandType type, Map<String, Object?> json) =>
      switch (type) {
        CommandType.enrolFarmer => EnrolFarmerPayload.fromJson(json),
        CommandType.recordConsent => RecordConsentPayload.fromJson(json),
        CommandType.savePlot => SavePlotPayload.fromJson(json),
        CommandType.startSeason => StartSeasonPayload.fromJson(json),
        CommandType.updateFarmer => UpdateFarmerPayload.fromJson(json),
        CommandType.planVisit => PlanVisitPayload.fromJson(json),
        CommandType.logVisit => LogVisitPayload.fromJson(json),
        CommandType.cancelVisit => CancelVisitPayload.fromJson(json),
        CommandType.closeCallback => CloseCallbackPayload.fromJson(json),
        CommandType.ackAlert => AckAlertPayload.fromJson(json),
      };

  /// The command type.
  CommandType get type;

  /// The kind of entity it creates or changes.
  EntityType get entityType => type.entityType;

  /// The entity it creates or changes.
  String get entityId;

  /// The farmer it belongs to, or null when the payload does not carry it.
  String? get farmerId;

  /// IDs this command may create.
  Set<String> get createdIds => {entityId};

  /// IDs that must exist on the server before this command.
  Set<String> get dependsOnIds;

  /// The snake_case `<Type>Payload` JSON.
  @override
  Map<String, Object?> toJson();

  /// This payload with every occurrence of the ID [from] replaced by [to]
  /// (after a `merged` EnrolFarmer: the local farmer ID becomes
  /// `merged_into` in every queued payload).
  CommandPayload replaceId(String from, String to) =>
      decode(type, _replaceString(toJson(), from, to)! as Map<String, Object?>);

  /// The wire command for the outbox entry [id].
  CommandIn toCommandIn({required String id, DateTime? clientCreatedAt}) =>
      CommandIn(
        id: id,
        type: type.wire,
        payload: toJson(),
        clientCreatedAt: clientCreatedAt,
      );
}

Object? _replaceString(Object? value, String from, String to) =>
    switch (value) {
      final String s => s == from ? to : s,
      final List<Object?> list => [
        for (final v in list) _replaceString(v, from, to),
      ],
      final Map<String, Object?> map => {
        for (final e in map.entries) e.key: _replaceString(e.value, from, to),
      },
      _ => value,
    };

// ---------------------------------------------------------------------------
// JSON helpers

T _known<T extends WireEnum>(T value, String key, String? wire) {
  if (value.wire.isEmpty) {
    throw FormatException('"$key" has an unknown value: $wire');
  }
  return value;
}

ConsentPurpose _purpose(String wire) =>
    _known(ConsentPurpose.fromWire(wire), 'purposes', wire);

Language _language(Map<String, Object?> json, String key) {
  final wire = json.reqString(key);
  if (wire != Language.te.wire && wire != Language.en.wire) {
    throw FormatException('"$key" has an unknown value: $wire');
  }
  return Language.fromWire(wire);
}

VisitSlot _slot(Map<String, Object?> json, String key) {
  final wire = json.reqString(key);
  return _known(VisitSlot.fromWire(wire), key, wire);
}

LatLng? _point(Map<String, Object?> json, String key) =>
    switch (json.optMap(key)) {
      final Map<String, Object?> m => LatLng.fromJson(m),
      null => null,
    };

void _put(Map<String, Object?> json, String key, Object? value) {
  if (value != null) json[key] = value;
}

// ---------------------------------------------------------------------------
// Farmers module

/// The consent given on the FA's phone (`EnrolFarmerConsent`, FAR-04).
final class EnrolConsent with _JsonValue {
  /// Creates a consent.
  const EnrolConsent({
    required this.purposes,
    required this.otpProof,
    required this.audioPlayed,
    required this.noticeVersion,
  });

  /// Reads an `EnrolFarmerConsent` object.
  factory EnrolConsent.fromJson(Map<String, Object?> json) => EnrolConsent(
    purposes: [for (final p in json.strings('purposes')) _purpose(p)],
    otpProof: json.optString('otp_proof'),
    audioPlayed: json.optBool('audio_played') ?? false,
    noticeVersion: json.optString('notice_version') ?? '',
  );

  /// Purposes agreed to; must include [ConsentPurpose.programme] with a
  /// proof.
  final List<ConsentPurpose> purposes;

  /// `ConsentProof.otpProof`, or null (offline: enrolled consent pending,
  /// RecordConsent later).
  final String? otpProof;

  /// The consent notice audio was played to the farmer.
  final bool audioPlayed;

  /// The consent notice version shown (required with a proof).
  final String noticeVersion;

  /// True when there is a proof (otherwise the farmer is consent pending).
  bool get hasProof => otpProof != null && otpProof!.isNotEmpty;

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'purposes': [for (final p in purposes) p.wire],
    };
    _put(json, 'otp_proof', otpProof);
    json['audio_played'] = audioPlayed;
    json['notice_version'] = noticeVersion;
    return json;
  }
}

/// EnrolFarmer: enrol a farmer on the FA's phone (`EnrolFarmerPayload`).
///
/// [farmerId] is minted on the phone. If the phone already belongs to a
/// farmer the result is `merged` (`merged_into` is the farmer to use), or
/// rejected `registered_with_another_fa` / `not_in_your_area`.
final class EnrolFarmerPayload extends CommandPayload {
  /// Creates the payload.
  const EnrolFarmerPayload({
    required this.farmerId,
    required this.phone,
    required this.name,
    this.nameTe,
    required this.language,
    required this.villageId,
    this.photoKey,
    required this.consent,
  });

  /// Reads an `EnrolFarmerPayload` object.
  factory EnrolFarmerPayload.fromJson(Map<String, Object?> json) =>
      EnrolFarmerPayload(
        farmerId: json.reqString('farmer_id'),
        phone: json.reqString('phone'),
        name: json.reqString('name'),
        nameTe: json.optString('name_te'),
        language: _language(json, 'language'),
        villageId: json.reqString('village_id'),
        photoKey: json.optString('photo_key'),
        consent: EnrolConsent.fromJson(json.reqMap('consent')),
      );

  @override
  final String farmerId;

  /// 10-digit Indian mobile number (+91 optional).
  final String phone;

  /// English name, 1-100 characters.
  final String name;

  /// Telugu name, or null.
  final String? nameTe;

  /// The farmer's language.
  final Language language;

  /// Village (must be in the FA's area).
  final String villageId;

  /// `FarmerPhotoUpload.storageKey` for this [farmerId], or null. Any other
  /// key is dropped by the server (the enrolment is kept).
  final String? photoKey;

  /// The consent given.
  final EnrolConsent consent;

  @override
  CommandType get type => CommandType.enrolFarmer;

  @override
  String get entityId => farmerId;

  @override
  Set<String> get dependsOnIds => const {};

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'farmer_id': farmerId,
      'phone': phone,
      'name': name,
    };
    _put(json, 'name_te', nameTe);
    json['language'] = language.wire;
    json['village_id'] = villageId;
    _put(json, 'photo_key', photoKey);
    json['consent'] = consent.toJson();
    return json;
  }
}

/// RecordConsent: consent captured after an enrolment that had no valid
/// proof (`RecordConsentPayload`). The proof must be for this FA and the
/// farmer's phone.
final class RecordConsentPayload extends CommandPayload {
  /// Creates the payload.
  const RecordConsentPayload({
    required this.farmerId,
    required this.purposes,
    required this.otpProof,
    required this.audioPlayed,
    required this.noticeVersion,
  });

  /// Reads a `RecordConsentPayload` object.
  factory RecordConsentPayload.fromJson(Map<String, Object?> json) =>
      RecordConsentPayload(
        farmerId: json.reqString('farmer_id'),
        purposes: [for (final p in json.strings('purposes')) _purpose(p)],
        otpProof: json.reqString('otp_proof'),
        audioPlayed: json.optBool('audio_played') ?? false,
        noticeVersion: json.reqString('notice_version'),
      );

  @override
  final String farmerId;

  /// Purposes agreed to (at least one).
  final List<ConsentPurpose> purposes;

  /// `ConsentProof.otpProof`.
  final String otpProof;

  /// The consent notice audio was played.
  final bool audioPlayed;

  /// The consent notice version shown.
  final String noticeVersion;

  @override
  CommandType get type => CommandType.recordConsent;

  @override
  String get entityId => farmerId;

  @override
  Set<String> get createdIds => const {};

  @override
  Set<String> get dependsOnIds => {farmerId};

  @override
  Map<String, Object?> toJson() => {
    'farmer_id': farmerId,
    'purposes': [for (final p in purposes) p.wire],
    'otp_proof': otpProof,
    'audio_played': audioPlayed,
    'notice_version': noticeVersion,
  };
}

/// SavePlot: create or update a plot (`SavePlotPayload`).
///
/// A boundary or a pin is required. [AreaSource.boundary] needs
/// [boundaryGeoJson] (the server measures the area); [AreaSource.typed] uses
/// [areaAcres]. An update carries [expectedVersion] (the `SnapPlot.version`
/// the FA saw), else a conflict comes back.
final class SavePlotPayload extends CommandPayload {
  /// Creates the payload.
  const SavePlotPayload({
    required this.plotId,
    required this.farmerId,
    required this.label,
    this.boundaryGeoJson,
    this.pin,
    required this.areaAcres,
    required this.areaSource,
    this.gpsAccuracyM,
    this.expectedVersion,
  });

  /// Reads a `SavePlotPayload` object. `boundary_geojson` may be an object or
  /// a string holding one; it is kept as compact text.
  factory SavePlotPayload.fromJson(Map<String, Object?> json) {
    final source = json.reqString('area_source');
    return SavePlotPayload(
      plotId: json.reqString('plot_id'),
      farmerId: json.reqString('farmer_id'),
      label: json.reqString('label'),
      boundaryGeoJson: SnapPlot.geoJsonText(json['boundary_geojson']),
      pin: _point(json, 'pin'),
      areaAcres: json.reqDouble('area_acres'),
      areaSource: _known(AreaSource.fromWire(source), 'area_source', source),
      gpsAccuracyM: json.optDouble('gps_accuracy_m'),
      expectedVersion: json.optInt('expected_version'),
    );
  }

  /// Plot ID (minted on the phone for a new plot).
  final String plotId;

  @override
  final String farmerId;

  /// "Plot 1", 1-60 characters.
  final String label;

  /// GeoJSON Polygon text (`polygonGeoJson`), or null. Sent as a JSON object.
  final String? boundaryGeoJson;

  /// The pin, or null.
  final LatLng? pin;

  /// Acres, more than 0 and at most 10000 (ignored for boundary).
  final double areaAcres;

  /// Boundary or typed.
  final AreaSource areaSource;

  /// GPS accuracy, 0-9999 m, or null.
  final double? gpsAccuracyM;

  /// The version being edited; null for a new plot.
  final int? expectedVersion;

  /// True for an edit of an existing plot.
  bool get isUpdate => expectedVersion != null;

  @override
  CommandType get type => CommandType.savePlot;

  @override
  String get entityId => plotId;

  @override
  Set<String> get createdIds => isUpdate ? const {} : {plotId};

  @override
  Set<String> get dependsOnIds => {farmerId, if (isUpdate) plotId};

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'plot_id': plotId,
      'farmer_id': farmerId,
      'label': label,
    };
    if (boundaryGeoJson != null) {
      json['boundary_geojson'] = jsonDecode(boundaryGeoJson!);
    }
    _put(json, 'pin', pin?.toJson());
    json['area_acres'] = areaAcres;
    json['area_source'] = areaSource.wire;
    _put(json, 'gps_accuracy_m', gpsAccuracyM);
    _put(json, 'expected_version', expectedVersion);
    return json;
  }
}

/// StartSeason: start a crop season on a plot (`StartSeasonPayload`).
final class StartSeasonPayload extends CommandPayload {
  /// Creates the payload.
  const StartSeasonPayload({
    required this.seasonId,
    required this.farmerId,
    required this.plotId,
    required this.seasonCode,
    required this.cropId,
    this.sowingDate,
    this.previousCropId,
  });

  /// Reads a `StartSeasonPayload` object.
  factory StartSeasonPayload.fromJson(Map<String, Object?> json) =>
      StartSeasonPayload(
        seasonId: json.reqString('season_id'),
        farmerId: json.reqString('farmer_id'),
        plotId: json.reqString('plot_id'),
        seasonCode: json.reqString('season_code'),
        cropId: json.reqString('crop_id'),
        sowingDate: json.optDate('sowing_date'),
        previousCropId: json.optString('previous_crop_id'),
      );

  /// Season ID (minted on the phone).
  final String seasonId;

  @override
  final String farmerId;

  /// Plot.
  final String plotId;

  /// `kharif-2026` (`^[a-z]+-[0-9]{4}(-[0-9]{2})?$`), from
  /// `SnapSeasonCodes.allOpen`.
  final String seasonCode;

  /// Crop.
  final String cropId;

  /// Sowing day, or null.
  final LocalDate? sowingDate;

  /// Previous crop, or null.
  final String? previousCropId;

  @override
  CommandType get type => CommandType.startSeason;

  @override
  String get entityId => seasonId;

  @override
  Set<String> get dependsOnIds => {farmerId, plotId};

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'season_id': seasonId,
      'farmer_id': farmerId,
      'plot_id': plotId,
      'season_code': seasonCode,
      'crop_id': cropId,
    };
    _put(json, 'sowing_date', sowingDate?.toIso());
    _put(json, 'previous_crop_id', previousCropId);
    return json;
  }
}

/// The fields UpdateFarmer changes (`UpdateFarmerFields`); null =
/// unchanged. At least one is required.
final class UpdateFarmerFields with _JsonValue {
  /// Creates the fields.
  const UpdateFarmerFields({
    this.name,
    this.nameTe,
    this.language,
    this.villageId,
    this.photoKey,
  });

  /// Reads an `UpdateFarmerFields` object.
  factory UpdateFarmerFields.fromJson(Map<String, Object?> json) =>
      UpdateFarmerFields(
        name: json.optString('name'),
        nameTe: json.optString('name_te'),
        language: json['language'] == null ? null : _language(json, 'language'),
        villageId: json.optString('village_id'),
        photoKey: json.optString('photo_key'),
      );

  /// New English name (at most 100 characters), or null.
  final String? name;

  /// New Telugu name, or null.
  final String? nameTe;

  /// New language, or null.
  final Language? language;

  /// New village, or null.
  final String? villageId;

  /// New photo key (must be under `farmers/{farmer_id}/` or the command is
  /// rejected), or null.
  final String? photoKey;

  /// True when nothing would change (the server rejects that).
  bool get isEmpty =>
      name == null &&
      nameTe == null &&
      language == null &&
      villageId == null &&
      photoKey == null;

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    _put(json, 'name', name);
    _put(json, 'name_te', nameTe);
    _put(json, 'language', language?.wire);
    _put(json, 'village_id', villageId);
    _put(json, 'photo_key', photoKey);
    return json;
  }
}

/// UpdateFarmer: change a farmer's profile (`UpdateFarmerPayload`). A field
/// the server changed since [expectedVersion] comes back as a conflict.
final class UpdateFarmerPayload extends CommandPayload {
  /// Creates the payload.
  const UpdateFarmerPayload({
    required this.farmerId,
    required this.expectedVersion,
    required this.fields,
  });

  /// Reads an `UpdateFarmerPayload` object.
  factory UpdateFarmerPayload.fromJson(Map<String, Object?> json) =>
      UpdateFarmerPayload(
        farmerId: json.reqString('farmer_id'),
        expectedVersion: json.reqInt('expected_version'),
        fields: UpdateFarmerFields.fromJson(json.reqMap('fields')),
      );

  @override
  final String farmerId;

  /// The `SnapFarmer.version` the FA saw.
  final int expectedVersion;

  /// What changes.
  final UpdateFarmerFields fields;

  @override
  CommandType get type => CommandType.updateFarmer;

  @override
  String get entityId => farmerId;

  @override
  Set<String> get createdIds => const {};

  @override
  Set<String> get dependsOnIds => {farmerId};

  @override
  Map<String, Object?> toJson() => {
    'farmer_id': farmerId,
    'expected_version': expectedVersion,
    'fields': fields.toJson(),
  };
}

// ---------------------------------------------------------------------------
// Visits module

/// PlanVisit: plan a visit for one of the FA's farmers (`PlanVisitPayload`).
final class PlanVisitPayload extends CommandPayload {
  /// Creates the payload.
  const PlanVisitPayload({
    required this.visitId,
    required this.farmerId,
    required this.plotId,
    required this.seasonId,
    required this.plannedFor,
    required this.plannedSlot,
    this.purpose,
  });

  /// Reads a `PlanVisitPayload` object.
  factory PlanVisitPayload.fromJson(Map<String, Object?> json) =>
      PlanVisitPayload(
        visitId: json.reqString('visit_id'),
        farmerId: json.reqString('farmer_id'),
        plotId: json.reqString('plot_id'),
        seasonId: json.reqString('season_id'),
        plannedFor: json.reqDate('planned_for'),
        plannedSlot: _slot(json, 'planned_slot'),
        purpose: json.optString('purpose'),
      );

  /// Visit ID (minted on the phone).
  final String visitId;

  @override
  final String farmerId;

  /// Plot.
  final String plotId;

  /// Season.
  final String seasonId;

  /// Planned day (IST).
  final LocalDate plannedFor;

  /// Planned slot.
  final VisitSlot plannedSlot;

  /// Why (free text), or null.
  final String? purpose;

  @override
  CommandType get type => CommandType.planVisit;

  @override
  String get entityId => visitId;

  @override
  Set<String> get dependsOnIds => {farmerId, plotId, seasonId};

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'visit_id': visitId,
      'farmer_id': farmerId,
      'plot_id': plotId,
      'season_id': seasonId,
      'planned_for': plannedFor.toIso(),
      'planned_slot': plannedSlot.wire,
    };
    _put(json, 'purpose', purpose);
    return json;
  }
}

/// An issue found on the visit (`LogVisitIssue`).
final class LogVisitIssue with _JsonValue {
  /// Creates an issue.
  const LogVisitIssue({
    required this.issueVisitId,
    required this.issueId,
    required this.severity,
    this.advisoryRuleId,
  });

  /// Reads a `LogVisitIssue` object.
  factory LogVisitIssue.fromJson(Map<String, Object?> json) {
    final severity = json.reqString('severity');
    return LogVisitIssue(
      issueVisitId: json.reqString('issue_visit_id'),
      issueId: json.reqString('issue_id'),
      severity: _known(Severity.fromWire(severity), 'severity', severity),
      advisoryRuleId: json.optString('advisory_rule_id'),
    );
  }

  /// Minted on the phone; unique within the visit (`SnapVisitIssue.id`).
  final String issueVisitId;

  /// The master issue (`SnapIssue.id`).
  final String issueId;

  /// How bad.
  final Severity severity;

  /// The rule picked (`SnapRule.id`); null leaves the issue unresolved. A
  /// rule that does not check out is also stored unresolved, never rejected.
  final String? advisoryRuleId;

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'issue_visit_id': issueVisitId,
      'issue_id': issueId,
      'severity': severity.wire,
    };
    _put(json, 'advisory_rule_id', advisoryRuleId);
    return json;
  }
}

/// A photo taken on the visit (`LogVisitPhoto`); uploaded after the LogVisit
/// is applied, with the same [photoId] and [contentType].
final class LogVisitPhoto with _JsonValue {
  /// Creates a photo.
  const LogVisitPhoto({required this.photoId, required this.contentType});

  /// Reads a `LogVisitPhoto` object.
  factory LogVisitPhoto.fromJson(Map<String, Object?> json) {
    final type = json.reqString('content_type');
    return LogVisitPhoto(
      photoId: json.reqString('photo_id'),
      contentType: _known(
        PhotoContentType.fromWire(type),
        'content_type',
        type,
      ),
    );
  }

  /// Photo ID (minted on the phone).
  final String photoId;

  /// Image type.
  final PhotoContentType contentType;

  @override
  Map<String, Object?> toJson() => {
    'photo_id': photoId,
    'content_type': contentType.wire,
  };
}

/// The follow-up visit planned in the same LogVisit (`LogVisitNextVisit`).
final class LogVisitNextVisit with _JsonValue {
  /// Creates a next visit.
  const LogVisitNextVisit({
    required this.visitId,
    required this.plannedFor,
    required this.plannedSlot,
  });

  /// Reads a `LogVisitNextVisit` object.
  factory LogVisitNextVisit.fromJson(Map<String, Object?> json) =>
      LogVisitNextVisit(
        visitId: json.reqString('visit_id'),
        plannedFor: json.reqDate('planned_for'),
        plannedSlot: _slot(json, 'planned_slot'),
      );

  /// A new visit ID (not the logged visit's).
  final String visitId;

  /// Planned day (IST).
  final LocalDate plannedFor;

  /// Planned slot.
  final VisitSlot plannedSlot;

  @override
  Map<String, Object?> toJson() => {
    'visit_id': visitId,
    'planned_for': plannedFor.toIso(),
    'planned_slot': plannedSlot.wire,
  };
}

/// LogVisit: record a visit, a planned one (its `visit_id`, it turns done)
/// or a new one (`LogVisitPayload`). Also closes the farmer's open
/// call-back.
final class LogVisitPayload extends CommandPayload {
  /// Creates the payload.
  const LogVisitPayload({
    required this.visitId,
    required this.farmerId,
    required this.plotId,
    required this.seasonId,
    required this.visitedAt,
    this.location,
    required this.farmerPresent,
    this.stageId,
    this.notes,
    this.issues = const [],
    this.photos = const [],
    this.nextVisit,
  });

  /// Reads a `LogVisitPayload` object.
  factory LogVisitPayload.fromJson(Map<String, Object?> json) =>
      LogVisitPayload(
        visitId: json.reqString('visit_id'),
        farmerId: json.reqString('farmer_id'),
        plotId: json.reqString('plot_id'),
        seasonId: json.reqString('season_id'),
        visitedAt: json.reqDateTime('visited_at'),
        location: _point(json, 'location'),
        farmerPresent: json.reqBool('farmer_present'),
        stageId: json.optString('stage_id'),
        notes: json.optString('notes'),
        issues: json.objects('issues', LogVisitIssue.fromJson),
        photos: json.objects('photos', LogVisitPhoto.fromJson),
        nextVisit: switch (json.optMap('next_visit')) {
          final Map<String, Object?> m => LogVisitNextVisit.fromJson(m),
          null => null,
        },
      );

  /// At most this many issues per visit.
  static const maxIssues = 20;

  /// At most this many photos per visit.
  static const maxPhotos = 20;

  /// Visit ID: the planned visit's, or a new one.
  final String visitId;

  @override
  final String farmerId;

  /// Plot.
  final String plotId;

  /// Season.
  final String seasonId;

  /// UTC time of the visit (not more than 15 minutes in the future).
  final DateTime visitedAt;

  /// Where the FA was, or null.
  final LatLng? location;

  /// Whether the farmer was there.
  final bool farmerPresent;

  /// Crop stage seen (`SnapStage.id`), or null.
  final String? stageId;

  /// Notes, or null.
  final String? notes;

  /// Issues found (at most [maxIssues]).
  final List<LogVisitIssue> issues;

  /// Photos taken (at most [maxPhotos]).
  final List<LogVisitPhoto> photos;

  /// The follow-up visit, or null.
  final LogVisitNextVisit? nextVisit;

  @override
  CommandType get type => CommandType.logVisit;

  @override
  String get entityId => visitId;

  @override
  Set<String> get createdIds => {visitId, ?nextVisit?.visitId};

  /// Not [visitId]: a LogVisit stands on its own on the server (it creates
  /// the visit when the plan never got there), so a refused PlanVisit must
  /// not take the FA's visit log down with it. The seq order still sends a
  /// LogVisit after the PlanVisit it completes.
  @override
  Set<String> get dependsOnIds => {farmerId, plotId, seasonId};

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'visit_id': visitId,
      'farmer_id': farmerId,
      'plot_id': plotId,
      'season_id': seasonId,
      'visited_at': utcIso(visitedAt),
    };
    _put(json, 'location', location?.toJson());
    json['farmer_present'] = farmerPresent;
    _put(json, 'stage_id', stageId);
    _put(json, 'notes', notes);
    json['issues'] = [for (final i in issues) i.toJson()];
    json['photos'] = [for (final p in photos) p.toJson()];
    _put(json, 'next_visit', nextVisit?.toJson());
    return json;
  }
}

/// CancelVisit: cancel a planned visit of the FA (`CancelVisitPayload`).
final class CancelVisitPayload extends CommandPayload {
  /// Creates the payload.
  const CancelVisitPayload({required this.visitId, this.reason});

  /// Reads a `CancelVisitPayload` object.
  factory CancelVisitPayload.fromJson(Map<String, Object?> json) =>
      CancelVisitPayload(
        visitId: json.reqString('visit_id'),
        reason: json.optString('reason'),
      );

  /// The planned visit.
  final String visitId;

  /// Why, or null.
  final String? reason;

  @override
  CommandType get type => CommandType.cancelVisit;

  @override
  String get entityId => visitId;

  @override
  String? get farmerId => null;

  @override
  Set<String> get createdIds => const {};

  @override
  Set<String> get dependsOnIds => {visitId};

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{'visit_id': visitId};
    _put(json, 'reason', reason);
    return json;
  }
}

/// CloseCallback: close a call-back request assigned to the FA
/// (`CloseCallbackPayload`).
final class CloseCallbackPayload extends CommandPayload {
  /// Creates the payload.
  const CloseCallbackPayload({required this.callbackId, this.note});

  /// Reads a `CloseCallbackPayload` object.
  factory CloseCallbackPayload.fromJson(Map<String, Object?> json) =>
      CloseCallbackPayload(
        callbackId: json.reqString('callback_id'),
        note: json.optString('note'),
      );

  /// The call-back (`SnapCallback.id`).
  final String callbackId;

  /// What came of the call, or null.
  final String? note;

  @override
  CommandType get type => CommandType.closeCallback;

  @override
  String get entityId => callbackId;

  @override
  String? get farmerId => null;

  @override
  Set<String> get createdIds => const {};

  @override
  Set<String> get dependsOnIds => {callbackId};

  @override
  Map<String, Object?> toJson() {
    final json = <String, Object?>{'callback_id': callbackId};
    _put(json, 'note', note);
    return json;
  }
}

// ---------------------------------------------------------------------------
// Messaging module

/// AckAlert: acknowledge one of the FA's alerts; idempotent
/// (`AckAlertPayload`).
final class AckAlertPayload extends CommandPayload {
  /// Creates the payload.
  const AckAlertPayload({required this.alertId});

  /// Reads an `AckAlertPayload` object.
  factory AckAlertPayload.fromJson(Map<String, Object?> json) =>
      AckAlertPayload(alertId: json.reqString('alert_id'));

  /// The alert (`SnapAlert.id`).
  final String alertId;

  @override
  CommandType get type => CommandType.ackAlert;

  @override
  String get entityId => alertId;

  @override
  String? get farmerId => null;

  @override
  Set<String> get createdIds => const {};

  @override
  Set<String> get dependsOnIds => {alertId};

  @override
  Map<String, Object?> toJson() => {'alert_id': alertId};
}
