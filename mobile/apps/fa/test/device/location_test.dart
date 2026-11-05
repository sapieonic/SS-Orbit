import 'dart:async';
import 'dart:math' as math;

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/device/location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

/// Area of a small ring in square metres (flat-earth approximation, fine
/// for a field).
double _areaM2(List<LatLng> ring) {
  final lat0 = ring.first.lat * math.pi / 180;
  final pts = [
    for (final p in ring)
      (x: p.lng * 111320.0 * math.cos(lat0), y: p.lat * 110574.0),
  ];
  var sum = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum.abs() / 2;
}

/// The mock GPS used in mock mode and by the dev screen.
void main() {
  late FixedClock clock;
  late MockLocationService gps;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 11, 2, 4, 30));
    gps = MockLocationService(clock: clock);
  });

  tearDown(() => gps.dispose());

  test('starts in Kondapur with a good fix', () async {
    final fix = await gps.currentFix();
    expect(fix.lat, 17.4600);
    expect(fix.lng, 78.3600);
    expect(fix.accuracyM, 4);
    expect(fix.at, clock.now());
    expect(fix.goodForBoundary, isTrue);
    expect(fix.point, MockLocationService.kondapur);
  });

  test('dev tools make the GPS rough, and watchers hear it', () async {
    final fixes = <LocationFix>[];
    final sub = gps.watch().listen(fixes.add);
    await pumpEventQueue();
    gps.setAccuracy(MockLocationService.poorAccuracyM);
    await pumpEventQueue();
    await sub.cancel();

    expect(fixes.map((f) => f.accuracyM), [4, 28]);
    expect(fixes.last.goodForBoundary, isFalse);
    expect((await gps.currentFix()).accuracyM, 28);
  });

  test('a switched-off GPS fails, then recovers on the same stream', () async {
    gps.setProblem(LocationProblem.serviceOff);
    await expectLater(
      gps.currentFix(),
      throwsA(
        isA<LocationUnavailable>().having(
          (e) => e.problem,
          'problem',
          LocationProblem.serviceOff,
        ),
      ),
    );

    final events = <Object>[];
    final sub = gps.watch().listen(events.add, onError: events.add);
    await pumpEventQueue();
    gps.setProblem(null);
    await pumpEventQueue();
    await sub.cancel();

    expect(events.first, isA<LocationUnavailable>());
    expect(events.last, isA<LocationFix>());
  });

  test('the boundary ring is about 2 acres', () {
    final ring = MockLocationService.boundaryRing(MockLocationService.kondapur);
    expect(ring, hasLength(4));
    final acres = _areaM2(ring) / 4046.86;
    expect(acres, closeTo(2, 0.15));
  });

  test('a scripted walk traces the ring and closes it', () async {
    final points = <LatLng>[];
    final sub = gps.watch().listen((f) => points.add(f.point));
    await pumpEventQueue();
    final walk = gps.walkBoundary(duration: const Duration(milliseconds: 250));
    expect(gps.walking, isTrue);
    await walk;
    await pumpEventQueue();
    await sub.cancel();

    expect(gps.walking, isFalse);
    // The current fix, then 4 sides x 6 points, then the first corner.
    expect(points, hasLength(1 + 4 * 6 + 1));
    final ring = MockLocationService.boundaryRing(MockLocationService.kondapur);
    expect(points[1], ring.first);
    expect(points.last, ring.first);
    expect(points, containsAll(ring));
    expect(gps.position, ring.first);
  });

  test('a walk can be stopped half way', () async {
    var done = false;
    unawaited(
      gps
          .walkBoundary(duration: const Duration(milliseconds: 500))
          .then((_) => done = true),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    gps.stopWalk();
    await pumpEventQueue();
    expect(done, isTrue);
    expect(gps.walking, isFalse);
    final at = gps.position;
    expect(at, isNot(MockLocationService.kondapur));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(gps.position, at);
  });
}
