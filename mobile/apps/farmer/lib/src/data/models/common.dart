import 'package:flutter/foundation.dart';

/// An enum that has a wire value in the API (`pending_profile`, `soil_partner`).
///
/// The future API layer maps generated DTO enums with `fromWire`, and the mock
/// uses [wire] where the API would send a string.
abstract interface class WireEnum {
  /// The value as the API spells it; empty for an `unknown` fallback.
  String get wire;
}

/// Finds the value of [values] whose [WireEnum.wire] is [wire], or [orElse]
/// (the enum's `unknown` value, for codes the server added later).
T enumFromWire<T extends WireEnum>(List<T> values, String? wire, T orElse) {
  if (wire == null || wire.isEmpty) return orElse;
  for (final v in values) {
    if (v.wire == wire) return v;
  }
  return orElse;
}

/// App and SMS language (`Language` in the specs). Telugu is the default.
enum Language implements WireEnum {
  /// Telugu.
  te('te'),

  /// English.
  en('en');

  const Language(this.wire);

  @override
  final String wire;

  /// Parses a wire value; anything unknown falls back to Telugu.
  static Language fromWire(String? wire) =>
      enumFromWire(values, wire, Language.te);
}

/// A map point (`LatLng` / `GeoPoint` in the specs), WGS 84 degrees.
@immutable
class LatLng {
  /// Creates a point.
  const LatLng(this.lat, this.lng);

  /// Latitude, -90 to 90.
  final double lat;

  /// Longitude, -180 to 180.
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

/// Allocation level of an FA: the `level` query of `GET /v1/farmer/fas`,
/// `FAOption.coverage_level` and `FarmerFACard.level`.
enum AreaLevel implements WireEnum {
  /// One or more villages.
  village('village'),

  /// A whole mandal.
  mandal('mandal'),

  /// A whole district.
  district('district'),

  /// A level this app version does not know.
  unknown('');

  const AreaLevel(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static AreaLevel fromWire(String? wire) =>
      enumFromWire(values, wire, AreaLevel.unknown);
}

/// Picks the Telugu or English text for [language], falling back to the
/// other one when the preferred text is missing or empty.
String pickText(Language language, {String? te, String? en}) {
  final first = language == Language.te ? te : en;
  final second = language == Language.te ? en : te;
  if (first != null && first.isNotEmpty) return first;
  return second ?? '';
}
