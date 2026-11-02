import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/enrol/enrol_crop_screen.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:fa/src/shared/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../../support/harness.dart';
import 'enrol_test_support.dart';

/// Mon 2 Nov 2026 (IST), the test clock's day.
final _today = LocalDate(2026, 11, 2);

Future<(FaTest, String, String)> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('te'),
  double textScale = 1,
}) async {
  final t = await enrolTest(
    language: locale.languageCode == 'en' ? Language.en : Language.te,
  );
  final farmerId = await enrolDirect(t);
  final plotId = await plotDirect(t, farmerId);
  await pumpFaScreen(
    tester,
    EnrolCropScreen(farmerId: farmerId, plotId: plotId),
    test: t,
    locale: locale,
    textScale: textScale,
  );
  return (t, farmerId, plotId);
}

Future<void> _tapText(WidgetTester tester, String text) =>
    scrollAndTap(tester, find.text(text).first);

void main() {
  testWidgets('shows step 3 with seasons, crops and the summary', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text(te.faEnrolTitleName(name: 'Mahesh B')), findsOneWidget);
    expect(find.textContaining('Plot 1'), findsWidgets);
    // Rabi 2026-27 is this season on 2 Nov 2026.
    expect(find.text(te.faEnrolCropThisSeason), findsOneWidget);
    expect(
      find.text(
        te.faEnrolCropCropHeading(
          season: te.faEnrolCropSeasonLabel(
            season: te.enumSeasonKindRabi,
            year: '2026-27',
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('పత్తి'), findsNWidgets(2)); // crop and previous crop
    expect(find.text(te.faEnrolCropSummaryNoCrop), findsOneWidget);
    expect(find.text(te.faEnrolCropConsentPending), findsOneWidget);
    expect(
      find.text(
        te.faEnrolCropSmsNote(name: 'Mahesh B', language: te.enumLanguageTe),
      ),
      findsOneWidget,
    );
    expectCleanLayout(tester);
  });

  testWidgets('Finish enrolment queues StartSeason and shows the success '
      'state; Plan first visit', (tester) async {
    final (t, farmerId, plotId) = await _pump(tester);
    await _tapText(tester, 'మిరప');
    await _tapText(
      tester,
      te.faEnrolCropSowYesterday(date: formatDateShort(te, _today.addDays(-1))),
    );
    final stage = t.territory
        .crop(MockBackend.chilliId)!
        .stageAt(1)!
        .displayName(Language.te);
    expect(
      find.text(te.faEnrolCropSowDayStage(day: 1, stage: stage)),
      findsOneWidget,
    );
    await tester.tap(find.text('పత్తి').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(te.faEnrolCropSummaryAfter(crop: 'పత్తి')),
      findsOne,
    );

    await scrollAndTap(tester, orbitButton(te.faEnrolCropFinish));
    final season = queued<StartSeasonPayload>(t).single;
    expect(season.farmerId, farmerId);
    expect(season.plotId, plotId);
    expect(season.seasonCode, 'rabi-2026-27');
    expect(season.cropId, MockBackend.chilliId);
    expect(season.sowingDate, _today.addDays(-1));
    expect(season.previousCropId, MockBackend.cottonId);

    expect(find.text(te.faEnrolCropEnrolled(name: 'Mahesh B')), findsOneWidget);
    expect(find.text(te.faEnrolCropSavedOnPhone), findsOneWidget);
    await scrollAndTap(tester, orbitButton(te.faEnrolCropPlanVisit));
    expect(currentLocation(t.router), AppRoutes.planVisit(farmerId: farmerId));
  });

  testWidgets('Back to farmers after finishing', (tester) async {
    final (t, _, _) = await _pump(tester);
    await _tapText(tester, 'వరి');
    await _tapText(tester, te.faEnrolCropNotSown);
    expect(find.text(te.faEnrolCropNotSownNote), findsOneWidget);
    await scrollAndTap(tester, orbitButton(te.faEnrolCropFinish));
    final season = queued<StartSeasonPayload>(t).single;
    expect(season.sowingDate, isNull);
    expect(season.previousCropId, isNull);
    await scrollAndTap(tester, orbitButton(te.faEnrolCropBackToFarmers));
    expect(currentPath(t.router), AppRoutes.farmers);
  });

  testWidgets('needs a crop and a sowing choice', (tester) async {
    final (t, _, _) = await _pump(tester);
    await scrollAndTap(tester, orbitButton(te.faEnrolCropFinish));
    expect(find.text(te.faEnrolCropErrorCrop), findsOneWidget);
    expect(find.text(te.faEnrolCropErrorSowing), findsOneWidget);
    expect(queued<StartSeasonPayload>(t), isEmpty);
  });

  testWidgets('another open season and a picked sowing date', (tester) async {
    final (t, _, _) = await _pump(tester);
    final kharif = te.faEnrolCropSeasonLabel(
      season: te.enumSeasonKindKharif,
      year: '2026',
    );
    await _tapText(tester, kharif);
    await _tapText(tester, 'పత్తి');
    await _tapText(tester, te.faEnrolCropSowPick);
    final ok = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    ).okButtonLabel;
    await tester.tap(find.text(ok));
    await tester.pumpAndSettle();
    final picked = _today.addDays(-7);
    expect(find.text(formatDateFull(te, picked)), findsOneWidget);
    await _tapText(tester, te.faEnrolCropFallow);
    await scrollAndTap(tester, orbitButton(te.faEnrolCropFinish));
    final season = queued<StartSeasonPayload>(t).single;
    expect(season.seasonCode, 'kharif-2026');
    expect(season.sowingDate, picked);
    expect(season.previousCropId, isNull);
  });

  testWidgets('a plot that already has a crop says so', (tester) async {
    final t = await enrolTest();
    await pumpFaScreen(
      tester,
      EnrolCropScreen(
        farmerId: MockBackend.raviId,
        plotId: MockBackend.raviPlotId,
      ),
      test: t,
    );
    expect(find.text(te.errorActiveSeasonExists), findsOneWidget);
    await scrollAndTap(tester, orbitButton(te.faEnrolOpenFarmer));
    expect(currentPath(t.router), AppRoutes.farmer(MockBackend.raviId));
  });

  testWidgets('a missing plot or another farmer\'s plot shows Not found', (
    tester,
  ) async {
    final t = await enrolTest();
    final id = await enrolDirect(t);
    await pumpFaScreen(
      tester,
      EnrolCropScreen(farmerId: id, plotId: MockBackend.raviPlotId),
      test: t,
    );
    expect(find.text(te.errorNotFound), findsOneWidget);
  });

  testWidgets('an empty plot ID shows Not found', (tester) async {
    await pumpFaScreen(
      tester,
      EnrolCropScreen(farmerId: MockBackend.raviId, plotId: ''),
      overrides: quietActions(),
    );
    expect(find.text(te.errorNotFound), findsOneWidget);
  });

  testWidgets('English UI shows English crop names', (tester) async {
    await _pump(tester, locale: const Locale('en'));
    expect(find.text('Cotton'), findsNWidgets(2));
    expect(orbitButton(en.faEnrolCropFinish), findsOneWidget);
  });

  for (final scale in textScales) {
    testWidgets('step 3 fits at text scale $scale', (tester) async {
      await _pump(tester, textScale: scale);
      expectCleanLayout(tester);
      await _tapText(tester, 'మొక్కజొన్న');
      await _tapText(
        tester,
        te.faEnrolCropSowToday(date: formatDateShort(te, _today)),
      );
      expectCleanLayout(tester);
      await scrollAndTap(tester, orbitButton(te.faEnrolCropFinish));
      expect(find.text(te.faEnrolCropEnrolled(name: 'Mahesh B')), findsOne);
      expectCleanLayout(tester);
    });
  }
}
