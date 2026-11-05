import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/enrol/consent_panel.dart';
import 'package:fa/src/features/farmer360/edit_profile_sheet.dart';
import 'package:fa/src/features/farmer360/farmer360_screen.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:fa/src/shared/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import '../farmers/farmers_test_support.dart';

Future<FaTest> _pump(
  WidgetTester tester,
  String farmerId, {
  FaTest? test,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => pumpFaScreen(
  tester,
  Farmer360Screen(farmerId: farmerId),
  test: test,
  location: AppRoutes.farmer(farmerId),
  locale: locale,
  textScale: textScale,
  overrides: farmersOverrides(),
);

String get _ravi => MockBackend.raviId;

String _kumar(FaTest t) => rowNamed(t.territory, 'Kumar B').farmer.id;

Future<void> _openEdit(WidgetTester tester) async {
  await scrollAndTap(tester, orbitButton(en.faFarmer360EditProfile));
  expect(find.byType(EditProfileSheet), findsOneWidget);
}

Finder _sheetField(String label) => find.descendant(
  of: find.byType(EditProfileSheet),
  matching: find.widgetWithText(TextField, label),
);

/// A store whose writes fail, as a full or broken disk would. Edit profile
/// only ever opens a transaction.
final class _BrokenStore implements LocalStore {
  @override
  Future<T> transaction<T>(Future<T> Function(LocalTables tx) action) =>
      Future.error(StateError('disk full'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Ravi K', () {
    testWidgets('header, plot with stage and day, last visit with advice', (
      tester,
    ) async {
      final t = await _pump(tester, _ravi);
      final v = t.territory.farmer360(_ravi)!;
      expect(find.text('Ravi K'), findsOneWidget);
      expect(find.text('90000 00101 · Kondapur'), findsOneWidget);
      final plot = v.plots.first;
      expect(
        find.text('${plot.plot.label} · Cotton · 2 ac 4 gunta'),
        findsOneWidget,
      );
      expect(
        find.text(
          en.faFarmer360PlotStageDay(
            stage: plot.stage!.name,
            day: plot.daysAfterSowing!,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Pink bollworm', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining(en.faFarmer360Advised(advice: 'Sample 5 SG')),
        findsOneWidget,
      );
      expect(find.text(en.enumFarmerPlanFree), findsOneWidget);
      // Later phases stay out.
      expect(find.textContaining('Wallet'), findsNothing);
      expect(find.textContaining('KYC'), findsNothing);
    });

    testWidgets('Call, WhatsApp and Directions open the other apps', (
      tester,
    ) async {
      final t = await _pump(tester, _ravi);
      final v = t.territory.farmer360(_ravi)!;
      await tester.tap(find.text(en.commonCall).first);
      await tester.tap(find.text(en.commonWhatsapp));
      await tester.tap(find.text(en.faFarmersActionDirections));
      await tester.pumpAndSettle();
      expect(t.launcher.calls, [v.farmer.phone]);
      expect(t.launcher.whatsApps.single.$1, v.farmer.phone);
      expect(t.launcher.directionsTo.single, (
        v.row.location!.lat,
        v.row.location!.lng,
      ));
    });

    testWidgets("Start visit opens today's planned visit on its plot", (
      tester,
    ) async {
      final t = await _pump(tester, _ravi);
      final today = t.territory.today;
      final planned = t.territory
          .farmer360(_ravi)!
          .plannedVisits
          .firstWhere((r) => r.visit.plannedFor == today)
          .visit;
      await tester.tap(find.text(en.faFarmer360StartVisit));
      await tester.pumpAndSettle();
      expect(
        currentLocation(t.router),
        AppRoutes.visit(
          farmerId: _ravi,
          visitId: planned.id,
          plotId: planned.plotId,
        ),
      );
    });

    testWidgets('call-back: call, then close it', (tester) async {
      final t = await _pump(tester, _ravi);
      expect(t.territory.openCallback(_ravi), isNotNull);
      expect(find.text(en.faFarmer360RowCallback), findsOneWidget);
      expect(find.text(en.faFarmer360CallbackClose), findsNothing);
      await tester.tap(find.text(en.commonCall).first);
      await tester.pumpAndSettle();
      await scrollAndTap(tester, orbitButton(en.faFarmer360CallbackClose));
      expect(find.text(en.faFarmer360CallbackClosed), findsOneWidget);
      expect(t.territory.openCallback(_ravi), isNull);
      expect(
        t.territory.outbox.where((e) => e.type == CommandType.closeCallback),
        hasLength(1),
      );
      expect(find.text(en.faFarmer360RowCallback), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Plan a visit opens the calendar for this farmer', (
      tester,
    ) async {
      final t = await _pump(tester, _ravi);
      await scrollAndTap(tester, orbitButton(en.faFarmer360PlanVisit));
      expect(currentLocation(t.router), AppRoutes.planVisit(farmerId: _ravi));
    });
  });

  group('consent', () {
    testWidgets('a consent-pending farmer gets Record consent (OTP sheet)', (
      tester,
    ) async {
      final t = await createFaTest(overrides: farmersOverrides());
      await _pump(tester, _kumar(t), test: t);
      expect(statusPill(en.faFarmer360ConsentPending), findsOneWidget);
      await scrollAndTap(tester, orbitButton(en.faFarmer360RecordConsent));
      expect(find.byType(RecordConsentSheet), findsOneWidget);
    });

    testWidgets('a farmer with consent shows how many purposes', (
      tester,
    ) async {
      final t = await _pump(tester, _ravi);
      final granted = t.territory.farmer360(_ravi)!.consentsGranted.length;
      expect(
        find.text(en.faFarmer360ConsentCount(count: granted, total: 4)),
        findsOneWidget,
      );
      expect(find.text(en.faFarmer360RecordConsent), findsNothing);
    });
  });

  group('edit profile', () {
    testWidgets('saves the name and language on the phone', (tester) async {
      final t = await _pump(tester, _ravi);
      await _openEdit(tester);
      await tester.enterText(_sheetField(en.faFarmer360EditName), 'Ravi Kumar');
      await tester.tap(find.text(en.enumLanguageEn));
      await tester.tap(orbitButton(en.commonSave));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileSheet), findsNothing);
      expect(find.text(en.faFarmer360EditSaved), findsOneWidget);
      final f = t.territory.farmer(_ravi)!;
      expect(f.name, 'Ravi Kumar');
      expect(f.language, Language.en);
      final entry = t.territory.outbox.singleWhere(
        (e) => e.type == CommandType.updateFarmer,
      );
      expect(entry.state, OutboxState.queued);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(t.territory.isPending(_ravi), isTrue);
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(statusPill(en.faCommonNotSynced), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('an empty name is refused; no change says so', (tester) async {
      final t = await _pump(tester, _ravi);
      await _openEdit(tester);
      await tester.enterText(_sheetField(en.faFarmer360EditName), '  ');
      await tester.tap(orbitButton(en.commonSave));
      await tester.pumpAndSettle();
      expect(find.text(en.faFarmer360EditRequired), findsOneWidget);

      await tester.enterText(_sheetField(en.faFarmer360EditName), 'Ravi K');
      await tester.tap(orbitButton(en.commonSave));
      await tester.pumpAndSettle();
      expect(find.text(en.faFarmer360EditNothingChanged), findsOneWidget);
      expect(find.byType(EditProfileSheet), findsOneWidget);
      expect(t.territory.outbox, isEmpty);
    });

    testWidgets(
      'an HO edit meanwhile shows the conflict; Keep HO\'s clears it',
      (tester) async {
        final t = await createFaTest(
          scenario: MockScenario.syncConflict,
          overrides: farmersOverrides(),
        );
        final padma = MockBackend.padmaId;
        await _pump(tester, padma, test: t);
        await _openEdit(tester);
        await tester.enterText(
          _sheetField(en.faFarmer360EditName),
          'Padma Sri',
        );
        await tester.tap(orbitButton(en.commonSave));
        await tester.pumpAndSettle();
        await t.read(syncEngineProvider).syncNow();
        await tester.pumpAndSettle();
        expect(find.byType(ConflictCard), findsOneWidget);
        expect(find.text('Padma Sri'), findsWidgets); // yours
        expect(find.text('Padma Sri (HO)'), findsWidgets); // HO's
        // The "Saved" snack bar would cover the card's buttons.
        ScaffoldMessenger.of(tester.element(find.byType(ConflictCard)))
            .removeCurrentSnackBar();
        final keepTheirs = find.text(en.faFarmer360ConflictKeepTheirs);
        await tester.ensureVisible(keepTheirs);
        await tester.pumpAndSettle();
        await tester.tap(keepTheirs);
        await tester.pumpAndSettle();
        expect(find.byType(ConflictCard), findsNothing);
        expect(
          t.territory.outbox.where((e) => e.state == OutboxState.conflict),
          isEmpty,
        );
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  group('ids', () {
    testWidgets('an unknown farmer shows Not found', (tester) async {
      await _pump(tester, 'no-such-farmer');
      expect(find.byType(NotFoundCard), findsOneWidget);
    });

    testWidgets('a merged farmer ID still opens the farmer', (tester) async {
      final t = await createFaTest(overrides: farmersOverrides());
      t.backend.scenario = MockScenario.offline;
      final minted = await t
          .read(faActionsProvider)
          .enrolFarmer(
            phone: MockBackend.rajuPhone,
            name: 'Raju P',
            language: Language.te,
            villageId: MockBackend.kondapurId,
          );
      t.backend.scenario = MockScenario.normal;
      await t.read(syncEngineProvider).syncNow();
      expect(t.territory.resolveFarmerId(minted), MockBackend.rajuId);
      await _pump(tester, minted, test: t);
      expect(find.text('Raju P'), findsOneWidget);
      expect(find.byType(NotFoundCard), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Telugu', () {
    testWidgets('renders labels and content in Telugu', (tester) async {
      final t = await _pump(tester, _ravi, locale: const Locale('te'));
      final f = t.territory.farmer(_ravi)!;
      expect(find.text(f.nameTe!), findsOneWidget);
      expect(find.text(te.faFarmer360RowPlot), findsOneWidget);
      expect(find.text(te.faFarmer360StartVisit), findsOneWidget);
    });
  });

  group('layout', () {
    for (final scale in textScales) {
      testWidgets('Ravi K fits 360x640 at text scale $scale', (tester) async {
        await _pump(
          tester,
          _ravi,
          locale: const Locale('te'),
          textScale: scale,
        );
        expectCleanLayout(tester);
      });

      testWidgets('consent pending fits 360x640 at text scale $scale', (
        tester,
      ) async {
        final t = await createFaTest(overrides: farmersOverrides());
        await _pump(
          tester,
          _kumar(t),
          test: t,
          locale: const Locale('te'),
          textScale: scale,
        );
        expectCleanLayout(tester);
      });

      testWidgets('edit profile fits 360x640 at text scale $scale', (
        tester,
      ) async {
        await _pump(
          tester,
          _ravi,
          locale: const Locale('te'),
          textScale: scale,
        );
        await scrollAndTap(tester, orbitButton(te.faFarmer360EditProfile));
        expectCleanLayout(tester);
      });
    }
  });

  testWidgets('clearing the Telugu name says it cannot be cleared', (
    tester,
  ) async {
    final t = await _pump(tester, _ravi);
    expect(t.territory.farmer(_ravi)!.nameTe, isNotNull);
    await _openEdit(tester);
    await tester.enterText(_sheetField(en.faFarmer360EditNameTe), '');
    await tester.tap(orbitButton(en.commonSave));
    await tester.pumpAndSettle();
    expect(find.text(en.faActionErrorCannotClear), findsOneWidget);
    expect(find.byType(EditProfileSheet), findsOneWidget);
    expect(t.territory.outbox, isEmpty);
  });

  testWidgets('a save that fails on the phone says so and can be retried', (
    tester,
  ) async {
    final t = await createFaTest(
      overrides: [
        ...farmersOverrides(),
        faActionsProvider.overrideWith(
          (ref) =>
              FaActions(store: _BrokenStore(), clock: ref.watch(clockProvider)),
        ),
      ],
    );
    await _pump(tester, _ravi, test: t);
    await _openEdit(tester);
    await tester.enterText(_sheetField(en.faFarmer360EditName), 'Ravi Kumar');
    await tester.tap(orbitButton(en.commonSave));
    await tester.pumpAndSettle();
    expect(find.text(en.errorUnknown), findsOneWidget);
    final save = tester.widget<OrbitButton>(orbitButton(en.commonSave));
    expect(save.loading, isFalse);
    expect(save.onPressed, isNotNull);
  });

  testWidgets('Start visit logs a plan whose day has passed', (tester) async {
    final t = await createFaTest(overrides: farmersOverrides());
    final today = t.territory.today;
    final planned = t.territory
        .farmer360(_ravi)!
        .plannedVisits
        .firstWhere((r) => r.visit.plannedFor == today)
        .visit;
    testClock.advance(const Duration(days: 1));
    await t.container.read(territoryProvider.notifier).reload();
    await _pump(tester, _ravi, test: t);
    expect(statusPill(en.faCalendarStatusOverdue), findsOneWidget);
    await tester.tap(find.text(en.faFarmer360StartVisit));
    await tester.pumpAndSettle();
    expect(
      currentLocation(t.router),
      AppRoutes.visit(
        farmerId: _ravi,
        visitId: planned.id,
        plotId: planned.plotId,
      ),
    );
  });

  testWidgets('another farmer on the same page starts fresh', (tester) async {
    final t = await createFaTest(overrides: farmersOverrides());
    final kumar = _kumar(t);
    t.backend.addCallback(kumar);
    await t.read(syncEngineProvider).syncNow();
    await t.container.read(territoryProvider.future);
    expect(t.territory.openCallback(kumar), isNotNull);
    final farmer = ValueNotifier(_ravi);
    addTearDown(farmer.dispose);
    await pumpFaScreen(
      tester,
      ValueListenableBuilder(
        valueListenable: farmer,
        builder: (_, id, _) => Farmer360Screen(farmerId: id),
      ),
      test: t,
      locale: const Locale('en'),
    );
    // A tall phone, so the whole summary is built.
    tester.view.physicalSize = const Size(360, 2000);
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.commonCall).first);
    await tester.pumpAndSettle();
    expect(orbitButton(en.faFarmer360CallbackClose), findsOneWidget);
    // A link to Kumar reuses the page: he was not called from here.
    farmer.value = kumar;
    await tester.pumpAndSettle();
    expect(find.text('Kumar B'), findsWidgets);
    expect(find.text(en.faFarmer360RowCallback), findsOneWidget);
    expect(orbitButton(en.faFarmer360CallbackClose), findsNothing);
  });

  testWidgets('an edit made during a conflict waits on the card', (
    tester,
  ) async {
    final t = await createFaTest(
      scenario: MockScenario.syncConflict,
      overrides: farmersOverrides(),
    );
    final padma = MockBackend.padmaId;
    final actions = t.read(faActionsProvider);
    await actions.updateFarmer(farmerId: padma, name: 'Padma Sri');
    await t.read(syncEngineProvider).syncNow();
    t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
    await actions.updateFarmer(farmerId: padma, name: 'Padma Sridevi');
    await _pump(tester, padma, test: t);
    expect(find.byType(ConflictCard), findsOneWidget);
    expect(find.text('Padma Sridevi'), findsWidgets);
    expect(find.textContaining(en.faSyncConflictWaiting), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
