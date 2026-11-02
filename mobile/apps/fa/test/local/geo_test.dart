import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/local/geo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixture.dart';

void main() {
  test('distanceKm: haversine', () {
    expect(distanceKm(kondapurAt, kondapurAt), 0);
    expect(distanceKm(kondapurAt, gachibowliAt), closeTo(2.51, 0.05));
  });

  test('ringCentre ignores the closing point; boundaryCentre and '
      'plotLocation', () {
    const ring = [LatLng(17, 78), LatLng(17, 78.2), LatLng(17.2, 78.2)];
    final c = ringCentre(ring)!;
    expect(ringCentre([...ring, ring.first]), c);
    expect(c.lat, closeTo(17.0667, 1e-4));
    expect(c.lng, closeTo(78.1333, 1e-4));
    expect(ringCentre(const []), isNull);
    expect(boundaryCentre(null), isNull);
    expect(boundaryCentre(lakshmiBoundary)!.lat, closeTo(17.4305, 1e-9));
  });

  test('ringAreaAcres: about 2 acres for a 96 m x 85 m walk', () {
    const sw = LatLng(17.46, 78.36);
    final ring = [
      sw,
      const LatLng(17.46, 78.36 + 96 / 106190.0),
      const LatLng(17.46 + 85 / 110574.0, 78.36 + 96 / 106190.0),
      const LatLng(17.46 + 85 / 110574.0, 78.36),
    ];
    // 96 m x 85 m = 8160 m2 = 2.016 acres.
    expect(ringAreaAcres(ring), closeTo(2.016, 0.01));
    expect(ringAreaAcres([...ring, ring.first]), closeTo(2.016, 0.01));
    expect(ringAreaAcres(ring.take(2).toList()), 0);
    expect(8160 / squareMetresPerAcre, closeTo(2.016, 0.001));
  });

  test('metresBetween and pathMetres', () {
    const a = LatLng(17.46, 78.36);
    const b = LatLng(17.46 + 100 / 110574.0, 78.36);
    expect(metresBetween(a, b), closeTo(100, 1));
    expect(metresBetween(a, a), 0);
    expect(pathMetres([a, b, a]), closeTo(200, 2));
    expect(pathMetres([a]), 0);
  });

  test('ringIsSimple: a crossing, touching or spiked boundary is refused', () {
    const a = LatLng(17.0, 78.0);
    const b = LatLng(17.0, 78.001);
    const c = LatLng(17.001, 78.001);
    const d = LatLng(17.001, 78.0);
    expect(ringIsSimple(const [a, b, c, d]), isTrue);
    expect(ringIsSimple(const [a, b, c, d, a]), isTrue, reason: 'closed');
    expect(ringIsSimple(const [a, b, b, c, d]), isTrue, reason: 'repeat');
    expect(ringIsSimple(const [a, c, b, d]), isFalse, reason: 'bow tie');
    expect(ringIsSimple(const [a, b, c]), isTrue);
    expect(ringIsSimple(const [a, b]), isFalse);
    // A spike: out to b and straight back over the same line.
    const half = LatLng(17.0, 78.0005);
    expect(ringIsSimple(const [a, b, half, d]), isFalse);
    // Touching itself at a corner (a figure eight through one point).
    const mid = LatLng(17.0005, 78.0005);
    expect(
      ringIsSimple(const [
        a,
        LatLng(17.0, 78.001),
        mid,
        LatLng(17.001, 78.001),
        LatLng(17.001, 78.0),
        mid,
      ]),
      isFalse,
    );
  });
}
