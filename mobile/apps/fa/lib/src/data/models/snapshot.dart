import 'dart:convert';

import 'package:orbit_core/orbit_core.dart';

import 'common.dart';
import 'enums.dart';
import 'masters.dart';

/// One farmer the FA may act on (`SnapFarmer`, snapshot section `farmers`).
///
/// The snapshot holds exactly the farmers the FA may act on.
final class SnapFarmer {
  /// Creates a farmer.
  const SnapFarmer({
    required this.id,
    required this.phone,
    required this.name,
    required this.nameTe,
    required this.language,
    required this.villageId,
    required this.source,
    required this.photoKey,
    required this.plan,
    required this.status,
    required this.consentsGranted,
    required this.consentPending,
    required this.profileCompletedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Reads a `SnapFarmer` object.
  factory SnapFarmer.fromJson(Map<String, Object?> json) => SnapFarmer(
    id: json.reqString('id'),
    phone: json.reqString('phone'),
    name: json.optString('name'),
    nameTe: json.optString('name_te'),
    language: Language.fromWire(json.optString('language')),
    villageId: json.optString('village_id'),
    source: FarmerSource.fromWire(json.optString('source')),
    photoKey: json.optString('photo_key'),
    plan: Plan.fromWire(json.optString('plan')),
    status: FarmerStatus.fromWire(json.optString('status')),
    consentsGranted: [
      for (final p in json.strings('consents_granted'))
        ConsentPurpose.fromWire(p),
    ],
    consentPending: json.reqBool('consent_pending'),
    profileCompletedAt: json.optDateTime('profile_completed_at'),
    version: json.reqInt('version'),
    createdAt: json.reqDateTime('created_at'),
    updatedAt: json.reqDateTime('updated_at'),
  );

  /// Farmer ID.
  final String id;

  /// E.164 phone (`+919000000101`).
  final String phone;

  /// English name, or null (self sign-up not finished).
  final String? name;

  /// Telugu name, or null.
  final String? nameTe;

  /// The farmer's language.
  final Language language;

  /// Village, or null (self sign-up not finished).
  final String? villageId;

  /// How the farmer came in.
  final FarmerSource source;

  /// Storage key of the photo, or null.
  final String? photoKey;

  /// Plan.
  final Plan plan;

  /// Account status (`pending_profile` = needs enrolment).
  final FarmerStatus status;

  /// Purposes the farmer has consented to.
  final List<ConsentPurpose> consentsGranted;

  /// No programme consent yet: show it and send RecordConsent once the farmer
  /// agrees.
  final bool consentPending;

  /// UTC time the profile was completed, or null.
  final DateTime? profileCompletedAt;

  /// Row version: `UpdateFarmerPayload.expected_version`.
  final int version;

  /// UTC creation time.
  final DateTime createdAt;

  /// UTC last update.
  final DateTime updatedAt;

  /// The name to show in [language] (empty when the farmer has none yet).
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  /// The `SnapFarmer` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'name_te': nameTe,
    'language': language.wire,
    'village_id': villageId,
    'source': source.wire,
    'photo_key': photoKey,
    'plan': plan.wire,
    'status': status.wire,
    'consents_granted': [for (final p in consentsGranted) p.wire],
    'consent_pending': consentPending,
    'profile_completed_at': _time(profileCompletedAt),
    'version': version,
    'created_at': utcIso(createdAt),
    'updated_at': utcIso(updatedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is SnapFarmer &&
      other.id == id &&
      other.phone == phone &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.language == language &&
      other.villageId == villageId &&
      other.source == source &&
      other.photoKey == photoKey &&
      other.plan == plan &&
      other.status == status &&
      listEquals(other.consentsGranted, consentsGranted) &&
      other.consentPending == consentPending &&
      other.profileCompletedAt == profileCompletedAt &&
      other.version == version &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    phone,
    name,
    nameTe,
    language,
    villageId,
    source,
    photoKey,
    plan,
    status,
    Object.hashAll(consentsGranted),
    consentPending,
    profileCompletedAt,
    version,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'SnapFarmer($id, $name)';
}

/// A plot of one of those farmers (`SnapPlot`, snapshot section `plots`).
///
/// The boundary is kept as **GeoJSON text** ([boundaryGeoJson]), the form the
/// local database stores and `SavePlotPayload.boundary_geojson` sends; use
/// [boundaryRings] to draw it and `polygonGeoJson` to build one from a walked
/// ring.
final class SnapPlot {
  /// Creates a plot.
  const SnapPlot({
    required this.id,
    required this.farmerId,
    required this.label,
    required this.villageId,
    required this.boundaryGeoJson,
    required this.pin,
    required this.areaAcres,
    required this.areaSource,
    required this.gpsAccuracyM,
    required this.status,
    required this.version,
    required this.updatedAt,
  });

  /// Reads a `SnapPlot` object. `boundary` may be a GeoJSON object or a
  /// string holding one; it is kept as compact text.
  factory SnapPlot.fromJson(Map<String, Object?> json) => SnapPlot(
    id: json.reqString('id'),
    farmerId: json.reqString('farmer_id'),
    label: json.reqString('label'),
    villageId: json.optString('village_id'),
    boundaryGeoJson: geoJsonText(json['boundary']),
    pin: switch (json.optMap('pin')) {
      final Map<String, Object?> m => LatLng.fromJson(m),
      null => null,
    },
    areaAcres: json.reqDouble('area_acres'),
    areaSource: AreaSource.fromWire(json.optString('area_source')),
    gpsAccuracyM: json.optDouble('gps_accuracy_m'),
    status: PlotStatus.fromWire(json.optString('status')),
    version: json.reqInt('version'),
    updatedAt: json.reqDateTime('updated_at'),
  );

  /// Plot ID.
  final String id;

  /// Owner.
  final String farmerId;

  /// "Plot 1".
  final String label;

  /// Village, or null.
  final String? villageId;

  /// GeoJSON Polygon/MultiPolygon text, or null when only a pin was taken.
  final String? boundaryGeoJson;

  /// The pin dropped on the plot, or null.
  final SnapPoint? pin;

  /// Acres (40 guntas = 1 acre; orbit_core `AcresGuntas`).
  final double areaAcres;

  /// Where [areaAcres] came from.
  final AreaSource areaSource;

  /// GPS accuracy when the boundary or pin was taken, metres.
  final double? gpsAccuracyM;

  /// Active or archived.
  final PlotStatus status;

  /// Row version: `SavePlotPayload.expected_version` for an edit.
  final int version;

  /// UTC last update.
  final DateTime updatedAt;

  /// The outer rings of [boundaryGeoJson] (empty when there is none).
  List<List<LatLng>> get boundaryRings => geoJsonOuterRings(boundaryGeoJson);

  /// A GeoJSON value from JSON (object, string or null) as compact text.
  static String? geoJsonText(Object? value) => switch (value) {
    null => null,
    final String s when s.isEmpty => null,
    final String s => s,
    _ => jsonEncode(value),
  };

  /// The `SnapPlot` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'farmer_id': farmerId,
    'label': label,
    'village_id': villageId,
    'boundary': _geoJsonValue(boundaryGeoJson),
    'pin': pin?.toJson(),
    'area_acres': areaAcres,
    'area_source': areaSource.wire,
    'gps_accuracy_m': gpsAccuracyM,
    'status': status.wire,
    'version': version,
    'updated_at': utcIso(updatedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is SnapPlot &&
      other.id == id &&
      other.farmerId == farmerId &&
      other.label == label &&
      other.villageId == villageId &&
      other.boundaryGeoJson == boundaryGeoJson &&
      other.pin == pin &&
      other.areaAcres == areaAcres &&
      other.areaSource == areaSource &&
      other.gpsAccuracyM == gpsAccuracyM &&
      other.status == status &&
      other.version == version &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    farmerId,
    label,
    villageId,
    boundaryGeoJson,
    pin,
    areaAcres,
    areaSource,
    gpsAccuracyM,
    status,
    version,
    updatedAt,
  );

  @override
  String toString() => 'SnapPlot($id, $label)';
}

/// A season on one of those plots (`SnapSeason`, snapshot section `seasons`).
final class SnapSeason {
  /// Creates a season.
  const SnapSeason({
    required this.id,
    required this.farmerId,
    required this.plotId,
    required this.seasonCode,
    required this.cropId,
    required this.sowingDate,
    required this.previousCropId,
    required this.status,
    required this.version,
    required this.updatedAt,
  });

  /// Reads a `SnapSeason` object.
  factory SnapSeason.fromJson(Map<String, Object?> json) => SnapSeason(
    id: json.reqString('id'),
    farmerId: json.reqString('farmer_id'),
    plotId: json.reqString('plot_id'),
    seasonCode: json.reqString('season_code'),
    cropId: json.reqString('crop_id'),
    sowingDate: json.optDate('sowing_date'),
    previousCropId: json.optString('previous_crop_id'),
    status: SeasonStatus.fromWire(json.optString('status')),
    version: json.reqInt('version'),
    updatedAt: json.reqDateTime('updated_at'),
  );

  /// Season ID.
  final String id;

  /// Owner.
  final String farmerId;

  /// Plot.
  final String plotId;

  /// `kharif-2026`.
  final String seasonCode;

  /// Crop.
  final String cropId;

  /// Sowing day (IST), or null.
  final LocalDate? sowingDate;

  /// Crop of the previous season, or null.
  final String? previousCropId;

  /// Active, harvested or abandoned.
  final SeasonStatus status;

  /// Row version.
  final int version;

  /// UTC last update.
  final DateTime updatedAt;

  /// Days from sowing to [today] (sowing day = 0), or null without a sowing
  /// date.
  int? daysAfterSowing(LocalDate today) => sowingDate?.daysUntil(today);

  /// The `SnapSeason` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'farmer_id': farmerId,
    'plot_id': plotId,
    'season_code': seasonCode,
    'crop_id': cropId,
    'sowing_date': sowingDate?.toIso(),
    'previous_crop_id': previousCropId,
    'status': status.wire,
    'version': version,
    'updated_at': utcIso(updatedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is SnapSeason &&
      other.id == id &&
      other.farmerId == farmerId &&
      other.plotId == plotId &&
      other.seasonCode == seasonCode &&
      other.cropId == cropId &&
      other.sowingDate == sowingDate &&
      other.previousCropId == previousCropId &&
      other.status == status &&
      other.version == version &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    farmerId,
    plotId,
    seasonCode,
    cropId,
    sowingDate,
    previousCropId,
    status,
    version,
    updatedAt,
  );
}

/// An issue found on a visit with the advice given (`SnapVisitIssue`).
final class SnapVisitIssue {
  /// Creates a visit issue.
  const SnapVisitIssue({
    required this.id,
    required this.issueId,
    required this.issueName,
    required this.issueNameTe,
    required this.severity,
    required this.adviceStatus,
    required this.ruleId,
    required this.saltId,
    required this.saltName,
    required this.saltNameTe,
    required this.skuId,
    required this.productName,
    required this.productNameTe,
    required this.dose,
    required this.doseTe,
  });

  /// Reads a `SnapVisitIssue` object.
  factory SnapVisitIssue.fromJson(Map<String, Object?> json) => SnapVisitIssue(
    id: json.reqString('id'),
    issueId: json.reqString('issue_id'),
    issueName: json.optString('issue_name'),
    issueNameTe: json.optString('issue_name_te'),
    severity: Severity.fromWire(json.optString('severity')),
    adviceStatus: AdviceStatus.fromWire(json.optString('advice_status')),
    ruleId: json.optString('rule_id'),
    saltId: json.optString('salt_id'),
    saltName: json.optString('salt_name'),
    saltNameTe: json.optString('salt_name_te'),
    skuId: json.optString('sku_id'),
    productName: json.optString('product_name'),
    productNameTe: json.optString('product_name_te'),
    dose: json.optString('dose'),
    doseTe: json.optString('dose_te'),
  );

  /// Row ID (`LogVisitIssue.issue_visit_id`).
  final String id;

  /// The master issue.
  final String issueId;

  /// English issue name, or null.
  final String? issueName;

  /// Telugu issue name, or null.
  final String? issueNameTe;

  /// How bad it was.
  final Severity severity;

  /// Given or unresolved; every advice field below is null when unresolved.
  final AdviceStatus adviceStatus;

  /// The rule picked, or null.
  final String? ruleId;

  /// Salt advised, or null.
  final String? saltId;

  /// English salt name, or null.
  final String? saltName;

  /// Telugu salt name, or null.
  final String? saltNameTe;

  /// SKU advised, or null.
  final String? skuId;

  /// English product name, or null.
  final String? productName;

  /// Telugu product name, or null.
  final String? productNameTe;

  /// English dose, or null.
  final String? dose;

  /// Telugu dose, or null.
  final String? doseTe;

  /// The `SnapVisitIssue` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'issue_id': issueId,
    'issue_name': issueName,
    'issue_name_te': issueNameTe,
    'severity': severity.wire,
    'advice_status': adviceStatus.wire,
    'rule_id': ruleId,
    'salt_id': saltId,
    'salt_name': saltName,
    'salt_name_te': saltNameTe,
    'sku_id': skuId,
    'product_name': productName,
    'product_name_te': productNameTe,
    'dose': dose,
    'dose_te': doseTe,
  };

  @override
  bool operator ==(Object other) =>
      other is SnapVisitIssue &&
      other.id == id &&
      other.issueId == issueId &&
      other.issueName == issueName &&
      other.issueNameTe == issueNameTe &&
      other.severity == severity &&
      other.adviceStatus == adviceStatus &&
      other.ruleId == ruleId &&
      other.saltId == saltId &&
      other.saltName == saltName &&
      other.saltNameTe == saltNameTe &&
      other.skuId == skuId &&
      other.productName == productName &&
      other.productNameTe == productNameTe &&
      other.dose == dose &&
      other.doseTe == doseTe;

  @override
  int get hashCode => Object.hash(
    id,
    issueId,
    issueName,
    issueNameTe,
    severity,
    adviceStatus,
    ruleId,
    saltId,
    saltName,
    saltNameTe,
    skuId,
    productName,
    productNameTe,
    dose,
    doseTe,
  );
}

/// A planned visit, or one of the 3 latest completed visits per farmer
/// (`SnapVisit`, snapshot section `visits`).
final class SnapVisit {
  /// Creates a visit.
  const SnapVisit({
    required this.id,
    required this.farmerId,
    required this.plotId,
    required this.seasonId,
    required this.faId,
    required this.status,
    required this.plannedFor,
    required this.plannedSlot,
    required this.purpose,
    required this.visitedAt,
    required this.farmerPresent,
    required this.stageId,
    required this.stageName,
    required this.stageNameTe,
    required this.notes,
    required this.photoCount,
    required this.issues,
  });

  /// Reads a `SnapVisit` object.
  factory SnapVisit.fromJson(Map<String, Object?> json) => SnapVisit(
    id: json.reqString('id'),
    farmerId: json.reqString('farmer_id'),
    plotId: json.reqString('plot_id'),
    seasonId: json.reqString('season_id'),
    faId: json.reqString('fa_id'),
    status: VisitStatus.fromWire(json.optString('status')),
    plannedFor: json.optDate('planned_for'),
    plannedSlot: switch (json.optString('planned_slot')) {
      final String s => VisitSlot.fromWire(s),
      null => null,
    },
    purpose: json.optString('purpose'),
    visitedAt: json.optDateTime('visited_at'),
    farmerPresent: json.optBool('farmer_present'),
    stageId: json.optString('stage_id'),
    stageName: json.optString('stage_name'),
    stageNameTe: json.optString('stage_name_te'),
    notes: json.optString('notes'),
    photoCount: json.optInt('photo_count') ?? 0,
    issues: json.objects('issues', SnapVisitIssue.fromJson),
  );

  /// Visit ID.
  final String id;

  /// Farmer.
  final String farmerId;

  /// Plot.
  final String plotId;

  /// Season.
  final String seasonId;

  /// The FA.
  final String faId;

  /// Planned, done, ...
  final VisitStatus status;

  /// Planned day (IST), or null.
  final LocalDate? plannedFor;

  /// Planned slot, or null.
  final VisitSlot? plannedSlot;

  /// Why the visit is planned (free text), or null.
  final String? purpose;

  /// UTC time it was logged, or null.
  final DateTime? visitedAt;

  /// Whether the farmer was there, or null (not logged).
  final bool? farmerPresent;

  /// Crop stage seen, or null.
  final String? stageId;

  /// English stage name, or null.
  final String? stageName;

  /// Telugu stage name, or null.
  final String? stageNameTe;

  /// The FA's notes, or null.
  final String? notes;

  /// Photos recorded on the visit.
  final int photoCount;

  /// Issues found.
  final List<SnapVisitIssue> issues;

  /// The `SnapVisit` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'farmer_id': farmerId,
    'plot_id': plotId,
    'season_id': seasonId,
    'fa_id': faId,
    'status': status.wire,
    'planned_for': plannedFor?.toIso(),
    'planned_slot': plannedSlot?.wire,
    'purpose': purpose,
    'visited_at': _time(visitedAt),
    'farmer_present': farmerPresent,
    'stage_id': stageId,
    'stage_name': stageName,
    'stage_name_te': stageNameTe,
    'notes': notes,
    'photo_count': photoCount,
    'issues': [for (final i in issues) i.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is SnapVisit &&
      other.id == id &&
      other.farmerId == farmerId &&
      other.plotId == plotId &&
      other.seasonId == seasonId &&
      other.faId == faId &&
      other.status == status &&
      other.plannedFor == plannedFor &&
      other.plannedSlot == plannedSlot &&
      other.purpose == purpose &&
      other.visitedAt == visitedAt &&
      other.farmerPresent == farmerPresent &&
      other.stageId == stageId &&
      other.stageName == stageName &&
      other.stageNameTe == stageNameTe &&
      other.notes == notes &&
      other.photoCount == photoCount &&
      listEquals(other.issues, issues);

  @override
  int get hashCode => Object.hash(
    id,
    farmerId,
    plotId,
    seasonId,
    faId,
    status,
    plannedFor,
    plannedSlot,
    purpose,
    visitedAt,
    farmerPresent,
    stageId,
    stageName,
    stageNameTe,
    notes,
    photoCount,
    Object.hashAll(issues),
  );

  @override
  String toString() => 'SnapVisit($id, ${status.wire})';
}

/// An open call-back request for the FA (`SnapCallback`, snapshot section
/// `callbacks`).
final class SnapCallback {
  /// Creates a call-back.
  const SnapCallback({
    required this.id,
    required this.farmerId,
    required this.requestedAt,
  });

  /// Reads a `SnapCallback` object.
  factory SnapCallback.fromJson(Map<String, Object?> json) => SnapCallback(
    id: json.reqString('id'),
    farmerId: json.reqString('farmer_id'),
    requestedAt: json.reqDateTime('requested_at'),
  );

  /// Call-back ID (`CloseCallbackPayload.callback_id`).
  final String id;

  /// Farmer who asked.
  final String farmerId;

  /// UTC time asked.
  final DateTime requestedAt;

  /// The `SnapCallback` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'farmer_id': farmerId,
    'requested_at': utcIso(requestedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is SnapCallback &&
      other.id == id &&
      other.farmerId == farmerId &&
      other.requestedAt == requestedAt;

  @override
  int get hashCode => Object.hash(id, farmerId, requestedAt);
}

/// An FA alert that is not closed (`SnapAlert`, snapshot section `alerts`;
/// the same fields as `FAAlert` without the farmer name and phone).
final class SnapAlert {
  /// Creates an alert.
  const SnapAlert({
    required this.id,
    required this.faId,
    required this.kind,
    required this.farmerId,
    required this.refId,
    required this.title,
    required this.body,
    required this.titleTe,
    required this.bodyTe,
    required this.status,
    required this.createdAt,
    required this.acknowledgedAt,
  });

  /// Reads a `SnapAlert` (or `FAAlert`) object.
  factory SnapAlert.fromJson(Map<String, Object?> json) => SnapAlert(
    id: json.reqString('id'),
    faId: json.reqString('fa_id'),
    kind: AlertKind.fromWire(json.optString('kind')),
    farmerId: json.optString('farmer_id'),
    refId: json.optString('ref_id'),
    title: json.reqString('title'),
    body: json.optString('body'),
    titleTe: json.optString('title_te'),
    bodyTe: json.optString('body_te'),
    status: AlertStatus.fromWire(json.optString('status')),
    createdAt: json.reqDateTime('created_at'),
    acknowledgedAt: json.optDateTime('acknowledged_at'),
  );

  /// Alert ID (`AckAlertPayload.alert_id`).
  final String id;

  /// The FA.
  final String faId;

  /// What it is about.
  final AlertKind kind;

  /// Farmer, or null.
  final String? farmerId;

  /// The record it is about (farmer for new_farmer, call-back for callback).
  final String? refId;

  /// English title.
  final String title;

  /// English body, or null.
  final String? body;

  /// Telugu title; null on older alerts and English-only HO notes.
  final String? titleTe;

  /// Telugu body, or null.
  final String? bodyTe;

  /// Open, acknowledged or closed.
  final AlertStatus status;

  /// UTC creation time.
  final DateTime createdAt;

  /// UTC time acknowledged, or null.
  final DateTime? acknowledgedAt;

  /// The title to show in [language] (falls back to the other language).
  String displayTitle(Language language) =>
      pickText(language, te: titleTe, en: title);

  /// The body to show in [language], or null when there is none.
  String? displayBody(Language language) {
    final text = pickText(language, te: bodyTe, en: body);
    return text.isEmpty ? null : text;
  }

  /// The `SnapAlert` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'fa_id': faId,
    'kind': kind.wire,
    'farmer_id': farmerId,
    'ref_id': refId,
    'title': title,
    'body': body,
    'title_te': titleTe,
    'body_te': bodyTe,
    'status': status.wire,
    'created_at': utcIso(createdAt),
    'acknowledged_at': _time(acknowledgedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is SnapAlert &&
      other.id == id &&
      other.faId == faId &&
      other.kind == kind &&
      other.farmerId == farmerId &&
      other.refId == refId &&
      other.title == title &&
      other.body == body &&
      other.titleTe == titleTe &&
      other.bodyTe == bodyTe &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.acknowledgedAt == acknowledgedAt;

  @override
  int get hashCode => Object.hash(
    id,
    faId,
    kind,
    farmerId,
    refId,
    title,
    body,
    titleTe,
    bodyTe,
    status,
    createdAt,
    acknowledgedAt,
  );

  @override
  String toString() => 'SnapAlert($id, ${kind.wire}, ${status.wire})';
}

/// A village in the FA's area, for offline enrolment (`SnapVillage`,
/// snapshot section `villages`).
final class SnapVillage {
  /// Creates a village.
  const SnapVillage({
    required this.id,
    required this.name,
    required this.nameTe,
    required this.lgdCode,
    required this.location,
    required this.mandalId,
    required this.mandalName,
    required this.mandalNameTe,
    required this.districtId,
    required this.districtName,
    required this.districtNameTe,
    required this.createdAt,
  });

  /// Reads a `SnapVillage` object (`lat`/`lng` become [location]).
  factory SnapVillage.fromJson(Map<String, Object?> json) {
    final lat = json.optDouble('lat');
    final lng = json.optDouble('lng');
    return SnapVillage(
      id: json.reqString('id'),
      name: json.reqString('name'),
      nameTe: json.optString('name_te'),
      lgdCode: json.optString('lgd_code'),
      location: lat != null && lng != null ? LatLng(lat, lng) : null,
      mandalId: json.reqString('mandal_id'),
      mandalName: json.reqString('mandal_name'),
      mandalNameTe: json.optString('mandal_name_te'),
      districtId: json.reqString('district_id'),
      districtName: json.reqString('district_name'),
      districtNameTe: json.optString('district_name_te'),
      createdAt: json.reqDateTime('created_at'),
    );
  }

  /// Village ID.
  final String id;

  /// "Kondapur".
  final String name;

  /// "కొండాపూర్", or null.
  final String? nameTe;

  /// LGD code, or null.
  final String? lgdCode;

  /// Village centre (`lat`, `lng`), or null.
  final LatLng? location;

  /// Mandal ID.
  final String mandalId;

  /// "Serilingampally".
  final String mandalName;

  /// Telugu mandal name, or null.
  final String? mandalNameTe;

  /// District ID.
  final String districtId;

  /// "Rangareddy".
  final String districtName;

  /// Telugu district name, or null.
  final String? districtNameTe;

  /// UTC creation time.
  final DateTime createdAt;

  /// The village name to show in [language].
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  /// The mandal name to show in [language].
  String displayMandal(Language language) =>
      pickText(language, te: mandalNameTe, en: mandalName);

  /// The district name to show in [language].
  String displayDistrict(Language language) =>
      pickText(language, te: districtNameTe, en: districtName);

  /// The `SnapVillage` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'name_te': nameTe,
    'lgd_code': lgdCode,
    'lat': location?.lat,
    'lng': location?.lng,
    'mandal_id': mandalId,
    'mandal_name': mandalName,
    'mandal_name_te': mandalNameTe,
    'district_id': districtId,
    'district_name': districtName,
    'district_name_te': districtNameTe,
    'created_at': utcIso(createdAt),
  };

  @override
  bool operator ==(Object other) =>
      other is SnapVillage &&
      other.id == id &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.lgdCode == lgdCode &&
      other.location == location &&
      other.mandalId == mandalId &&
      other.mandalName == mandalName &&
      other.mandalNameTe == mandalNameTe &&
      other.districtId == districtId &&
      other.districtName == districtName &&
      other.districtNameTe == districtNameTe &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    nameTe,
    lgdCode,
    location,
    mandalId,
    mandalName,
    mandalNameTe,
    districtId,
    districtName,
    districtNameTe,
    createdAt,
  );

  @override
  String toString() => 'SnapVillage($name)';
}

/// Everything the FA app keeps offline (`Snapshot`,
/// `GET /v1/fa/sync/snapshot`), with the `sections` flattened into fields.
///
/// Unknown sections are ignored. A missing list section reads as empty; the
/// `masters` section is required.
final class Snapshot {
  /// Creates a snapshot.
  const Snapshot({
    required this.territoryVersion,
    required this.mastersVersion,
    required this.generatedAt,
    required this.farmers,
    required this.plots,
    required this.seasons,
    required this.visits,
    required this.callbacks,
    required this.alerts,
    required this.masters,
    required this.villages,
  });

  /// Reads the snapshot document (`{territory_version, masters_version,
  /// generated_at, sections{...}}`).
  factory Snapshot.fromJson(Map<String, Object?> json) {
    final s = json.reqMap('sections');
    return Snapshot(
      territoryVersion: json.reqInt('territory_version'),
      mastersVersion: json.reqInt('masters_version'),
      generatedAt: json.reqDateTime('generated_at'),
      farmers: s.objects('farmers', SnapFarmer.fromJson),
      plots: s.objects('plots', SnapPlot.fromJson),
      seasons: s.objects('seasons', SnapSeason.fromJson),
      visits: s.objects('visits', SnapVisit.fromJson),
      callbacks: s.objects('callbacks', SnapCallback.fromJson),
      alerts: s.objects('alerts', SnapAlert.fromJson),
      masters: SnapMasters.fromJson(s.reqMap('masters')),
      villages: s.objects('villages', SnapVillage.fromJson),
    );
  }

  /// Territory version (changes when any of the FA's data changes).
  final int territoryVersion;

  /// Masters version.
  final int mastersVersion;

  /// UTC time the server built it.
  final DateTime generatedAt;

  /// Farmers the FA may act on.
  final List<SnapFarmer> farmers;

  /// Their plots.
  final List<SnapPlot> plots;

  /// Their seasons.
  final List<SnapSeason> seasons;

  /// Planned visits and the 3 latest done per farmer.
  final List<SnapVisit> visits;

  /// Open call-backs.
  final List<SnapCallback> callbacks;

  /// Alerts that are not closed.
  final List<SnapAlert> alerts;

  /// Crops, issues, salts, SKUs, rules, season codes.
  final SnapMasters masters;

  /// Villages in the FA's area.
  final List<SnapVillage> villages;

  /// The ETag the server gives this snapshot: `"t{territory}-m{masters}"`
  /// (with the quotes), as in `SyncStatus.etag`.
  String get etag => snapshotEtag(territoryVersion, mastersVersion);

  /// The snapshot ETag for these versions.
  static String snapshotEtag(int territoryVersion, int mastersVersion) =>
      '"t$territoryVersion-m$mastersVersion"';

  /// The `Snapshot` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'territory_version': territoryVersion,
    'masters_version': mastersVersion,
    'generated_at': utcIso(generatedAt),
    'sections': {
      'farmers': [for (final f in farmers) f.toJson()],
      'plots': [for (final p in plots) p.toJson()],
      'seasons': [for (final s in seasons) s.toJson()],
      'visits': [for (final v in visits) v.toJson()],
      'callbacks': [for (final c in callbacks) c.toJson()],
      'alerts': [for (final a in alerts) a.toJson()],
      'masters': masters.toJson(),
      'villages': [for (final v in villages) v.toJson()],
    },
  };

  @override
  bool operator ==(Object other) =>
      other is Snapshot &&
      other.territoryVersion == territoryVersion &&
      other.mastersVersion == mastersVersion &&
      other.generatedAt == generatedAt &&
      listEquals(other.farmers, farmers) &&
      listEquals(other.plots, plots) &&
      listEquals(other.seasons, seasons) &&
      listEquals(other.visits, visits) &&
      listEquals(other.callbacks, callbacks) &&
      listEquals(other.alerts, alerts) &&
      other.masters == masters &&
      listEquals(other.villages, villages);

  @override
  int get hashCode => Object.hash(
    territoryVersion,
    mastersVersion,
    generatedAt,
    Object.hashAll(farmers),
    Object.hashAll(plots),
    Object.hashAll(seasons),
    Object.hashAll(visits),
    Object.hashAll(callbacks),
    Object.hashAll(alerts),
    masters,
    Object.hashAll(villages),
  );

  @override
  String toString() =>
      'Snapshot($etag, ${farmers.length} farmers, ${visits.length} visits)';
}

/// The answer to a snapshot pull with `If-None-Match`.
sealed class SnapshotResult {
  const SnapshotResult();
}

/// 304: the app's snapshot is current. Touch `last_pull_at` and stop.
final class SnapshotNotModified extends SnapshotResult {
  /// Creates the result.
  const SnapshotNotModified({required this.etag});

  /// The ETag the server sent back (the one the app holds).
  final String etag;

  @override
  bool operator ==(Object other) =>
      other is SnapshotNotModified && other.etag == etag;

  @override
  int get hashCode => etag.hashCode;
}

/// 200: a new snapshot with its ETag (store both in one transaction).
final class SnapshotFetched extends SnapshotResult {
  /// Creates the result.
  const SnapshotFetched({required this.snapshot, required this.etag});

  /// The snapshot.
  final Snapshot snapshot;

  /// The response's `ETag` header (`"t12-m3"`), sent next time as
  /// `If-None-Match`.
  final String etag;

  @override
  bool operator ==(Object other) =>
      other is SnapshotFetched &&
      other.snapshot == snapshot &&
      other.etag == etag;

  @override
  int get hashCode => Object.hash(snapshot, etag);
}

String? _time(DateTime? t) => t == null ? null : utcIso(t);

/// Stored GeoJSON text as the JSON value the server sends (an object), or
/// the text itself when it does not parse ([SnapPlot.geoJsonText] reads
/// both).
Object? _geoJsonValue(String? text) {
  if (text == null) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}
