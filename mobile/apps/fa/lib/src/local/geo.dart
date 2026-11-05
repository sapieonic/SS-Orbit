// Small geometry helpers for the territory: distances, plot centres and
// the area of a walked boundary. Pure Dart.

import 'dart:math' as math;

import '../data/models/models.dart';

/// Mean Earth radius, km.
const double earthRadiusKm = 6371.0088;

/// Great-circle distance between [a] and [b], in km (haversine).
double distanceKm(LatLng a, LatLng b) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
}

/// The average of a ring's corners (the closing point is not counted twice),
/// or null for an empty ring. Good enough for a field-sized polygon.
LatLng? ringCentre(List<LatLng> ring) {
  final points = [...ring];
  if (points.length > 1 && points.first == points.last) points.removeLast();
  if (points.isEmpty) return null;
  var lat = 0.0;
  var lng = 0.0;
  for (final p in points) {
    lat += p.lat;
    lng += p.lng;
  }
  return LatLng(lat / points.length, lng / points.length);
}

/// The centre of the first outer ring of a GeoJSON boundary, or null.
LatLng? boundaryCentre(String? geoJson) {
  final rings = geoJsonOuterRings(geoJson);
  return rings.isEmpty ? null : ringCentre(rings.first);
}

/// Where a plot is: its pin, else its boundary's centre, else null.
LatLng? plotLocation(SnapPlot plot) =>
    plot.pin ?? boundaryCentre(plot.boundaryGeoJson);

/// Square metres in one acre.
const squareMetresPerAcre = 4046.8564224;

/// The area of the polygon [ring] (closed or not) in acres, on a local flat
/// projection around its centre: plenty for a field, and only for display
/// (the server recomputes it in PostGIS). Zero for fewer than 3 corners.
double ringAreaAcres(List<LatLng> ring) {
  final points = [...ring];
  if (points.length > 1 && points.first == points.last) points.removeLast();
  if (points.length < 3) return 0;
  final lat0 = points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
  const r = earthRadiusKm * 1000;
  final kx = r * math.cos(lat0 * math.pi / 180) * math.pi / 180;
  const ky = r * math.pi / 180;
  var twice = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    twice += (a.lng * kx) * (b.lat * ky) - (b.lng * kx) * (a.lat * ky);
  }
  return (twice.abs() / 2) / squareMetresPerAcre;
}

/// Metres between two nearby points (flat approximation).
double metresBetween(LatLng a, LatLng b) {
  const r = earthRadiusKm * 1000;
  final lat0 = (a.lat + b.lat) / 2 * math.pi / 180;
  final dx = (b.lng - a.lng) * math.pi / 180 * r * math.cos(lat0);
  final dy = (b.lat - a.lat) * math.pi / 180 * r;
  return math.sqrt(dx * dx + dy * dy);
}

/// The length of the path through [points], in metres.
double pathMetres(List<LatLng> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += metresBetween(points[i - 1], points[i]);
  }
  return total;
}

/// True when the polygon [ring] (closed or not) does not cross or touch
/// itself, as PostGIS `ST_IsValid` wants it: no two edges meet except
/// neighbours at their shared corner, and no edge doubles back over the one
/// before it. The server refuses any other boundary ("boundary crosses
/// itself; walk it again"). Fewer than 3 corners is not a polygon (false).
bool ringIsSimple(List<LatLng> ring) {
  final points = [...ring];
  if (points.length > 1 && points.first == points.last) points.removeLast();
  // Repeated corners in a row add nothing (PostGIS ignores them too).
  final p = <LatLng>[];
  for (final x in points) {
    if (p.isEmpty || p.last != x) p.add(x);
  }
  if (p.length > 1 && p.first == p.last) p.removeLast();
  final n = p.length;
  if (n < 3) return false;
  for (var i = 0; i < n; i++) {
    final a1 = p[i];
    final a2 = p[(i + 1) % n];
    for (var j = i + 1; j < n; j++) {
      final b1 = p[j];
      final b2 = p[(j + 1) % n];
      final neighbours = j == i + 1 || (i == 0 && j == n - 1);
      if (!neighbours) {
        if (_segmentsMeet(a1, a2, b1, b2)) return false;
        continue;
      }
      // Neighbours share one corner; they may only meet there. Collinear
      // and pointing back means a spike (zero-width part).
      final shared = j == i + 1 ? a2 : a1;
      final other1 = j == i + 1 ? a1 : a2;
      final other2 = j == i + 1 ? b2 : b1;
      if (_orient(other1, shared, other2) == 0 &&
          _dot(other1, shared, other2) > 0) {
        return false;
      }
    }
  }
  return true;
}

double _cross(LatLng o, LatLng a, LatLng b) =>
    (a.lng - o.lng) * (b.lat - o.lat) - (a.lat - o.lat) * (b.lng - o.lng);

int _orient(LatLng o, LatLng a, LatLng b) {
  final c = _cross(o, a, b);
  const eps = 1e-18;
  return c > eps ? 1 : (c < -eps ? -1 : 0);
}

/// Dot product of (a - s) and (b - s): positive when a and b lie on the same
/// side of s.
double _dot(LatLng a, LatLng s, LatLng b) =>
    (a.lng - s.lng) * (b.lng - s.lng) + (a.lat - s.lat) * (b.lat - s.lat);

bool _onSegment(LatLng a, LatLng b, LatLng x) =>
    math.min(a.lng, b.lng) <= x.lng &&
    x.lng <= math.max(a.lng, b.lng) &&
    math.min(a.lat, b.lat) <= x.lat &&
    x.lat <= math.max(a.lat, b.lat);

bool _segmentsMeet(LatLng a1, LatLng a2, LatLng b1, LatLng b2) {
  final d1 = _orient(b1, b2, a1);
  final d2 = _orient(b1, b2, a2);
  final d3 = _orient(a1, a2, b1);
  final d4 = _orient(a1, a2, b2);
  if (d1 != d2 && d3 != d4 && d1 != 0 && d2 != 0 && d3 != 0 && d4 != 0) {
    return true;
  }
  if (d1 == 0 && _onSegment(b1, b2, a1)) return true;
  if (d2 == 0 && _onSegment(b1, b2, a2)) return true;
  if (d3 == 0 && _onSegment(a1, a2, b1)) return true;
  if (d4 == 0 && _onSegment(a1, a2, b2)) return true;
  return false;
}

/// True when every corner of [ring] lies within [toleranceM] metres of one
/// straight line (or there are fewer than 3 distinct corners): a "boundary"
/// that encloses nothing.
bool ringIsFlat(List<LatLng> ring, {double toleranceM = 0.5}) {
  final points = {...ring}.toList();
  if (points.length < 3) return true;
  final a = points.first;
  var far = a;
  var farM = 0.0;
  for (final p in points) {
    final m = metresBetween(a, p);
    if (m > farM) {
      far = p;
      farM = m;
    }
  }
  if (farM == 0) return true;
  const r = earthRadiusKm * 1000;
  final lat0 = a.lat * math.pi / 180;
  double x(LatLng p) => (p.lng - a.lng) * math.pi / 180 * r * math.cos(lat0);
  double y(LatLng p) => (p.lat - a.lat) * math.pi / 180 * r;
  final fx = x(far);
  final fy = y(far);
  for (final p in points) {
    final d = (fx * y(p) - fy * x(p)).abs() / farM;
    if (d > toleranceM) return false;
  }
  return true;
}
