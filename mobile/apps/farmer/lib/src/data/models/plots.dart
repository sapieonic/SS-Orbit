import 'package:flutter/foundation.dart';
import 'package:orbit_core/orbit_core.dart';

import 'common.dart';

/// How a plot's area was measured (`Plot.area_source`).
enum AreaSource implements WireEnum {
  /// From a GPS boundary walk.
  boundary('boundary'),

  /// Typed in.
  typed('typed'),

  /// A source this app version does not know.
  unknown('');

  const AreaSource(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static AreaSource fromWire(String? wire) =>
      enumFromWire(values, wire, AreaSource.unknown);
}

/// Plot status (`Plot.status`).
enum PlotStatus implements WireEnum {
  /// In use.
  active('active'),

  /// Archived.
  archived('archived'),

  /// A status this app version does not know.
  unknown('');

  const PlotStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static PlotStatus fromWire(String? wire) =>
      enumFromWire(values, wire, PlotStatus.unknown);
}

/// A field (`Plot`).
@immutable
class Plot {
  /// Creates a plot.
  const Plot({
    required this.id,
    required this.farmerId,
    required this.label,
    required this.villageId,
    required this.boundary,
    required this.pin,
    required this.areaAcres,
    required this.areaSource,
    required this.gpsAccuracyM,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Plot ID.
  final String id;

  /// Owner.
  final String farmerId;

  /// "Plot 1".
  final String label;

  /// Village of the plot.
  final String? villageId;

  /// GeoJSON Polygon walked with GPS, as decoded JSON; null when not walked.
  final Map<String, Object?>? boundary;

  /// Pin dropped on the map.
  final LatLng? pin;

  /// Area in acres (`AcresGuntas.fromAcres` for display).
  final double areaAcres;

  /// How [areaAcres] was measured.
  final AreaSource areaSource;

  /// GPS accuracy of the walk in metres.
  final double? gpsAccuracyM;

  /// Active or archived.
  final PlotStatus status;

  /// Row version.
  final int version;

  /// Created (UTC).
  final DateTime createdAt;

  /// Last changed (UTC).
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Plot &&
      other.id == id &&
      other.farmerId == farmerId &&
      other.label == label &&
      other.villageId == villageId &&
      mapEquals(other.boundary, boundary) &&
      other.pin == pin &&
      other.areaAcres == areaAcres &&
      other.areaSource == areaSource &&
      other.gpsAccuracyM == gpsAccuracyM &&
      other.status == status &&
      other.version == version &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    farmerId,
    label,
    villageId,
    pin,
    areaAcres,
    areaSource,
    gpsAccuracyM,
    status,
    version,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Plot($id, $label, $areaAcres ac)';
}

/// Season status (`Season.status`).
enum SeasonStatus implements WireEnum {
  /// Growing now.
  active('active'),

  /// Closed after harvest.
  harvested('harvested'),

  /// Closed without a harvest.
  abandoned('abandoned'),

  /// A status this app version does not know.
  unknown('');

  const SeasonStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static SeasonStatus fromWire(String? wire) =>
      enumFromWire(values, wire, SeasonStatus.unknown);
}

/// How a season ends (`CloseSeasonRequest.outcome`).
enum SeasonOutcome implements WireEnum {
  /// Harvested.
  harvested('harvested'),

  /// Abandoned.
  abandoned('abandoned');

  const SeasonOutcome(this.wire);

  @override
  final String wire;
}

/// A crop season on a plot (`Season`).
@immutable
class Season {
  /// Creates a season.
  const Season({
    required this.id,
    required this.farmerId,
    required this.plotId,
    required this.seasonCode,
    required this.cropId,
    required this.sowingDate,
    required this.previousCropId,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Season ID.
  final String id;

  /// Owner.
  final String farmerId;

  /// The plot.
  final String plotId;

  /// `kharif-2026`, `rabi-2026-27`.
  final String seasonCode;

  /// The crop (`FarmerCrop.id`).
  final String cropId;

  /// Sowing day (IST calendar date).
  final LocalDate? sowingDate;

  /// The crop grown before, if known.
  final String? previousCropId;

  /// Active or closed.
  final SeasonStatus status;

  /// Row version.
  final int version;

  /// Created (UTC).
  final DateTime createdAt;

  /// Last changed (UTC).
  final DateTime updatedAt;

  /// A copy with the given fields replaced (null keeps the current value).
  Season copyWith({SeasonStatus? status, int? version, DateTime? updatedAt}) =>
      Season(
        id: id,
        farmerId: farmerId,
        plotId: plotId,
        seasonCode: seasonCode,
        cropId: cropId,
        sowingDate: sowingDate,
        previousCropId: previousCropId,
        status: status ?? this.status,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Season &&
      other.id == id &&
      other.farmerId == farmerId &&
      other.plotId == plotId &&
      other.seasonCode == seasonCode &&
      other.cropId == cropId &&
      other.sowingDate == sowingDate &&
      other.previousCropId == previousCropId &&
      other.status == status &&
      other.version == version &&
      other.createdAt == createdAt &&
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
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Season($id, $seasonCode, ${status.wire})';
}
