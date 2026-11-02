import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/calendar/calendar_state.dart';
import 'package:fa/src/features/calendar/plan_visit_screen.dart';
import 'package:fa/src/features/calendar/visit_ui.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:fa/src/shared/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../../support/harness.dart';

/// Mon 2 Nov 2026, the test's today.
final _today = LocalDate(2026, 11, 2);

Future<FaTest> _pump(
  WidgetTester tester, {
  String? farmerId,
  FaTest? test,
  Locale locale = const Locale('en'),
}) => pumpFaScreen(
  tester,
  PlanVisitScreen(farmerId: farmerId),
  test: test,
  locale: locale,
);

/// The PlanVisit commands in the outbox.
List<PlanVisitPayload> _plans(FaTest t) => [
  for (final e in t.territory.outbox)
    if (e.type == CommandType.planVisit) e.command as PlanVisitPayload,
];

Finder _chip(String label) =>
    find.byWidgetPredicate((w) => w is OptionChip && w.label == label);

/// Scrolls the form until [finder] is built and on screen.
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

/// Lets the engine's debounced nudge after a write fire (it syncs).
Future<void> _settleNudge(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

String _farmerId(FaTest t, String name) =>
    t.territory.farmerRows(query: name).first.farmer.id;

void main() {
  testWidgets('plans a visit for today with the defaults', (tester) async {
    final t = await _pump(tester, farmerId: MockBackend.raviId);
    expect(find.text(en.faShellTitlePlanVisit), findsOneWidget);
    expect(find.text('Ravi K'), findsOneWidget);
    expect(_chip('Plot 1 · Cotton'), findsOneWidget);
    expect(tester.widget<OptionChip>(_chip(en.commonToday)).selected, isTrue);
    // Ravi has had visits: a stage check by default.
    expect(
      tester
          .widget<OptionChip>(_chip(en.faPlanVisitPurposeStageCheck))
          .selected,
      isTrue,
    );

    await _tap(tester, orbitButton(en.faPlanVisitSave));

    final plan = _plans(t).single;
    expect(plan.farmerId, MockBackend.raviId);
    expect(plan.plannedFor, _today);
    expect(plan.plannedSlot, VisitSlot.any);
    expect(plan.purpose, VisitPurpose.stageCheck.wire);
    expect(t.territory.visit(plan.visitId)!.status, VisitStatus.planned);
    expect(currentPath(t.router), AppRoutes.calendar);
    expect(t.read(calendarDayProvider), isNull);
    final notice = t.read(visitNoticeProvider)!;
    expect(notice.kind, VisitNoticeKind.planned);
    expect(notice.visitId, plan.visitId);
    await _settleNudge(tester);
  });

  testWidgets('day, time and purpose chips go into the plan', (tester) async {
    final t = await _pump(tester, farmerId: MockBackend.raviId);
    final day = _today.addDays(3);
    await _tap(tester, _chip(formatDateWeekday(en, day)));
    await _tap(tester, find.text(en.enumPlannedSlotMorning));
    await _tap(tester, _chip(en.faPlanVisitPurposePestFollowUp));
    await _tap(tester, orbitButton(en.faPlanVisitSave));

    final plan = _plans(t).single;
    expect(plan.plannedFor, day);
    expect(plan.plannedSlot, VisitSlot.morning);
    expect(plan.purpose, 'Pest follow-up');
    expect(t.read(calendarDayProvider), day);
    await _settleNudge(tester);
  });

  testWidgets('Other purpose needs words; they are saved as typed', (
    tester,
  ) async {
    final t = await _pump(tester, farmerId: MockBackend.raviId);
    await _tap(tester, _chip(en.faPlanVisitPurposeOther));
    await _tap(tester, orbitButton(en.faPlanVisitSave));
    expect(find.text(en.faPlanVisitPurposeRequired), findsOneWidget);
    expect(_plans(t), isEmpty);

    await tester.enterText(find.byType(TextField), 'Collect drip bill');
    await _tap(tester, orbitButton(en.faPlanVisitSave));
    expect(_plans(t).single.purpose, 'Collect drip bill');
    await _settleNudge(tester);
  });

  testWidgets('a farmer never visited gets First visit by default', (
    tester,
  ) async {
    final t = await createFaTest();
    final kumar = _farmerId(t, 'Kumar B');
    await _pump(tester, test: t, farmerId: kumar);
    // Kumar B has more than one plot with a crop.
    expect(
      find.byWidgetPredicate(
        (w) => w is OptionChip && w.label.startsWith('Plot '),
      ),
      findsAtLeastNWidgets(2),
    );
    await _scrollTo(tester, _chip(en.faPlanVisitPurposeFirstVisit));
    expect(
      tester
          .widget<OptionChip>(_chip(en.faPlanVisitPurposeFirstVisit))
          .selected,
      isTrue,
    );
  });

  testWidgets('the date picker offers up to 13 days ahead', (tester) async {
    final t = await _pump(tester, farmerId: MockBackend.raviId);
    await _tap(tester, _chip(en.faPlanVisitOtherDate));
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    // Today to today + 13 (14 days in all), nothing before or after.
    expect(DateUtils.dateOnly(picker.firstDate), DateTime(2026, 11, 2));
    expect(DateUtils.dateOnly(picker.lastDate), DateTime(2026, 11, 15));
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final day = LocalDate(2026, 11, 12);
    expect(
      tester.widget<OptionChip>(_chip(formatDateWeekday(en, day))).selected,
      isTrue,
    );
    await _tap(tester, orbitButton(en.faPlanVisitSave));
    expect(_plans(t).single.plannedFor, day);
    await _settleNudge(tester);
  });

  testWidgets('without a farmer: search, pick, change', (tester) async {
    final t = await _pump(tester);
    expect(find.textContaining(en.faPlanVisitPickFarmer), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Venkat R');
    await tester.pumpAndSettle();
    expect(find.text('Venkat R'), findsNWidgets(2)); // the field and the row
    await tester.tap(find.text('Venkat R').last);
    await tester.pumpAndSettle();
    expect(_chip('Plot 1 · Cotton'), findsOneWidget);

    await tester.tap(find.text(en.faPlanVisitChangeFarmer));
    await tester.pumpAndSettle();
    expect(find.textContaining(en.faPlanVisitPickFarmer), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody here');
    await tester.pumpAndSettle();
    expect(find.text(en.faPlanVisitNoMatch), findsOneWidget);

    // Android back from the form returns to the list, not out.
    await tester.enterText(find.byType(TextField), 'Venkat R');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Venkat R').last);
    await tester.pumpAndSettle();
    await systemBack(tester);
    expect(find.textContaining(en.faPlanVisitPickFarmer), findsOneWidget);
    expect(currentPath(t.router), '/screen');
  });

  testWidgets('moving a visit re-plans the same visit on the new day', (
    tester,
  ) async {
    final t = await createFaTest();
    final old = t.territory
        .visitsOn(_today.addDays(1))
        .all
        .firstWhere((r) => r.farmer?.name == 'Ravi K')
        .visit;
    t.read(rescheduleRequestProvider.notifier).request(old.id);
    await _pump(tester, test: t, farmerId: MockBackend.raviId);
    expect(find.text(en.faPlanVisitRescheduleTitle), findsWidgets);
    expect(
      find.text(
        en.faPlanVisitMovingFrom(
          date: formatDateWeekday(en, _today.addDays(1)),
        ),
      ),
      findsOneWidget,
    );
    // Its free-text purpose is kept.
    await _scrollTo(tester, find.text(old.purpose!));
    expect(t.read(rescheduleRequestProvider), isNull);

    final day = _today.addDays(5);
    await _tap(tester, _chip(formatDateWeekday(en, day)));
    await _tap(tester, orbitButton(en.faPlanVisitMove));

    final plan = _plans(t).single;
    expect(plan.visitId, old.id, reason: 'a re-plan reuses the visit');
    expect(plan.plannedFor, day);
    expect(plan.purpose, old.purpose);
    expect(plan.plotId, old.plotId);
    expect(plan.seasonId, old.seasonId);
    expect([
      for (final e in t.territory.outbox)
        if (e.type == CommandType.cancelVisit) e,
    ], isEmpty);
    final moved = t.territory.visit(old.id)!;
    expect(moved.status, VisitStatus.planned);
    expect(moved.plannedFor, day);
    expect(t.read(visitNoticeProvider)!.visitId, old.id);
    expect(t.read(visitNoticeProvider)!.kind, VisitNoticeKind.moved);
    expect(t.read(calendarDayProvider), day);
    await _settleNudge(tester);
  });

  testWidgets('an unknown farmer shows not found', (tester) async {
    await _pump(tester, farmerId: 'nobody');
    expect(find.text(en.errorNotFound), findsOneWidget);
  });

  testWidgets('Telugu: the form in Telugu', (tester) async {
    await _pump(
      tester,
      farmerId: MockBackend.raviId,
      locale: const Locale('te'),
    );
    expect(find.text(te.faShellTitlePlanVisit), findsOneWidget);
    expect(find.text(te.faPlanVisitPurposeStageCheck), findsOneWidget);
    expect(find.text('రవి కె'), findsOneWidget);
    expectCleanLayout(tester);
  });

  screenLayoutTest(
    'the form',
    () => PlanVisitScreen(farmerId: MockBackend.raviId),
  );
  screenLayoutTest(
    'the form with Other',
    () => PlanVisitScreen(farmerId: MockBackend.raviId),
    after: (tester, t) async {
      await _tap(tester, _chip(te.faPlanVisitPurposeOther));
      await _tap(tester, orbitButton(te.faPlanVisitSave));
      expect(find.text(te.faPlanVisitPurposeRequired), findsOneWidget);
    },
  );
  screenLayoutTest('the farmer list', () => const PlanVisitScreen());

  testWidgets('a link for another farmer starts the form over', (tester) async {
    final t = await createFaTest();
    final rows = [
      for (final r in t.territory.farmerRows())
        if (r.plots.any((p) => p.season != null)) r,
    ];
    final x = rows[0].farmer;
    final y = rows[1].farmer;
    final farmer = ValueNotifier<String?>(x.id);
    addTearDown(farmer.dispose);
    await pumpFaScreen(
      tester,
      ValueListenableBuilder(
        valueListenable: farmer,
        builder: (_, id, _) => PlanVisitScreen(farmerId: id),
      ),
      test: t,
      locale: const Locale('en'),
    );
    expect(find.text(x.name!), findsWidgets);
    // The router reuses the page for the next link's farmer.
    farmer.value = y.id;
    await tester.pumpAndSettle();
    expect(find.text(y.name!), findsWidgets);
    expect(find.text(x.name!), findsNothing);
    await _tap(tester, orbitButton(en.faPlanVisitSave));
    expect(_plans(t).single.farmerId, y.id);
    await _settleNudge(tester);
  });
}
