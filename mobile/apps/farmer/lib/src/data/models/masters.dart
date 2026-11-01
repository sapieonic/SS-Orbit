import 'package:flutter/foundation.dart';
import 'package:orbit_core/orbit_core.dart';

import 'common.dart';

/// A crop stage (`Stage` on Home, `FarmerStage` in the crop list; same
/// shape). Days count from sowing (sowing day = 0).
@immutable
class Stage {
  /// Creates a stage.
  const Stage({
    required this.id,
    required this.code,
    required this.name,
    required this.nameTe,
    required this.seq,
    required this.startDay,
    required this.endDay,
  });

  /// Stage ID.
  final String id;

  /// `flowering`.
  final String code;

  /// "Flowering".
  final String name;

  /// "పూత దశ".
  final String nameTe;

  /// Order, 1-based.
  final int seq;

  /// First day after sowing.
  final int startDay;

  /// Last day after sowing.
  final int endDay;

  /// True when [daysAfterSowing] falls in this stage.
  bool contains(int daysAfterSowing) =>
      daysAfterSowing >= startDay && daysAfterSowing <= endDay;

  @override
  bool operator ==(Object other) =>
      other is Stage &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.seq == seq &&
      other.startDay == startDay &&
      other.endDay == endDay;

  @override
  int get hashCode =>
      Object.hash(id, code, name, nameTe, seq, startDay, endDay);

  @override
  String toString() => 'Stage($code, $startDay-$endDay)';
}

/// A crop with its stage calendar (`FarmerCrop`).
@immutable
class FarmerCrop {
  /// Creates a crop.
  const FarmerCrop({
    required this.id,
    required this.code,
    required this.nameTe,
    required this.name,
    required this.durationDays,
    required this.stages,
  });

  /// Crop ID.
  final String id;

  /// `cotton`.
  final String code;

  /// "పత్తి".
  final String nameTe;

  /// "Cotton".
  final String name;

  /// About how long the crop takes ("day 137 of about 160").
  final int? durationDays;

  /// Stages in order.
  final List<Stage> stages;

  @override
  bool operator ==(Object other) =>
      other is FarmerCrop &&
      other.id == id &&
      other.code == code &&
      other.nameTe == nameTe &&
      other.name == name &&
      other.durationDays == durationDays &&
      listEquals(other.stages, stages);

  @override
  int get hashCode =>
      Object.hash(id, code, nameTe, name, durationDays, Object.hashAll(stages));

  @override
  String toString() => 'FarmerCrop($code)';
}

/// Season codes to offer when starting a season (`SeasonCodes`).
@immutable
class SeasonCodes {
  /// Creates season codes.
  const SeasonCodes({
    required this.current,
    required this.next,
    required this.allOpen,
    required this.validUntil,
  });

  /// From the orbit_core calendar (mock data, or an expired cache).
  factory SeasonCodes.fromSet(SeasonCodeSet set) => SeasonCodes(
    current: set.current,
    next: set.next,
    allOpen: set.allOpen,
    validUntil: set.validUntil,
  );

  /// The season today.
  final String current;

  /// The next season.
  final String next;

  /// Previous, current and next, oldest first: the season picker's options.
  final List<String> allOpen;

  /// Last IST day of [current]; refresh the crop list after it.
  final LocalDate validUntil;

  @override
  bool operator ==(Object other) =>
      other is SeasonCodes &&
      other.current == current &&
      other.next == next &&
      listEquals(other.allOpen, allOpen) &&
      other.validUntil == validUntil;

  @override
  int get hashCode =>
      Object.hash(current, next, Object.hashAll(allOpen), validUntil);
}

/// Active crops and today's season codes (`FarmerCropList`,
/// `GET /v1/farmer/crops`).
@immutable
class FarmerCropList {
  /// Creates a crop list.
  const FarmerCropList({
    required this.version,
    required this.items,
    required this.seasonCodes,
  });

  /// Masters version the list was built from.
  final int version;

  /// Every active crop.
  final List<FarmerCrop> items;

  /// Season codes for the picker.
  final SeasonCodes seasonCodes;

  /// The crop with [id], or null.
  FarmerCrop? byId(String id) {
    for (final c in items) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is FarmerCropList &&
      other.version == version &&
      listEquals(other.items, items) &&
      other.seasonCodes == seasonCodes;

  @override
  int get hashCode => Object.hash(version, Object.hashAll(items), seasonCodes);
}

/// A dealer near a point (`NearbyDealerView`, `GET /v1/farmer/dealers`).
@immutable
class NearbyDealer {
  /// Creates a dealer.
  const NearbyDealer({
    required this.id,
    required this.nameTe,
    required this.name,
    required this.phone,
    required this.location,
    required this.distanceM,
  });

  /// Dealer ID.
  final String id;

  /// Telugu name.
  final String? nameTe;

  /// English name.
  final String name;

  /// E.164 phone.
  final String? phone;

  /// Shop location.
  final LatLng location;

  /// Straight-line distance in metres.
  final int distanceM;

  @override
  bool operator ==(Object other) =>
      other is NearbyDealer &&
      other.id == id &&
      other.nameTe == nameTe &&
      other.name == name &&
      other.phone == phone &&
      other.location == location &&
      other.distanceM == distanceM;

  @override
  int get hashCode => Object.hash(id, nameTe, name, phone, location, distanceM);
}
