import 'package:flutter/foundation.dart';
import 'package:orbit_core/orbit_core.dart';

import 'common.dart';
import 'fas.dart';

/// How bad an issue is (`Severity`).
enum Severity implements WireEnum {
  /// తక్కువ.
  low('low'),

  /// మధ్యస్థం.
  moderate('moderate'),

  /// ఎక్కువ.
  high('high'),

  /// A severity this app version does not know.
  unknown('');

  const Severity(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static Severity fromWire(String? wire) =>
      enumFromWire(values, wire, Severity.unknown);
}

/// Part of the day a visit is planned for (`PlannedSlot`).
enum PlannedSlot implements WireEnum {
  /// Morning.
  morning('morning'),

  /// Afternoon.
  afternoon('afternoon'),

  /// Any time.
  any('any'),

  /// A slot this app version does not know.
  unknown('');

  const PlannedSlot(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static PlannedSlot fromWire(String? wire) =>
      enumFromWire(values, wire, PlannedSlot.unknown);
}

/// The next planned visit as Home carries it (`PlannedVisit`).
@immutable
class PlannedVisit {
  /// Creates a planned visit.
  const PlannedVisit({
    required this.visitId,
    required this.faId,
    required this.plotId,
    required this.seasonId,
    required this.plannedFor,
    required this.plannedSlot,
    required this.purpose,
  });

  /// Visit ID.
  final String visitId;

  /// The visiting FA.
  final String faId;

  /// The plot.
  final String plotId;

  /// The season.
  final String seasonId;

  /// IST calendar day.
  final LocalDate plannedFor;

  /// Part of the day.
  final PlannedSlot plannedSlot;

  /// FA's note, e.g. "Check bollworm traps" (free text, usually English).
  final String? purpose;

  @override
  bool operator ==(Object other) =>
      other is PlannedVisit &&
      other.visitId == visitId &&
      other.faId == faId &&
      other.plotId == plotId &&
      other.seasonId == seasonId &&
      other.plannedFor == plannedFor &&
      other.plannedSlot == plannedSlot &&
      other.purpose == purpose;

  @override
  int get hashCode => Object.hash(
    visitId,
    faId,
    plotId,
    seasonId,
    plannedFor,
    plannedSlot,
    purpose,
  );
}

/// The next planned visit for My visits (`NextVisit`,
/// `GET /v1/farmer/visits/next`).
@immutable
class NextVisit {
  /// Creates a next visit.
  const NextVisit({
    required this.visitId,
    required this.plotId,
    required this.plannedFor,
    required this.plannedSlot,
    required this.purpose,
    required this.fa,
  });

  /// Visit ID.
  final String visitId;

  /// The plot.
  final String plotId;

  /// IST calendar day.
  final LocalDate plannedFor;

  /// Part of the day.
  final PlannedSlot plannedSlot;

  /// FA's note.
  final String? purpose;

  /// The visiting FA.
  final FaName? fa;

  @override
  bool operator ==(Object other) =>
      other is NextVisit &&
      other.visitId == visitId &&
      other.plotId == plotId &&
      other.plannedFor == plannedFor &&
      other.plannedSlot == plannedSlot &&
      other.purpose == purpose &&
      other.fa == fa;

  @override
  int get hashCode =>
      Object.hash(visitId, plotId, plannedFor, plannedSlot, purpose, fa);
}

/// One issue found on a visit and what to spray (`FarmerAdvice`).
///
/// Shows a Shanmukha product only when [skuId] is set ("Sample 5 SG"),
/// otherwise the salt with "ask for this name at the shop" ([saltOnly]).
/// Never another brand.
@immutable
class FarmerAdvice {
  /// Creates advice.
  const FarmerAdvice({
    required this.issueName,
    required this.issueNameTe,
    required this.severity,
    required this.advicePending,
    required this.saltName,
    required this.saltNameTe,
    required this.skuId,
    required this.productName,
    required this.productNameTe,
    required this.dose,
    required this.doseTe,
    required this.saltOnly,
  });

  /// "Pink bollworm".
  final String? issueName;

  /// "గులాబీ రంగు పురుగు".
  final String? issueNameTe;

  /// How bad it is.
  final Severity severity;

  /// Found but no advice recorded: "Your FA will follow up".
  final bool advicePending;

  /// Active ingredient, e.g. "Emamectin benzoate 5% SG".
  final String? saltName;

  /// Telugu salt name.
  final String? saltNameTe;

  /// Shanmukha SKU; opens the product card (F8a).
  final String? skuId;

  /// "Sample 5 SG".
  final String? productName;

  /// Telugu product name.
  final String? productNameTe;

  /// "80 g in 200 L water per acre".
  final String? dose;

  /// Telugu dose.
  final String? doseTe;

  /// No Shanmukha product maps to the salt: show the salt (F8b).
  final bool saltOnly;

  @override
  bool operator ==(Object other) =>
      other is FarmerAdvice &&
      other.issueName == issueName &&
      other.issueNameTe == issueNameTe &&
      other.severity == severity &&
      other.advicePending == advicePending &&
      other.saltName == saltName &&
      other.saltNameTe == saltNameTe &&
      other.skuId == skuId &&
      other.productName == productName &&
      other.productNameTe == productNameTe &&
      other.dose == dose &&
      other.doseTe == doseTe &&
      other.saltOnly == saltOnly;

  @override
  int get hashCode => Object.hash(
    issueName,
    issueNameTe,
    severity,
    advicePending,
    saltName,
    saltNameTe,
    skuId,
    productName,
    productNameTe,
    dose,
    doseTe,
    saltOnly,
  );
}

/// A logged FA visit with its advice (`FarmerVisit`, F4).
@immutable
class FarmerVisit {
  /// Creates a visit.
  const FarmerVisit({
    required this.id,
    required this.plotId,
    required this.visitedAt,
    required this.fa,
    required this.stageName,
    required this.stageNameTe,
    required this.issues,
  });

  /// Visit ID.
  final String id;

  /// The plot (name from the Home cache).
  final String plotId;

  /// When the FA visited (UTC).
  final DateTime visitedAt;

  /// The FA.
  final FaName? fa;

  /// Crop stage at the visit.
  final String? stageName;

  /// Telugu stage name.
  final String? stageNameTe;

  /// Issues found, with advice.
  final List<FarmerAdvice> issues;

  @override
  bool operator ==(Object other) =>
      other is FarmerVisit &&
      other.id == id &&
      other.plotId == plotId &&
      other.visitedAt == visitedAt &&
      other.fa == fa &&
      other.stageName == stageName &&
      other.stageNameTe == stageNameTe &&
      listEquals(other.issues, issues);

  @override
  int get hashCode => Object.hash(
    id,
    plotId,
    visitedAt,
    fa,
    stageName,
    stageNameTe,
    Object.hashAll(issues),
  );

  @override
  String toString() => 'FarmerVisit($id, $visitedAt, ${issues.length} issues)';
}
