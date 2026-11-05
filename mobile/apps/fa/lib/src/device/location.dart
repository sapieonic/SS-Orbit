import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';

import '../data/models/models.dart';
import '../data/providers.dart' show clockProvider, orbitEnvProvider;

/// Boundary walks are allowed only at this accuracy or better (metres). The
/// plan suggests 10 m; confirm after the Phase 0 GPS spike.
const boundaryAccuracyLimitM = 10.0;

/// One GPS reading.
final class LocationFix {
  /// Creates a fix.
  const LocationFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.at,
  });

  /// Latitude, WGS 84 degrees.
  final double lat;

  /// Longitude, WGS 84 degrees.
  final double lng;

  /// Horizontal accuracy radius in metres (68 % confidence), as the phone
  /// reports it. Smaller is better.
  final double accuracyM;

  /// When the fix was taken (UTC).
  final DateTime at;

  /// The fix as a map point.
  LatLng get point => LatLng(lat, lng);

  /// Good enough to walk a plot boundary ([boundaryAccuracyLimitM]).
  bool get goodForBoundary => accuracyM <= boundaryAccuracyLimitM;

  @override
  bool operator ==(Object other) =>
      other is LocationFix &&
      other.lat == lat &&
      other.lng == lng &&
      other.accuracyM == accuracyM &&
      other.at == at;

  @override
  int get hashCode => Object.hash(lat, lng, accuracyM, at);

  @override
  String toString() => 'LocationFix($lat, $lng, ±${accuracyM}m)';
}

/// Why no fix could be had.
enum LocationProblem {
  /// The FA refused the location permission (or refused it for good).
  permissionDenied,

  /// Location is switched off in the phone's settings.
  serviceOff,

  /// No fix in time (indoors, no sky view).
  timeout,
}

/// Thrown by [LocationService] when no fix can be had.
final class LocationUnavailable implements Exception {
  /// Creates the error.
  const LocationUnavailable(this.problem);

  /// What went wrong.
  final LocationProblem problem;

  @override
  String toString() => 'LocationUnavailable(${problem.name})';
}

/// The phone's GPS.
///
/// Written so `geolocator` drops in later:
/// - [currentFix]: `Geolocator.isLocationServiceEnabled()` (false ->
///   [LocationProblem.serviceOff]), `Geolocator.checkPermission()` /
///   `requestPermission()` (denied -> [LocationProblem.permissionDenied]),
///   then `Geolocator.getCurrentPosition(locationSettings:
///   LocationSettings(accuracy: LocationAccuracy.best, timeLimit: ...))`
///   (`TimeoutException` -> [LocationProblem.timeout]); `Position.latitude`,
///   `longitude`, `accuracy`, `timestamp` map to [LocationFix].
/// - [watch]: `Geolocator.getPositionStream(locationSettings:
///   AndroidSettings(accuracy: LocationAccuracy.best, distanceFilter: 1,
///   intervalDuration: 1 s))`, mapped the same way.
abstract interface class LocationService {
  /// One fresh fix. Throws [LocationUnavailable].
  Future<LocationFix> currentFix();

  /// Fixes as the FA moves (the boundary walk, the accuracy card), starting
  /// with the current one. Errors are [LocationUnavailable]. Cancel the
  /// subscription to stop the GPS.
  Stream<LocationFix> watch();
}

/// A [LocationService] for mock mode, tests and the dev screen.
///
/// Starts in Kondapur ([kondapur], ±[goodAccuracyM]). Dev tools can make the
/// GPS rough ([poorAccuracyM], the "GPS is ±28 m" card), switch it off, move
/// the phone, or play a [walkBoundary] around a plot of about 2 acres.
final class MockLocationService implements LocationService {
  /// Creates the mock at [start] (default [kondapur]).
  MockLocationService({this.clock = const SystemClock(), LatLng? start})
    : _position = start ?? kondapur;

  /// Kondapur, Serilingampally (the mock FA's territory).
  static const kondapur = LatLng(17.4600, 78.3600);

  /// A good fix (open ground).
  static const goodAccuracyM = 4.0;

  /// A rough fix (under trees, near sheds): too rough to walk a boundary.
  static const poorAccuracyM = 28.0;

  /// Time source for [LocationFix.at].
  final Clock clock;

  final _changes = StreamController<LocationFix>.broadcast();
  LatLng _position;
  double _accuracyM = goodAccuracyM;
  LocationProblem? _problem;
  Timer? _walk;
  Completer<void>? _walkDone;

  /// Where the phone is now.
  LatLng get position => _position;

  /// The accuracy the next fixes report.
  double get accuracyM => _accuracyM;

  /// The failure every call reports, or null when the GPS works.
  LocationProblem? get problem => _problem;

  /// True while a [walkBoundary] is playing.
  bool get walking => _walk != null;

  LocationFix _fix() => LocationFix(
    lat: _position.lat,
    lng: _position.lng,
    accuracyM: _accuracyM,
    at: clock.now(),
  );

  void _emit() {
    if (_changes.isClosed) return;
    final problem = _problem;
    if (problem != null) {
      _changes.addError(LocationUnavailable(problem));
    } else {
      _changes.add(_fix());
    }
  }

  @override
  Future<LocationFix> currentFix() async {
    final problem = _problem;
    if (problem != null) throw LocationUnavailable(problem);
    return _fix();
  }

  @override
  Stream<LocationFix> watch() {
    StreamSubscription<LocationFix>? changes;
    late final StreamController<LocationFix> out;
    out = StreamController<LocationFix>(
      onListen: () {
        final problem = _problem;
        if (problem != null) {
          out.addError(LocationUnavailable(problem));
        } else {
          out.add(_fix());
        }
        changes = _changes.stream.listen(out.add, onError: out.addError);
      },
      onCancel: () => changes?.cancel(),
    );
    return out.stream;
  }

  /// Sets the reported accuracy (e.g. [poorAccuracyM]) and tells watchers.
  void setAccuracy(double metres) {
    _accuracyM = metres;
    _emit();
  }

  /// Makes every call fail with [problem] (null: the GPS works again).
  void setProblem(LocationProblem? problem) {
    _problem = problem;
    _emit();
  }

  /// Moves the phone to [point] and tells watchers.
  void moveTo(LatLng point) {
    _position = point;
    _emit();
  }

  /// Walks the [boundaryRing] around [start] (default: where the phone is)
  /// over [duration], one fix per point, and stops on the first corner, so
  /// the ring closes. Completes when the walk ends (or is stopped).
  Future<void> walkBoundary({
    LatLng? start,
    Duration duration = const Duration(seconds: 6),
    int pointsPerSide = 6,
  }) {
    stopWalk();
    final ring = boundaryRing(start ?? _position);
    final path = <LatLng>[
      for (var side = 0; side < ring.length; side++)
        for (var i = 0; i < pointsPerSide; i++)
          _lerp(ring[side], ring[(side + 1) % ring.length], i / pointsPerSide),
      ring.first,
    ];
    final step = duration ~/ path.length;
    final done = Completer<void>();
    var next = 0;
    void tick() {
      moveTo(path[next++]);
      if (next >= path.length) {
        stopWalk();
        if (!done.isCompleted) done.complete();
      }
    }

    tick();
    _walk = Timer.periodic(step, (_) => tick());
    _walkDone = done;
    return done.future;
  }

  /// Stops a [walkBoundary] where it is.
  void stopWalk() {
    _walk?.cancel();
    _walk = null;
    final done = _walkDone;
    _walkDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// Stops the walk and closes the stream.
  void dispose() {
    stopWalk();
    unawaited(_changes.close());
  }

  /// The corners of a slightly uneven four-sided plot of about 2 acres
  /// (~8,100 m²) whose south-west corner is [southWest]: roughly 95 m east
  /// by 85 m north.
  static List<LatLng> boundaryRing(LatLng southWest) {
    const metresPerDegLat = 110574.0;
    final metresPerDegLng = 111320.0 * math.cos(southWest.lat * math.pi / 180);
    LatLng at(double eastM, double northM) => LatLng(
      southWest.lat + northM / metresPerDegLat,
      southWest.lng + eastM / metresPerDegLng,
    );
    return [at(0, 0), at(96, 4), at(92, 88), at(-2, 84)];
  }

  static LatLng _lerp(LatLng a, LatLng b, double t) =>
      LatLng(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
}

/// The GPS the screens use: [MockLocationService] on mock data (dev tools
/// check for it to drive it). There is no real GPS yet, so on the API this
/// throws instead of recording scripted fixes for pins and check-ins.
final locationServiceProvider = Provider<LocationService>((ref) {
  if (!ref.watch(orbitEnvProvider).usesMock) {
    throw UnimplementedError(
      'LocationService on the API needs the geolocator plugin (a GPS '
      'implementation of LocationService); only MockLocationService exists. '
      'See "Not done yet" in mobile/README.md.',
    );
  }
  final service = MockLocationService(clock: ref.watch(clockProvider));
  ref.onDispose(service.dispose);
  return service;
});
