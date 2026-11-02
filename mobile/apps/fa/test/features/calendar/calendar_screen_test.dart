import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/calendar/calendar_screen.dart';
import 'package:fa/src/features/calendar/calendar_state.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:fa/src/shared/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

/// Mon 2 Nov 2026, the test's today.
final _today = LocalDate(2026, 11, 2);

Future<FaTest> _pump(
  WidgetTester tester, {
  FaTest? test,
  Locale locale = const Locale('en'),
  MockScenario scenario = MockScenario.normal,
}) => pumpFaScreen(
  tester,
  const CalendarScreen(),
  test: test,
  locale: locale,
  scenario: scenario,
);

Finder _day(LocalDate day) => find.bySemanticsLabel(
  RegExp('^${RegExp.escape(formatDateWeekday(en, day))},'),
);

/// Scrolls the calendar until [finder] is on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Lets the engine's debounced nudge after a write fire (it syncs).
Future<void> _settleNudge(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

SnapVisit _planned(FaTest t, String name, LocalDate day) => t.territory
    .visitsOn(day)
    .all
    .firstWhere((r) => r.farmer?.name == name && r.isPlanned)
    .visit;

void main() {
  testWidgets("shows today's visits by slot with the day's counts", (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text(en.faCalendarTitle), findsOneWidget);
    expect(
      find.text(
        '${formatDateWeekday(en, _today)} · ${en.faCalendarVisitCount(count: 3)}'
        ' · ${en.faCalendarDoneCount(count: 1)}',
      ),
      findsOneWidget,
    );
    expect(find.text(en.enumPlannedSlotMorning.toUpperCase()), findsOneWidget);
    expect(
      find.text(en.enumPlannedSlotAfternoon.toUpperCase()),
      findsOneWidget,
    );
    for (final name in ['Ravi K', 'Sita R', 'Venkatesh M']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(
      find.textContaining('Plot 1 · Cotton · Pest follow-up'),
      findsOneWidget,
    );
    expect(statusPill(en.faCalendarStatusDone), findsOneWidget);
    expect(statusPill(en.faCalendarStatusPlanned), findsNWidgets(2));
    // Planned today: Start visit and Call on both; Plan my route is Phase 3.
    expect(orbitButton(en.faCalendarStartVisit), findsNWidgets(2));
    expect(orbitButton(en.commonCall), findsNWidgets(2));
    await _scrollTo(tester, find.text(en.faCalendarFooterNote));
    expect(find.textContaining('route'), findsNothing);
  });

  testWidgets('Start visit opens the visit log for that visit', (tester) async {
    final t = await _pump(tester);
    final ravi = _planned(t, 'Ravi K', _today);
    await tester.tap(orbitButton(en.faCalendarStartVisit).first);
    await tester.pumpAndSettle();
    expect(
      currentLocation(t.router),
      AppRoutes.visit(
        farmerId: ravi.farmerId,
        visitId: ravi.id,
        plotId: ravi.plotId,
      ),
    );
  });

  testWidgets('Call opens the dialer with the farmer\'s phone', (tester) async {
    final t = await _pump(tester);
    await tester.tap(orbitButton(en.commonCall).first);
    await tester.pumpAndSettle();
    expect(t.launcher.calls, [MockBackend.raviPhone]);

    t.launcher.opens = false;
    await tester.tap(orbitButton(en.commonCall).first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        en.faCommonCallFailed(phone: formatIndianMobile(MockBackend.raviPhone)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('picking a day shows its visits; future ones cannot start', (
    tester,
  ) async {
    final t = await _pump(tester);
    final tomorrow = _today.addDays(1);
    await tester.tap(_day(tomorrow));
    await tester.pumpAndSettle();
    expect(t.read(calendarDayProvider), tomorrow);
    expect(find.text('Anil G'), findsOneWidget);
    expect(find.text('Ravi K'), findsOneWidget);
    expect(find.text('Sita R'), findsNothing);
    expect(orbitButton(en.faCalendarStartVisit), findsNothing);
    // Kumar B has never had a visit.
    await tester.tap(_day(_today.addDays(2)));
    await tester.pumpAndSettle();
    expect(statusPill(en.faCalendarStatusFirstVisit), findsOneWidget);
    // Back to today.
    await tester.tap(_day(_today));
    await tester.pumpAndSettle();
    expect(t.read(calendarDayProvider), isNull);
  });

  testWidgets('the week arrows move a week; This week comes back', (
    tester,
  ) async {
    final t = await _pump(tester);
    await tester.tap(find.byTooltip(en.faCalendarNextWeek));
    await tester.pumpAndSettle();
    expect(t.read(calendarDayProvider), _today.addDays(7));
    expect(
      find.textContaining(
        en.faCalendarWeekOf(date: formatDateShort(en, _today.addDays(7))),
      ),
      findsOneWidget,
    );
    expect(find.text(en.faCalendarEmptyTitle), findsOneWidget);
    await tester.tap(find.textContaining(en.faCalendarThisWeek));
    await tester.pumpAndSettle();
    expect(t.read(calendarDayProvider), isNull);
    await tester.tap(find.byTooltip(en.faCalendarPreviousWeek));
    await tester.pumpAndSettle();
    expect(t.read(calendarDayProvider), _today.addDays(-7));
  });

  testWidgets('an empty day sends the FA to the farmers due a visit', (
    tester,
  ) async {
    final t = await _pump(tester);
    await tester.tap(_day(_today.addDays(4)));
    await tester.pumpAndSettle();
    expect(find.text(en.faCalendarEmptyTitle), findsOneWidget);
    expect(find.text(en.faCalendarEmptyBody), findsOneWidget);
    await tester.tap(orbitButton(en.faCalendarFindDue));
    await tester.pumpAndSettle();
    expect(
      currentLocation(t.router),
      AppRoutes.farmersFiltered(FarmerFilter.visitDue),
    );
  });

  testWidgets('Add opens Plan a visit', (tester) async {
    final t = await _pump(tester);
    await tester.tap(find.bySemanticsLabel(en.faShellTitlePlanVisit));
    await tester.pumpAndSettle();
    expect(currentLocation(t.router), AppRoutes.planVisit());
  });

  testWidgets('Cancel visit asks first, then cancels it on the phone', (
    tester,
  ) async {
    final t = await _pump(tester);
    final visit = _planned(t, 'Venkatesh M', _today);
    await tester.tap(
      find.byTooltip(en.faCalendarVisitOptions(name: 'Venkatesh M')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.faCalendarCancelVisit));
    await tester.pumpAndSettle();
    expect(
      find.text(en.faCalendarCancelTitle(name: 'Venkatesh M')),
      findsOneWidget,
    );

    // Keep it: nothing happens.
    await tester.tap(find.text(en.faCalendarKeepVisit));
    await tester.pumpAndSettle();
    expect(t.territory.visit(visit.id)!.status, VisitStatus.planned);

    await tester.longPress(find.text('Venkatesh M'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.faCalendarCancelVisit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.faCalendarCancelVisit).last);
    await tester.pumpAndSettle();

    expect(t.territory.visit(visit.id)!.status, VisitStatus.cancelled);
    expect(
      t.territory.outbox.where((e) => e.type == CommandType.cancelVisit),
      hasLength(1),
    );
    expect(find.text('Venkatesh M'), findsNothing);
    expect(
      find.text(en.faCalendarCancelled(name: 'Venkatesh M')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(en.commonClose));
    await tester.pumpAndSettle();
    expect(t.read(visitNoticeProvider), isNull);
    await _settleNudge(tester);
  });

  testWidgets('Move to another day opens Plan a visit for that visit', (
    tester,
  ) async {
    final t = await _pump(tester);
    final visit = _planned(t, 'Ravi K', _today);
    await tester.tap(find.byTooltip(en.faCalendarVisitOptions(name: 'Ravi K')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.faCalendarReschedule));
    await tester.pumpAndSettle();
    expect(t.read(rescheduleRequestProvider), visit.id);
    expect(
      currentLocation(t.router),
      AppRoutes.planVisit(farmerId: visit.farmerId),
    );
  });

  testWidgets('a visit planned on the phone shows Not synced yet', (
    tester,
  ) async {
    final t = await createFaTest(language: Language.en);
    await t
        .read(faActionsProvider)
        .planVisit(
          farmerId: MockBackend.raviId,
          plannedFor: _today.addDays(4),
          purpose: 'Soil sample',
        );
    await _pump(tester, test: t);
    await tester.tap(_day(_today.addDays(4)));
    await tester.pumpAndSettle();
    expect(find.text(en.enumPlannedSlotAny.toUpperCase()), findsOneWidget);
    expect(find.textContaining('Soil sample'), findsOneWidget);
    expect(statusPill(en.faCommonNotSynced), findsOneWidget);
    // Once it synced, the tag goes.
    await _settleNudge(tester);
    expect(statusPill(en.faCommonNotSynced), findsNothing);
  });

  testWidgets('the saved-visit notice shows on its day', (tester) async {
    final t = await createFaTest(language: Language.en);
    final ravi = _planned(t, 'Ravi K', _today);
    t
        .read(visitNoticeProvider.notifier)
        .show(
          VisitNotice(
            kind: VisitNoticeKind.saved,
            farmerId: ravi.farmerId,
            visitId: ravi.id,
            day: _today,
            hasAdvice: true,
          ),
        );
    await _pump(tester, test: t);
    // Not in the outbox: counts as sent.
    expect(find.text(en.faCalendarSavedSent(name: 'Ravi K')), findsOneWidget);
    await tester.tap(_day(_today.addDays(1)));
    await tester.pumpAndSettle();
    expect(find.text(en.faCalendarSavedSent(name: 'Ravi K')), findsNothing);
  });

  testWidgets('offline: a banner says visits still save', (tester) async {
    final t = await createFaTest();
    t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
    await _pump(tester, test: t);
    expect(find.text(en.faCalendarOffline), findsOneWidget);
  });

  testWidgets('Telugu: titles, slots and farmer names in Telugu', (
    tester,
  ) async {
    final t = await _pump(tester, locale: const Locale('te'));
    expect(find.text(te.faCalendarTitle), findsOneWidget);
    expect(find.text(te.enumPlannedSlotMorning), findsOneWidget);
    final ravi = t.territory.farmer(MockBackend.raviId)!;
    expect(find.text(ravi.nameTe!), findsOneWidget);
    expect(orbitButton(te.faCalendarStartVisit), findsOneWidget);
    expectCleanLayout(tester);
  });

  screenLayoutTest('today', () => const CalendarScreen());
  screenLayoutTest(
    'the busiest day',
    () => const CalendarScreen(),
    after: (tester, t) async {
      t.read(calendarDayProvider.notifier).show(_today.addDays(2));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text(te.faCalendarFooterNote));
    },
  );
  screenLayoutTest(
    'an empty day with a notice',
    () => const CalendarScreen(),
    after: (tester, t) async {
      final day = _today.addDays(4);
      t.read(calendarDayProvider.notifier).show(day);
      t
          .read(visitNoticeProvider.notifier)
          .show(
            VisitNotice(
              kind: VisitNoticeKind.planned,
              farmerId: MockBackend.raviId,
              visitId: 'x',
              day: day,
            ),
          );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a saved visit without advice promises no SMS', (tester) async {
    final t = await createFaTest(language: Language.en);
    final ravi = _planned(t, 'Ravi K', _today);
    t
        .read(visitNoticeProvider.notifier)
        .show(
          VisitNotice(
            kind: VisitNoticeKind.saved,
            farmerId: ravi.farmerId,
            visitId: ravi.id,
            day: _today,
          ),
        );
    await _pump(tester, test: t);
    expect(
      find.text(en.faCalendarSavedNoAdvice(name: 'Ravi K')),
      findsOneWidget,
    );
    expect(find.textContaining('SMS'), findsNothing);
  });

  testWidgets('a visit whose day passed shows under today as Overdue', (
    tester,
  ) async {
    final t = await createFaTest(language: Language.en);
    final ravi = _planned(t, 'Ravi K', _today);
    // Two days on, the visit was never logged.
    testClock.advance(const Duration(days: 2));
    await t.container.read(territoryProvider.notifier).reload();
    await _pump(tester, test: t);
    expect(
      t.territory.overdueVisits().map((r) => r.visit.id),
      contains(ravi.id),
    );
    await _scrollTo(tester, statusPill(en.faCalendarStatusOverdue).first);
    expect(statusPill(en.faCalendarStatusOverdue), findsWidgets);
    expect(find.text('Ravi K'), findsWidgets);
    expect(find.text(en.faCalendarEmptyTitle), findsNothing);
    // It can still be started from today.
    final start = orbitButton(en.faCalendarStartVisit);
    await _scrollTo(tester, start.first);
    await tester.tap(start.first);
    await tester.pumpAndSettle();
    expect(currentPath(t.router), AppRoutes.visitPath);
  });

  testWidgets('every day of the strip is a 48 dp target', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final days = find.descendant(
      of: find.byType(DayStrip),
      matching: find.byType(InkWell),
    );
    expect(days, findsNWidgets(7));
    for (final e in days.evaluate()) {
      expect(e.size!.width, greaterThanOrEqualTo(48));
      expect(e.size!.height, greaterThanOrEqualTo(48));
    }
    // The whole week fits: no day is scrolled off the 360 dp phone.
    expect(tester.getRect(days.last).right, lessThanOrEqualTo(360));
    handle.dispose();
  });

  testWidgets('a visit HO marked missed still shows, as Overdue', (
    tester,
  ) async {
    final t = await createFaTest(language: Language.en);
    final ravi = _planned(t, 'Ravi K', _today);
    testClock.advance(const Duration(days: 2));
    // The server's hourly job marks it missed; the pull brings that down.
    await t.read(syncEngineProvider).syncNow();
    await t.container.read(territoryProvider.future);
    expect(t.territory.visit(ravi.id)!.status, VisitStatus.missed);
    await _pump(tester, test: t);
    await _scrollTo(tester, statusPill(en.faCalendarStatusOverdue).first);
    expect(statusPill(en.faCalendarStatusOverdue), findsWidgets);
    expect(
      t.territory.overdueVisits().map((r) => r.visit.id),
      contains(ravi.id),
    );
  });
}
