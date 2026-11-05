import 'package:fa/src/data/data.dart';
import 'package:fa/src/device/device.dart';
import 'package:fa/src/features/calendar/calendar_state.dart';
import 'package:fa/src/features/calendar/visit_ui.dart';
import 'package:fa/src/features/visit_log/visit_log_screen.dart';
import 'package:fa/src/features/visit_log/visit_log_widgets.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:fa/src/shared/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

/// Mon 2 Nov 2026, the test's today.
final _today = LocalDate(2026, 11, 2);

/// Ravi K's visit planned for today.
SnapVisit _raviToday(FaTest t) => t.territory
    .visitsOn(_today)
    .all
    .firstWhere((r) => r.farmer?.name == 'Ravi K' && r.isPlanned)
    .visit;

String _farmerId(FaTest t, String name) =>
    t.territory.farmerRows(query: name).first.farmer.id;

/// Pumps the visit log of Ravi's planned visit (or [build]'s screen) on a
/// tall phone.
Future<FaTest> _pump(
  WidgetTester tester, {
  FaTest? test,
  VisitLogScreen Function(FaTest t)? build,
  Locale locale = const Locale('en'),
}) async {
  final t = test ?? await createFaTest();
  final v = _raviToday(t);
  await pumpFaScreen(
    tester,
    build?.call(t) ??
        VisitLogScreen(farmerId: v.farmerId, visitId: v.id, plotId: v.plotId),
    test: t,
    locale: locale,
  );
  // A tall phone, so the whole form is built and on screen (the layout
  // tests below use the real 360 x 640).
  tester.view.physicalSize = const Size(360, 2000);
  await tester.pumpAndSettle();
  return t;
}

List<LogVisitPayload> _logs(FaTest t) => [
  for (final e in t.territory.outbox)
    if (e.type == CommandType.logVisit) e.command as LogVisitPayload,
];

Finder _chip(String label) =>
    find.byWidgetPredicate((w) => w is OptionChip && w.label == label);

Finder _severity(String label) => find.descendant(
  of: find.byType(SeverityPicker),
  matching: find.text(label),
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) await _scrollTo(tester, finder);
  if (finder.first.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Picks [issue] from the issue sheet (after choosing [type]).
Future<void> _pickIssue(
  WidgetTester tester,
  String issue, {
  String? type,
}) async {
  if (type != null) await _tap(tester, find.text(type));
  await _tap(tester, find.byType(PickerButton));
  await tester.tap(find.text(issue).last);
  await tester.pumpAndSettle();
}

Future<void> _takePhoto(WidgetTester tester) =>
    _tap(tester, find.byIcon(OrbitIcons.camera));

Future<void> _save(WidgetTester tester) =>
    _tap(tester, orbitButton(en.faVisitLogSave));

/// Lets the engine's debounced nudge after a write fire (it syncs).
Future<void> _settleNudge(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the header, the suggested stage and the issue types', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text(en.faShellTitleVisitLog), findsOneWidget);
    expect(
      find.text(
        'Ravi K · Plot 1 · Cotton · ${en.faVisitLogDayAfterSowing(count: 65)}',
      ),
      findsOneWidget,
    );
    expect(tester.widget<OptionChip>(_chip('Flowering')).selected, isTrue);
    for (final type in ['Pest', 'Disease', 'Deficiency']) {
      expect(find.text(type), findsOneWidget);
    }
    expect(find.text(en.faVisitLogPickIssue), findsOneWidget);
    expect(
      find.textContaining(en.faVisitLogPhotoCount(count: 0)),
      findsOneWidget,
    );
    expect(find.textContaining(en.faVisitLogWorksOffline), findsOneWidget);
    expect(find.textContaining('17.46°N 78.36°E'), findsOneWidget);
  });

  testWidgets('logs the planned visit with a photo, an issue and advice', (
    tester,
  ) async {
    final t = await _pump(tester);
    final planned = _raviToday(t);
    await _takePhoto(tester);
    expect(
      find.textContaining(en.faVisitLogPhotoCount(count: 1)),
      findsOneWidget,
    );

    await _pickIssue(tester, 'Pink bollworm');
    // The master's salt is preselected, with its Shanmukha product.
    await _scrollTo(
      tester,
      find.text(en.faVisitLogProduct(name: 'Sample 5 SG')),
    );
    expect(find.text('Emamectin benzoate 5% SG'), findsOneWidget);
    await _tap(tester, _severity(en.enumSeverityModerate));
    await _save(tester);

    final log = _logs(t).single;
    expect(log.visitId, planned.id);
    expect(log.farmerId, MockBackend.raviId);
    expect(log.plotId, planned.plotId);
    expect(log.visitedAt, testStart);
    expect(log.location, isNotNull);
    expect(log.farmerPresent, isTrue);
    expect(log.stageId, t.territory.suggestedStage(planned.seasonId)!.id);
    final issue = log.issues.single;
    expect(issue.severity, Severity.moderate);
    expect(
      issue.advisoryRuleId,
      t.territory.adviceFor(issue.issueId).first.rule.id,
    );
    expect(log.photos, hasLength(1));
    expect(log.nextVisit!.plannedFor, _today.addDays(7));
    expect(t.territory.visit(planned.id)!.status, VisitStatus.done);

    // Visit saved.
    expect(find.text(en.faVisitLogSavedTitle), findsOneWidget);
    expect(find.text(en.faVisitLogSavedPending), findsOneWidget);
    expect(find.text('Flowering'), findsOneWidget);
    expect(find.text('Pink bollworm (moderate)'), findsOneWidget);
    expect(find.text('Sample 5 SG · Emamectin benzoate 5% SG'), findsOneWidget);
    expect(find.text(formatDateWeekday(en, _today.addDays(7))), findsOneWidget);
    expect(
      find.text(
        en.faVisitLogSmsPending(name: 'Ravi K', language: en.faVisitLogLangTe),
      ),
      findsOneWidget,
    );
    expect(find.text(en.faVisitLogEditVisit), findsOneWidget);
    final notice = t.read(visitNoticeProvider)!;
    expect(notice.kind, VisitNoticeKind.saved);
    expect(notice.visitId, planned.id);
    expect(notice.hasAdvice, isTrue);
    expect(t.read(calendarDayProvider), isNull);

    // Once it synced: the SMS went, and it can't be edited any more.
    await _settleNudge(tester);
    expect(find.text(en.faVisitLogSavedSynced), findsOneWidget);
    expect(
      find.text(
        en.faVisitLogSmsSent(name: 'Ravi K', language: en.faVisitLogLangTe),
      ),
      findsOneWidget,
    );
    expect(find.text(en.faVisitLogEditVisit), findsNothing);
  });

  testWidgets('without photos it asks first', (tester) async {
    final t = await _pump(tester);
    await _save(tester);
    expect(find.text(en.faVisitLogNoPhotoTitle), findsOneWidget);
    // Take photo instead: the camera opens, nothing is saved yet.
    await tester.tap(find.text(en.faVisitLogTakePhoto));
    await tester.pumpAndSettle();
    expect(_logs(t), isEmpty);
    expect(
      find.textContaining(en.faVisitLogPhotoCount(count: 1)),
      findsOneWidget,
    );

    await _tap(
      tester,
      find.descendant(
        of: find.byType(PhotoStrip),
        matching: find.byType(Image),
      ),
    );
    await tester.tap(find.byTooltip(en.faVisitLogRemovePhoto(number: 1)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(en.faVisitLogPhotoCount(count: 0)),
      findsOneWidget,
    );

    await _save(tester);
    await tester.tap(find.text(en.faVisitLogSaveWithoutPhotos));
    await tester.pumpAndSettle();
    final log = _logs(t).single;
    expect(log.photos, isEmpty);
    expect(log.issues, isEmpty);
    expect(find.text(en.faVisitLogSavedTitle), findsOneWidget);
    // No issues: no SMS promised.
    expect(find.textContaining('SMS'), findsNothing);
    await _settleNudge(tester);
  });

  testWidgets('an issue needs a severity', (tester) async {
    final t = await _pump(tester);
    await _takePhoto(tester);
    await _pickIssue(tester, 'Pink bollworm');
    await _save(tester);
    expect(find.text(en.faVisitLogCheckDetails), findsOneWidget);
    await _scrollTo(tester, find.text(en.faVisitLogSeverityRequired));
    expect(_logs(t), isEmpty);
    // Add another issue waits for it too.
    await _scrollTo(tester, orbitButton(en.faVisitLogAddIssue));
    expect(
      tester.widget<OrbitButton>(orbitButton(en.faVisitLogAddIssue)).onPressed,
      isNull,
    );
  });

  testWidgets('a salt-only rule says the farmer sees the salt name only', (
    tester,
  ) async {
    await _pump(tester);
    await _pickIssue(tester, 'Leaf spot', type: 'Disease');
    await _scrollTo(tester, find.text(en.faVisitLogNoProduct));
    expect(find.text(en.faVisitLogNoProductNote), findsOneWidget);
    expect(find.text('Mancozeb 75% WP'), findsOneWidget);
  });

  testWidgets('an issue with no rule is logged for HO to follow up', (
    tester,
  ) async {
    final t = await createFaTest();
    final anil = _farmerId(t, 'Anil G');
    await _pump(
      tester,
      test: t,
      build: (_) => VisitLogScreen(farmerId: anil),
    );
    await _pickIssue(tester, 'Wilt', type: 'Disease');
    await _scrollTo(tester, find.text(en.faVisitLogNoRule));
    expect(find.text(en.faVisitLogNoRuleNote), findsOneWidget);
    await _tap(tester, _severity(en.enumSeverityHigh));
    await _takePhoto(tester);
    await _save(tester);

    final log = _logs(t).single;
    expect(log.visitId, isNotNull);
    expect(log.issues.single.advisoryRuleId, isNull);
    expect(log.issues.single.severity, Severity.high);
    // An unplanned visit: the engine made the visit.
    expect(t.territory.visit(log.visitId)!.status, VisitStatus.done);
    expect(find.text(en.faVisitLogAdviceHo), findsOneWidget);
    expect(find.text(en.faVisitLogSmsNone), findsOneWidget);
    await _settleNudge(tester);
  });

  testWidgets('more issues: add, list, remove', (tester) async {
    final t = await _pump(tester);
    await _takePhoto(tester);
    await _pickIssue(tester, 'Pink bollworm');
    await _tap(tester, _severity(en.enumSeverityModerate));
    await _tap(tester, orbitButton(en.faVisitLogAddIssue));
    await _scrollTo(
      tester,
      find.text(en.faVisitLogIssueRow(number: 1, issue: 'Pink bollworm')),
    );
    expect(find.text('Moderate · Emamectin benzoate 5% SG'), findsOneWidget);
    expect(find.text(en.faVisitLogPickIssue), findsOneWidget);

    await _pickIssue(tester, 'Whitefly');
    await _tap(tester, _severity(en.enumSeverityLow));
    await _tap(tester, orbitButton(en.faVisitLogAddIssue));
    await _scrollTo(
      tester,
      find.text(en.faVisitLogIssueRow(number: 2, issue: 'Whitefly')),
    );
    await _tap(
      tester,
      find.byTooltip(en.faVisitLogRemoveIssue(issue: 'Pink bollworm')),
    );
    expect(
      find.text(en.faVisitLogIssueRow(number: 1, issue: 'Whitefly')),
      findsOneWidget,
    );
    await _save(tester);
    expect(_logs(t).single.issues, hasLength(1));
    expect(find.text('Whitefly (low)'), findsOneWidget);
    await _settleNudge(tester);
  });

  testWidgets('Edit this visit changes the queued log in place', (
    tester,
  ) async {
    final t = await createFaTest();
    // Offline, so the log stays queued (and editable) through the test.
    t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
    await _pump(tester, test: t);
    await _takePhoto(tester);
    await _pickIssue(tester, 'Pink bollworm');
    await _tap(tester, _severity(en.enumSeverityModerate));
    await _save(tester);
    final first = _logs(t).single;

    await _tap(tester, find.text(en.faVisitLogEditVisit));
    await _scrollTo(tester, _severity(en.enumSeverityHigh));
    await _tap(tester, _severity(en.enumSeverityHigh));
    await _takePhoto(tester);
    await _tap(tester, orbitButton(en.faVisitLogSaveChanges));

    final edited = _logs(t).single;
    expect(edited.visitId, first.visitId);
    expect(edited.issues.single.severity, Severity.high);
    expect(edited.photos, hasLength(2));
    expect(edited.photos.first.photoId, first.photos.single.photoId);
    expect(find.text('Pink bollworm (high)'), findsOneWidget);

    // Leaving an edit without saving puts the saved values back.
    await _tap(tester, find.text(en.faVisitLogEditVisit));
    await _scrollTo(tester, _severity(en.enumSeverityLow));
    await _tap(tester, _severity(en.enumSeverityLow));
    await tester.tap(find.byTooltip(en.faVisitLogBackToCalendar));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.faVisitLogDiscard));
    await tester.pumpAndSettle();
    expect(find.text('Pink bollworm (high)'), findsOneWidget);
    expect(_logs(t).single.issues.single.severity, Severity.high);
    await _settleNudge(tester);
  });

  testWidgets('Back to calendar and Open farmer', (tester) async {
    final t = await _pump(tester);
    await _takePhoto(tester);
    await _save(tester);
    await _tap(tester, orbitButton(en.faVisitLogOpenFarmer(name: 'Ravi K')));
    expect(currentPath(t.router), AppRoutes.farmer(MockBackend.raviId));
    await _settleNudge(tester);
  });

  testWidgets('Back to calendar goes to the calendar', (tester) async {
    final t = await _pump(tester);
    await _takePhoto(tester);
    await _save(tester);
    await _tap(tester, orbitButton(en.faVisitLogBackToCalendar));
    expect(currentPath(t.router), AppRoutes.calendar);
    await _settleNudge(tester);
  });

  testWidgets('next visit: not now, or a date from the picker', (tester) async {
    final t = await _pump(tester);
    await _takePhoto(tester);
    await _tap(tester, _chip(en.faVisitLogNextNone));
    await _save(tester);
    expect(_logs(t).single.nextVisit, isNull);
    expect(find.text(en.faVisitLogNotPlanned), findsOneWidget);
    await _settleNudge(tester);
  });

  testWidgets('next visit from the date picker', (tester) async {
    final t = await _pump(tester);
    await _takePhoto(tester);
    await _tap(tester, _chip(en.faVisitLogNextOther));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(_logs(t).single.nextVisit!.plannedFor, LocalDate(2026, 11, 20));
    await _settleNudge(tester);
  });

  testWidgets('farmer away and no GPS: saved without a location', (
    tester,
  ) async {
    final t = await createFaTest();
    (t.read(locationServiceProvider) as MockLocationService).setProblem(
      LocationProblem.timeout,
    );
    await _pump(tester, test: t);
    expect(find.textContaining(en.faVisitLogGpsNone), findsOneWidget);
    expect(find.byTooltip(en.faVisitLogGpsRetry), findsOneWidget);
    await _tap(tester, find.text(en.faVisitLogFarmerPresent));
    expect(find.textContaining(en.faVisitLogPresentNo), findsOneWidget);
    await _takePhoto(tester);
    await _save(tester);
    final log = _logs(t).single;
    expect(log.location, isNull);
    expect(log.farmerPresent, isFalse);
    await _settleNudge(tester);
  });

  testWidgets('the camera failing says so', (tester) async {
    final t = await createFaTest();
    (t.read(photoCaptureProvider) as MockPhotoCapture).failNext();
    await _pump(tester, test: t);
    await _takePhoto(tester);
    expect(find.text(en.faVisitLogCameraFailed), findsOneWidget);
    expect(
      find.textContaining(en.faVisitLogPhotoCount(count: 0)),
      findsOneWidget,
    );
  });

  testWidgets('leaving with details entered asks first', (tester) async {
    final t = await _pump(tester);
    await _takePhoto(tester);
    await systemBack(tester);
    expect(find.text(en.faVisitLogDiscardTitle), findsOneWidget);
    await tester.tap(find.text(en.faVisitLogStay));
    await tester.pumpAndSettle();
    expect(find.byType(VisitLogScreen), findsOneWidget);

    await tester.tap(find.byTooltip(en.faVisitLogBackToCalendar));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.faVisitLogDiscard));
    await tester.pumpAndSettle();
    expect(currentPath(t.router), AppRoutes.calendar);
    expect(_logs(t), isEmpty);
  });

  testWidgets('a visit already logged, or a farmer not here', (tester) async {
    final t = await createFaTest();
    final sita = t.territory
        .visitsOn(_today)
        .all
        .firstWhere((r) => r.farmer?.name == 'Sita R')
        .visit;
    await _pump(
      tester,
      test: t,
      build: (_) => VisitLogScreen(farmerId: sita.farmerId, visitId: sita.id),
    );
    expect(find.text(en.faVisitLogAlreadyLogged), findsOneWidget);
  });

  testWidgets('an unknown farmer shows not found', (tester) async {
    await _pump(tester, build: (_) => const VisitLogScreen(farmerId: 'nobody'));
    expect(find.text(en.errorNotFound), findsOneWidget);
  });

  testWidgets('Telugu: issues in Telugu, severities in both', (tester) async {
    await _pump(tester, locale: const Locale('te'));
    expect(find.text(te.faShellTitleVisitLog), findsOneWidget);
    expect(find.text('పూత దశ'), findsWidgets);
    await _tap(tester, find.byType(PickerButton));
    expect(find.text('గులాబీ రంగు పురుగు'), findsOneWidget);
    expect(find.text('Pink bollworm'), findsOneWidget);
    await tester.tap(find.text('గులాబీ రంగు పురుగు'));
    await tester.pumpAndSettle();
    expect(_severity(te.enumSeverityModerate), findsOneWidget);
    expect(_severity(en.enumSeverityModerate), findsOneWidget);
    expectCleanLayout(tester);
  });

  screenLayoutTest('the visit log', () => const _RaviToday());
  screenLayoutTest(
    'an issue with advice',
    () => const _RaviToday(),
    after: (tester, t) async {
      await _tap(tester, find.byType(PickerButton));
      await tester.tap(find.text('గులాబీ రంగు పురుగు'));
      await tester.pumpAndSettle();
      await _tap(tester, _severity(te.enumSeverityModerate));
      await _tap(tester, orbitButton(te.faVisitLogAddIssue));
      await _scrollTo(tester, find.text(te.faVisitLogFarmerPresent));
    },
  );
  screenLayoutTest(
    'visit saved',
    () => const _RaviToday(),
    after: (tester, t) async {
      await _tap(tester, find.byIcon(OrbitIcons.camera));
      await _tap(tester, orbitButton(te.faVisitLogSave));
      expect(find.text(te.faVisitLogSavedTitle), findsOneWidget);
      await _scrollTo(tester, find.text(te.faVisitLogEditVisit));
      await _settleNudge(tester);
    },
  );

  testWidgets('a visit with no issue tells the calendar there is no advice', (
    tester,
  ) async {
    final t = await _pump(tester);
    await _takePhoto(tester);
    await _save(tester);
    expect(_logs(t).single.issues, isEmpty);
    expect(t.read(visitNoticeProvider)!.hasAdvice, isFalse);
    await _settleNudge(tester);
  });

  testWidgets('saves when the phone clock is 20 minutes slow', (tester) async {
    // The server's time is 20 minutes ahead of the phone's: the visit is
    // stamped with the server's time and must not count as "in the future".
    final t = await createFaTest(
      overrides: [
        serverClockProvider.overrideWithValue(
          FixedClock(testStart.add(const Duration(minutes: 20))),
        ),
      ],
    );
    await _pump(tester, test: t);
    await _takePhoto(tester);
    await _save(tester);
    expect(find.text(en.faActionErrorInvalidDate), findsNothing);
    final log = _logs(t).single;
    expect(log.visitedAt, testStart.add(const Duration(minutes: 20)));
    expect(find.text(en.faVisitLogSavedTitle), findsOneWidget);
    await _settleNudge(tester);
  });

  testWidgets('a plan whose day passed can still be logged', (tester) async {
    final t = await createFaTest();
    final planned = _raviToday(t);
    testClock.advance(const Duration(days: 1));
    await t.container.read(territoryProvider.notifier).reload();
    await pumpFaScreen(
      tester,
      VisitLogScreen(
        farmerId: planned.farmerId,
        visitId: planned.id,
        plotId: planned.plotId,
      ),
      test: t,
      locale: const Locale('en'),
    );
    tester.view.physicalSize = const Size(360, 2000);
    await tester.pumpAndSettle();
    expect(find.text(en.faVisitLogAlreadyLogged), findsNothing);
    await _takePhoto(tester);
    await _save(tester);
    expect(_logs(t).single.visitId, planned.id);
    expect(t.territory.visit(planned.id)!.status, VisitStatus.done);
    await _settleNudge(tester);
  });
}

/// The visit log of Ravi's visit today, read from the territory once (for
/// [screenLayoutTest], which makes the container itself).
class _RaviToday extends ConsumerStatefulWidget {
  const _RaviToday();

  @override
  ConsumerState<_RaviToday> createState() => _RaviTodayState();
}

class _RaviTodayState extends ConsumerState<_RaviToday> {
  late final SnapVisit _visit = ref
      .read(territoryProvider)
      .requireValue
      .visitsOn(_today)
      .all
      .firstWhere((r) => r.farmer?.name == 'Ravi K' && r.isPlanned)
      .visit;

  @override
  Widget build(BuildContext context) => VisitLogScreen(
    farmerId: _visit.farmerId,
    visitId: _visit.id,
    plotId: _visit.plotId,
  );
}
