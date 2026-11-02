import 'dart:async';

import 'package:fa/src/data/data.dart';
import 'package:fa/src/device/device.dart';
import 'package:fa/src/features/enrol/boundary_sketch.dart';
import 'package:fa/src/features/enrol/enrol_plot_screen.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/geo.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:fa/src/shared/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';
import 'enrol_test_support.dart';

MockLocationService _gps(FaTest t) =>
    t.read(locationServiceProvider) as MockLocationService;

Future<(FaTest, String)> _pump(WidgetTester tester) async {
  final t = await enrolTest();
  final id = await enrolDirect(t);
  await pumpFaScreen(tester, EnrolPlotScreen(farmerId: id), test: t);
  return (t, id);
}

/// Walks the mock plot's corners from where the phone is now.
Future<List<LatLng>> _walk(WidgetTester tester, FaTest t) async {
  final gps = _gps(t);
  final ring = MockLocationService.boundaryRing(gps.position);
  for (final p in ring.skip(1)) {
    gps.moveTo(p);
    await tester.pumpAndSettle();
  }
  return ring;
}

/// Walks [offsets] (degrees from where the phone is) as corners, then
/// closes the boundary.
Future<void> _walkCorners(
  WidgetTester tester,
  FaTest t,
  List<(double, double)> offsets,
) async {
  final gps = _gps(t);
  final start = gps.position;
  await scrollAndTap(tester, orbitButton(te.faEnrolPlotStart));
  for (final (dLat, dLng) in offsets) {
    gps.moveTo(LatLng(start.lat + dLat, start.lng + dLng));
    await tester.pumpAndSettle();
  }
  await scrollAndTap(tester, orbitButton(te.faEnrolPlotClose));
}

/// A GPS whose watch fails at once and whose one-off fix waits for [fix].
final class _SlowGps implements LocationService {
  final fix = Completer<LocationFix>();

  @override
  Future<LocationFix> currentFix() => fix.future;

  @override
  Stream<LocationFix> watch() =>
      Stream.error(const LocationUnavailable(LocationProblem.timeout));
}

void main() {
  testWidgets('shows step 2 for the farmer with a good GPS', (tester) async {
    await _pump(tester);
    expect(find.text(te.faEnrolTitleName(name: 'Mahesh B')), findsOneWidget);
    expect(statusPill(te.faEnrolPlotGpsGood(metres: 4)), findsOneWidget);
    expect(orbitButton(te.faEnrolPlotStart), findsOneWidget);
    expect(find.byType(BoundarySketch), findsOneWidget);
    expect(find.text(te.faEnrolPlotVillageFromGps), findsOneWidget);
    expect(find.text('కొండాపూర్'), findsOneWidget);
    expectCleanLayout(tester);
  });

  testWidgets('walk, close, area on the phone, Save & next queues SavePlot '
      'and opens step 3', (tester) async {
    final (t, id) = await _pump(tester);
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotStart));
    expect(orbitButton(te.faEnrolPlotClose), findsOneWidget);
    expect(find.text(te.faEnrolPlotNeedCorners), findsOneWidget);
    final ring = await _walk(tester, t);
    expect(find.text(te.faEnrolPlotNeedCorners), findsNothing);
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotClose));
    final acres = ringAreaAcres(ring);
    expect(acres, closeTo(2.0, 0.1));
    expect(statusPill(te.faEnrolPlotClosed), findsOneWidget);
    expect(find.textContaining(formatArea(te, acres)), findsWidgets);
    expect(orbitButton(te.faEnrolPlotWalkAgain), findsOneWidget);

    await scrollAndTap(tester, orbitButton(te.faEnrolPlotSaveNext));
    final plot = queued<SavePlotPayload>(t).single;
    expect(plot.farmerId, id);
    expect(plot.label, 'Plot 1');
    expect(plot.areaSource, AreaSource.boundary);
    expect(plot.areaAcres, closeTo(acres, 0.001));
    expect(geoJsonOuterRings(plot.boundaryGeoJson).single.length, 5);
    expect(plot.gpsAccuracyM, MockLocationService.goodAccuracyM);
    expect(queued<UpdateFarmerPayload>(t), isEmpty);
    expect(
      currentLocation(t.router),
      AppRoutes.enrolCrop(id, plotId: plot.plotId),
    );
  });

  testWidgets('Undo last corner and Pause', (tester) async {
    final (t, _) = await _pump(tester);
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotStart));
    await _walk(tester, t);
    expect(
      find.bySemanticsLabel(te.faEnrolPlotSketchWalking(corners: 4)),
      findsOneWidget,
    );
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotUndo));
    expect(
      find.bySemanticsLabel(te.faEnrolPlotSketchWalking(corners: 3)),
      findsOneWidget,
    );
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotPause));
    _gps(t).moveTo(const LatLng(17.4610, 78.3610));
    await tester.pumpAndSettle();
    // Paused: the move is not a corner.
    expect(
      find.bySemanticsLabel(te.faEnrolPlotSketchWalking(corners: 3)),
      findsOneWidget,
    );
    expect(orbitButton(te.faEnrolPlotResume), findsOneWidget);
  });

  testWidgets('rough GPS: the ±28 m card with Type area and Try again', (
    tester,
  ) async {
    final (t, _) = await _pump(tester);
    _gps(t).setAccuracy(MockLocationService.poorAccuracyM);
    await tester.pumpAndSettle();
    expect(find.text(te.faEnrolPlotGpsLowTitle(metres: 28)), findsOneWidget);
    expect(orbitButton(te.faEnrolPlotStart), findsNothing);

    // Still rough after Try again.
    await scrollAndTap(tester, orbitButton(te.commonRetry));
    expect(find.text(te.faEnrolPlotGpsLowTitle(metres: 28)), findsOneWidget);
    _gps(t).setAccuracy(MockLocationService.goodAccuracyM);
    await tester.pumpAndSettle();
    expect(find.text(te.faEnrolPlotGpsLowTitle(metres: 28)), findsNothing);
    expect(orbitButton(te.faEnrolPlotStart), findsOneWidget);

    _gps(t).setAccuracy(MockLocationService.poorAccuracyM);
    await tester.pumpAndSettle();
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotModeType).last);
    expect(find.text(te.faEnrolPlotTypedNote), findsOneWidget);
  });

  testWidgets('no location permission says so', (tester) async {
    final (t, _) = await _pump(tester);
    _gps(t).setProblem(LocationProblem.permissionDenied);
    await tester.pumpAndSettle();
    expect(find.text(te.faEnrolPlotGpsDenied), findsOneWidget);
  });

  testWidgets('typed area: acres + guntas with a pin where the FA stands', (
    tester,
  ) async {
    final (t, id) = await _pump(tester);
    await tester.tap(find.text(te.faEnrolPlotModeType));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('enrol.guntas')), '45');
    await tester.pumpAndSettle();
    expect(find.text(te.faEnrolPlotGuntasTooMany), findsOneWidget);
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotSaveNext));
    expect(find.text(te.faEnrolPlotErrorTyped), findsOneWidget);
    expect(queued<SavePlotPayload>(t), isEmpty);

    await tester.enterText(find.byKey(const Key('enrol.acres')), '2');
    await tester.enterText(find.byKey(const Key('enrol.guntas')), '4');
    await tester.pumpAndSettle();
    expect(
      find.textContaining(te.faCommonArea(acres: 2, guntas: 4)),
      findsOneWidget,
    );
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotSaveNext));
    final plot = queued<SavePlotPayload>(t).single;
    expect(plot.farmerId, id);
    expect(plot.areaSource, AreaSource.typed);
    expect(plot.areaAcres, 2.1);
    expect(plot.boundaryGeoJson, isNull);
    expect(plot.pin, _gps(t).position);
    expect(currentPath(t.router), '/enrol/$id/crop');
  });

  testWidgets('Save & next without a closed walk says what is missing', (
    tester,
  ) async {
    final (t, _) = await _pump(tester);
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotSaveNext));
    expect(find.text(te.faEnrolPlotErrorWalk), findsOneWidget);
    expect(queued<SavePlotPayload>(t), isEmpty);
  });

  testWidgets('another village updates the farmer too', (tester) async {
    final (t, id) = await _pump(tester);
    await tester.tap(find.text(te.faEnrolPlotModeType));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('enrol.acres')), '1');
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text(te.faEnrolPlotChangeVillage));
    await tester.tap(find.text('గచ్చిబౌలి'));
    await tester.pumpAndSettle();
    expect(find.text(te.faEnrolPlotVillage), findsOneWidget);
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotSaveNext));
    final update = queued<UpdateFarmerPayload>(t).single;
    expect(update.farmerId, id);
    expect(update.fields.villageId, MockBackend.gachibowliId);
  });

  testWidgets('an unknown farmer shows Not found', (tester) async {
    await pumpFaScreen(
      tester,
      const EnrolPlotScreen(farmerId: 'nobody'),
      overrides: quietActions(),
    );
    expect(find.text(te.errorNotFound), findsOneWidget);
  });

  testWidgets('English UI', (tester) async {
    final t = await enrolTest(language: Language.en);
    final id = await enrolDirect(t);
    await pumpFaScreen(
      tester,
      EnrolPlotScreen(farmerId: id),
      test: t,
      locale: const Locale('en'),
    );
    expect(find.text(en.faEnrolPlotModeWalk), findsOneWidget);
    expect(find.text('Kondapur'), findsOneWidget);
  });

  for (final scale in textScales) {
    testWidgets('step 2 states fit at text scale $scale', (tester) async {
      final t = await enrolTest();
      final id = await enrolDirect(t);
      await pumpFaScreen(
        tester,
        EnrolPlotScreen(farmerId: id),
        test: t,
        textScale: scale,
      );
      expectCleanLayout(tester);
      await scrollAndTap(tester, orbitButton(te.faEnrolPlotStart));
      await _walk(tester, t);
      expectCleanLayout(tester);
      await scrollAndTap(tester, orbitButton(te.faEnrolPlotClose));
      expectCleanLayout(tester);
      _gps(t).setAccuracy(MockLocationService.poorAccuracyM);
      await scrollAndTap(tester, orbitButton(te.faEnrolPlotWalkAgain));
      expectCleanLayout(tester);
      final typeTab = find.text(te.faEnrolPlotModeType).first;
      await tester.ensureVisible(typeTab);
      await tester.pumpAndSettle();
      await tester.tap(typeTab);
      await tester.pumpAndSettle();
      expect(find.text(te.faEnrolPlotTypedNote), findsOneWidget);
      expectCleanLayout(tester);
    });
  }

  testWidgets('a new enrolment takes the village from the GPS at the farm', (
    tester,
  ) async {
    // Step 1 put the farmer in Kondapur (no GPS fix there); the FA now
    // stands in Gachibowli.
    final t = await enrolTest();
    final id = await enrolDirect(t);
    final gachibowli = t.territory.village(MockBackend.gachibowliId)!;
    _gps(t).moveTo(gachibowli.location!);
    await pumpFaScreen(tester, EnrolPlotScreen(farmerId: id), test: t);
    expect(find.text(te.faEnrolPlotVillageFromGps), findsOneWidget);
    expect(find.text('గచ్చిబౌలి'), findsOneWidget);
    await tester.tap(find.text(te.faEnrolPlotModeType));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('enrol.acres')), '1');
    await tester.pumpAndSettle();
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotSaveNext));
    final update = queued<UpdateFarmerPayload>(t).single;
    expect(update.farmerId, id);
    expect(update.fields.villageId, MockBackend.gachibowliId);
  });

  testWidgets('a farmer HO already has keeps his village', (tester) async {
    final t = await enrolTest();
    final farmer = t.territory.farmers.firstWhere(
      (f) =>
          f.status == FarmerStatus.active &&
          f.villageId == MockBackend.kondapurId,
    );
    final gachibowli = t.territory.village(MockBackend.gachibowliId)!;
    _gps(t).moveTo(gachibowli.location!);
    await pumpFaScreen(tester, EnrolPlotScreen(farmerId: farmer.id), test: t);
    expect(find.text('కొండాపూర్'), findsOneWidget);
    expect(find.text(te.faEnrolPlotVillage), findsOneWidget);
  });

  testWidgets('corners in a line: area too small, Walk again', (tester) async {
    final (t, _) = await _pump(tester);
    await _walkCorners(tester, t, [(0.0002, 0), (0.0004, 0)]);
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotSaveNext));
    expect(find.text(te.faActionErrorAreaTooSmall), findsOneWidget);
    expect(queued<SavePlotPayload>(t), isEmpty);
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotWalkAgain).first);
    expect(find.text(te.faActionErrorAreaTooSmall), findsNothing);
    expect(orbitButton(te.faEnrolPlotStart), findsOneWidget);
  });

  testWidgets('a boundary that crosses itself offers Walk again', (
    tester,
  ) async {
    final (t, _) = await _pump(tester);
    // A lopsided bow tie: the third side crosses the first.
    await _walkCorners(tester, t, [(0.0005, 0.0005), (0.0005, 0), (0, 0.0008)]);
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotSaveNext));
    expect(find.text(te.faActionErrorBoundaryCrossesItself), findsOneWidget);
    expect(orbitButton(te.faEnrolPlotWalkAgain), findsNWidgets(2));
    expect(queued<SavePlotPayload>(t), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('leaving while Try again waits for the GPS is safe', (
    tester,
  ) async {
    final gps = _SlowGps();
    final t = await createFaTest(
      overrides: [
        ...quietActions(),
        locationServiceProvider.overrideWithValue(gps),
      ],
    );
    final id = await enrolDirect(t);
    await pumpFaScreen(tester, EnrolPlotScreen(farmerId: id), test: t);
    await scrollAndTap(tester, orbitButton(te.commonRetry));
    t.router.go(AppRoutes.sync);
    await tester.pumpAndSettle();
    expect(find.byType(EnrolPlotScreen), findsNothing);
    gps.fix.complete(
      LocationFix(lat: 17.46, lng: 78.36, accuracyM: 4, at: testStart),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('another farmer\'s step 2 starts fresh', (tester) async {
    final t = await enrolTest();
    final a = await enrolDirect(t);
    final b = await enrolDirect(t, phone: '9876500012', name: 'Naresh C');
    final farmer = ValueNotifier(a);
    addTearDown(farmer.dispose);
    await pumpFaScreen(
      tester,
      ValueListenableBuilder(
        valueListenable: farmer,
        builder: (_, id, _) => EnrolPlotScreen(farmerId: id),
      ),
      test: t,
    );
    await scrollAndTap(tester, orbitButton(te.faEnrolPlotStart));
    expect(orbitButton(te.faEnrolPlotClose), findsOneWidget);
    farmer.value = b;
    await tester.pumpAndSettle();
    expect(find.text(te.faEnrolTitleName(name: 'Naresh C')), findsOneWidget);
    expect(orbitButton(te.faEnrolPlotStart), findsOneWidget);
    expect(orbitButton(te.faEnrolPlotClose), findsNothing);
  });
}
