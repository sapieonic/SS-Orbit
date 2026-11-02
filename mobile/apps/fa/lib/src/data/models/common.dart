// WireEnum, enumFromWire, Language, LatLng, AreaLevel and pickText are copied
// from apps/farmer/lib/src/data/models/common.dart (without the Flutter
// import). Moving them to orbit_core is a later clean-up.
//
// The FA models are pure Dart (no Flutter import) because the offline engine
// in `local/` uses them and moves to packages/orbit_sync later. That is why
// this file has its own small equality helpers instead of flutter's
// `listEquals` / `mapEquals`.

import 'dart:convert';

import 'package:orbit_core/orbit_core.dart';

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

/// A map point (`LatLng` / `GeoPoint` / `SnapPoint` in the specs), WGS 84
/// degrees.
final class LatLng {
  /// Creates a point.
  const LatLng(this.lat, this.lng);

  /// Reads `{lat, lng}`.
  factory LatLng.fromJson(Map<String, Object?> json) =>
      LatLng(json.reqDouble('lat'), json.reqDouble('lng'));

  /// Latitude, -90 to 90.
  final double lat;

  /// Longitude, -180 to 180.
  final double lng;

  /// `{lat, lng}`.
  Map<String, Object?> toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

/// The snapshot's `SnapPoint` (`{lat, lng}`); the same as [LatLng].
typedef SnapPoint = LatLng;

/// Allocation level of an FA (`FALevel`: `FieldAssistant.level`).
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

// ---------------------------------------------------------------------------
// GeoJSON

/// A GeoJSON Polygon (as compact text) with one outer [ring].
///
/// The ring is closed for you (the first point is repeated at the end when
/// it is not already). GeoJSON order is `[lng, lat]`.
String polygonGeoJson(List<LatLng> ring) {
  final points = [...ring];
  if (points.isNotEmpty && points.first != points.last) {
    points.add(points.first);
  }
  return jsonEncode({
    'type': 'Polygon',
    'coordinates': [
      [
        for (final p in points) [p.lng, p.lat],
      ],
    ],
  });
}

/// The outer rings of a GeoJSON Polygon or MultiPolygon, for drawing a plot.
///
/// Holes are left out. Returns an empty list for null, empty or unreadable
/// text and for other geometry types (never throws).
List<List<LatLng>> geoJsonOuterRings(String? geoJson) {
  if (geoJson == null || geoJson.isEmpty) return const [];
  try {
    final decoded = jsonDecode(geoJson);
    if (decoded is! Map<String, Object?>) return const [];
    final coords = decoded['coordinates'];
    if (coords is! List<Object?>) return const [];
    final polygons = switch (decoded['type']) {
      'Polygon' => [coords],
      'MultiPolygon' => coords,
      _ => const <Object?>[],
    };
    final rings = <List<LatLng>>[];
    for (final polygon in polygons) {
      if (polygon is! List<Object?> || polygon.isEmpty) continue;
      final outer = polygon.first;
      if (outer is! List<Object?>) continue;
      rings.add([
        for (final pos in outer)
          if (pos is List<Object?> &&
              pos.length >= 2 &&
              pos[0] is num &&
              pos[1] is num)
            LatLng((pos[1]! as num).toDouble(), (pos[0]! as num).toDouble()),
      ]);
    }
    return rings;
  } on FormatException {
    return const [];
  }
}

// ---------------------------------------------------------------------------
// Equality helpers (pure Dart stand-ins for flutter's listEquals/mapEquals)

/// True when [a] and [b] have equal items in the same order (items compared
/// with [jsonEquals], so nested JSON lists and maps compare by value).
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!jsonEquals(a[i], b[i])) return false;
  }
  return true;
}

/// True when [a] and [b] have the same keys with equal values (values
/// compared with [jsonEquals]).
bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || !jsonEquals(e.value, b[e.key])) return false;
  }
  return true;
}

/// Deep equality for decoded JSON values (maps, lists, scalars).
bool jsonEquals(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) return listEquals(a, b);
  if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
    return mapEquals(a, b);
  }
  return a == b;
}

/// A hash consistent with [jsonEquals].
int jsonHash(Object? value) => switch (value) {
  final List<Object?> list => Object.hashAll(list.map(jsonHash)),
  final Map<Object?, Object?> map => Object.hashAllUnordered(
    map.entries.map((e) => Object.hash(e.key, jsonHash(e.value))),
  ),
  _ => value.hashCode,
};

// ---------------------------------------------------------------------------
// JSON reading

/// Typed reads from a decoded JSON object, for the `fromJson` factories.
///
/// Every reader throws [FormatException] naming the key when the value is
/// missing (for `req*`) or has the wrong type. Numbers are accepted for
/// doubles whether the JSON had `2` or `2.0`.
extension JsonRead on Map<String, Object?> {
  T? _opt<T>(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is T) return v as T;
    throw FormatException('"$key" should be $T, got ${v.runtimeType}');
  }

  T _req<T>(String key) {
    final v = _opt<T>(key);
    if (v == null) throw FormatException('"$key" is required');
    return v;
  }

  /// A required string.
  String reqString(String key) => _req<String>(key);

  /// An optional string.
  String? optString(String key) => _opt<String>(key);

  /// A required integer.
  int reqInt(String key) => _req<int>(key);

  /// An optional integer.
  int? optInt(String key) => _opt<int>(key);

  /// A required number as a double.
  double reqDouble(String key) => _req<num>(key).toDouble();

  /// An optional number as a double.
  double? optDouble(String key) => _opt<num>(key)?.toDouble();

  /// A required boolean.
  bool reqBool(String key) => _req<bool>(key);

  /// An optional boolean.
  bool? optBool(String key) => _opt<bool>(key);

  /// A required RFC 3339 time, as UTC.
  DateTime reqDateTime(String key) => _parseTime(key, reqString(key));

  /// An optional RFC 3339 time, as UTC.
  DateTime? optDateTime(String key) {
    final s = optString(key);
    return s == null ? null : _parseTime(key, s);
  }

  /// A required `YYYY-MM-DD` date.
  LocalDate reqDate(String key) => _parseDate(key, reqString(key));

  /// An optional `YYYY-MM-DD` date.
  LocalDate? optDate(String key) {
    final s = optString(key);
    return s == null ? null : _parseDate(key, s);
  }

  /// A required JSON object.
  Map<String, Object?> reqMap(String key) => _req<Map<String, Object?>>(key);

  /// An optional JSON object.
  Map<String, Object?>? optMap(String key) => _opt<Map<String, Object?>>(key);

  /// A list of JSON objects mapped by [convert]; empty when absent or null.
  List<T> objects<T>(String key, T Function(Map<String, Object?>) convert) {
    final list = _opt<List<Object?>>(key) ?? const [];
    return [
      for (final item in list)
        if (item is Map<String, Object?>)
          convert(item)
        else
          throw FormatException('"$key" should hold objects'),
    ];
  }

  /// A list of strings; empty when absent or null.
  List<String> strings(String key) {
    final list = _opt<List<Object?>>(key) ?? const [];
    return [
      for (final item in list)
        if (item is String)
          item
        else
          throw FormatException('"$key" should hold strings'),
    ];
  }

  static DateTime _parseTime(String key, String s) {
    final t = DateTime.tryParse(s);
    if (t == null) throw FormatException('"$key" is not a date-time: $s');
    return t.toUtc();
  }

  static LocalDate _parseDate(String key, String s) {
    final d = LocalDate.tryParse(s);
    if (d == null) throw FormatException('"$key" is not a date: $s');
    return d;
  }
}

/// RFC 3339 UTC text for [time] (`2026-11-02T04:30:00.000Z`).
String utcIso(DateTime time) => time.toUtc().toIso8601String();
