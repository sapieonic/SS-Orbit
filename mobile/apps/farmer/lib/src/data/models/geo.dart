import 'package:flutter/foundation.dart';

/// A village with its mandal and district (`Village`, village picker).
@immutable
class Village {
  /// Creates a village.
  const Village({
    required this.id,
    required this.name,
    required this.nameTe,
    required this.lgdCode,
    required this.lat,
    required this.lng,
    required this.mandalId,
    required this.mandalName,
    required this.mandalNameTe,
    required this.districtId,
    required this.districtName,
    required this.districtNameTe,
    required this.createdAt,
  });

  /// Village ID (send as `village_id` to complete-profile).
  final String id;

  /// English name.
  final String name;

  /// Telugu name.
  final String? nameTe;

  /// Government LGD code.
  final String? lgdCode;

  /// Centroid latitude, null when unknown.
  final double? lat;

  /// Centroid longitude, null when unknown.
  final double? lng;

  /// Mandal ID.
  final String mandalId;

  /// Mandal English name.
  final String mandalName;

  /// Mandal Telugu name.
  final String? mandalNameTe;

  /// District ID.
  final String districtId;

  /// District English name.
  final String districtName;

  /// District Telugu name.
  final String? districtNameTe;

  /// Created (UTC).
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is Village &&
      other.id == id &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.lgdCode == lgdCode &&
      other.lat == lat &&
      other.lng == lng &&
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
    lat,
    lng,
    mandalId,
    mandalName,
    mandalNameTe,
    districtId,
    districtName,
    districtNameTe,
    createdAt,
  );

  @override
  String toString() => 'Village($name, $mandalName)';
}

/// A mandal in the geo tree (`TreeMandal`).
@immutable
class TreeMandal {
  /// Creates a mandal.
  const TreeMandal({
    required this.id,
    required this.name,
    required this.nameTe,
    required this.lgdCode,
    required this.villageCount,
  });

  /// Mandal ID (browse with `searchVillages(mandalId: id)`).
  final String id;

  /// English name.
  final String name;

  /// Telugu name.
  final String? nameTe;

  /// Government LGD code.
  final String? lgdCode;

  /// Villages in the mandal.
  final int villageCount;

  @override
  bool operator ==(Object other) =>
      other is TreeMandal &&
      other.id == id &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.lgdCode == lgdCode &&
      other.villageCount == villageCount;

  @override
  int get hashCode => Object.hash(id, name, nameTe, lgdCode, villageCount);
}

/// A district in the geo tree (`TreeDistrict`).
@immutable
class TreeDistrict {
  /// Creates a district.
  const TreeDistrict({
    required this.id,
    required this.name,
    required this.nameTe,
    required this.lgdCode,
    required this.villageCount,
    required this.mandals,
  });

  /// District ID.
  final String id;

  /// English name.
  final String name;

  /// Telugu name.
  final String? nameTe;

  /// Government LGD code.
  final String? lgdCode;

  /// Villages in the district.
  final int villageCount;

  /// Mandals in the district.
  final List<TreeMandal> mandals;

  @override
  bool operator ==(Object other) =>
      other is TreeDistrict &&
      other.id == id &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.lgdCode == lgdCode &&
      other.villageCount == villageCount &&
      listEquals(other.mandals, mandals);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    nameTe,
    lgdCode,
    villageCount,
    Object.hashAll(mandals),
  );
}

/// District > mandal tree for browsing the village picker (`GeoTree`).
@immutable
class GeoTree {
  /// Creates a tree.
  const GeoTree({required this.districts});

  /// Districts with their mandals.
  final List<TreeDistrict> districts;

  @override
  bool operator ==(Object other) =>
      other is GeoTree && listEquals(other.districts, districts);

  @override
  int get hashCode => Object.hashAll(districts);
}
