import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/visits/visit_widgets.dart';
import 'package:farmer/src/features/visits/visits_providers.dart';
import 'package:farmer/src/features/visits/visits_screen.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

void main() {
  group('VisitsScreen', () {
    testWidgets('shows the next visit and visits grouped by plot', (
      tester,
    ) async {
      final container = await createTestContainer();
      await pumpScreen(tester, const VisitsScreen(), container: container);

      expect(find.text('సందర్శనలు'), findsOneWidget);
      // Next visit: tomorrow (test "today" is Sun 1 Nov), morning, Suresh.
      expect(find.text('FA వచ్చే రోజు'), findsOneWidget);
      expect(find.textContaining('రేపు · '), findsOneWidget);
      expect(find.text('ఉదయం'), findsOneWidget);
      expect(
        find.text('సురేష్ కె గారు వచ్చే ముందు కాల్ చేస్తారు'),
        findsOneWidget,
      );
      // One plot group, named like My farm ("Plot 1" from the server reads
      // "పొలం 1") plus the crop.
      expect(find.widgetWithText(SectionHeader, 'పొలం 1 · పత్తి'), findsOne);
      // Newest visit first, with its stage, issue and product advice. The
      // Telugu stage name already ends in దశ: it is not added twice.
      expect(find.text('12 అక్టో · సురేష్ కె'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(VisitCard).first,
          matching: find.text('కాయ దశ'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('దశ దశ'), findsNothing);
      expect(find.text('గులాబీ రంగు పురుగు'), findsOneWidget);
      expect(find.text('Pink bollworm'), findsOneWidget);
      expect(find.text('మందు: శాంపిల్ 5 SG'), findsOneWidget);
      expect(find.text('ఎకరానికి 200 లీ. నీటిలో 80 గ్రా.'), findsOneWidget);
      expect(find.byType(SeverityPill), findsWidgets);

      // Salt-only and pending advice further down.
      await tester.scrollUntilVisible(
        find.text('షణ్ముఖ మందు లేదు, దుకాణంలో అడగండి'),
        200,
      );
      await tester.scrollUntilVisible(
        find.text('సలహా ఇంకా రాలేదు. మీ FA తర్వాత చెబుతారు.'),
        200,
      );
      await tester.scrollUntilVisible(
        find.text('సమస్యలు ఏమీ కనిపించలేదు'),
        200,
      );
    });

    testWidgets('loads the next page when the farmer scrolls to the end', (
      tester,
    ) async {
      final container = await createTestContainer(
        overrides: [visitsPageSizeProvider.overrideWithValue(2)],
      );
      await pumpScreen(tester, const VisitsScreen(), container: container);
      expect(find.byType(VisitCard), findsWidgets);

      // The oldest visit (5th, on page 3) shows once the farmer scrolls down.
      await tester.scrollUntilVisible(
        find.text('సమస్యలు ఏమీ కనిపించలేదు'),
        300,
      );
      await tester.pumpAndSettle();
      final state = container.read(visitsControllerProvider).requireValue;
      expect(state.visits.items, hasLength(5));
      expect(state.visits.hasMore, isFalse);
    });

    testWidgets('no visits: one card with Call FA', (tester) async {
      final container = await createTestContainer(
        scenario: MockScenario.noVisits,
      );
      await pumpScreen(tester, const VisitsScreen(), container: container);

      expect(find.text('ఇంకా సందర్శనలు లేవు'), findsOneWidget);
      expect(find.text('మీ FA మొదటి సందర్శన ప్లాన్ చేస్తారు.'), findsOneWidget);
      expect(
        find.textContaining('సురేష్ కె గారికి కాల్ చేయండి'),
        findsOneWidget,
      );
      expect(find.byType(NextVisitCard), findsNothing);
      expect(find.byType(VisitCard), findsNothing);
    });

    testWidgets('no visits and no FA: the card calls the helpline', (
      tester,
    ) async {
      final backend = testBackend();
      final container = await createTestContainer(
        backend: backend,
        scenario: MockScenario.noVisits,
      );
      // No FA on Home, but the visits list still says "no visits".
      backend.scenario = MockScenario.noFaAssigned;
      await container.read(farmerHomeProvider.future);
      backend.scenario = MockScenario.noVisits;
      await pumpScreen(tester, const VisitsScreen(), container: container);

      expect(find.text('ఇంకా సందర్శనలు లేవు'), findsOneWidget);
      expect(find.textContaining('సహాయ కేంద్రానికి కాల్'), findsOneWidget);
    });

    testWidgets('offline: one card, Try again reloads', (tester) async {
      final backend = testBackend();
      final container = await createTestContainer(
        backend: backend,
        scenario: MockScenario.offline,
      );
      await pumpScreen(tester, const VisitsScreen(), container: container);

      expect(find.text('ఇంటర్నెట్ లేదు'), findsOneWidget);
      expect(find.byType(VisitCard), findsNothing);

      backend.scenario = MockScenario.normal;
      await tester.tap(find.byType(OrbitButton));
      await tester.pumpAndSettle();
      expect(find.byType(VisitCard), findsWidgets);
    });

    testWidgets('server error shows the error card', (tester) async {
      final container = await createTestContainer(
        scenario: MockScenario.serverError,
      );
      await pumpScreen(tester, const VisitsScreen(), container: container);
      expect(find.text('ఏదో తప్పు జరిగింది'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads the list', (tester) async {
      final backend = testBackend();
      final container = await createTestContainer(backend: backend);
      await pumpScreen(tester, const VisitsScreen(), container: container);
      expect(find.byType(VisitCard), findsWidgets);

      backend.scenario = MockScenario.noVisits;
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('ఇంకా సందర్శనలు లేవు'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the list and says why', (tester) async {
      final backend = testBackend();
      final container = await createTestContainer(backend: backend);
      await pumpScreen(tester, const VisitsScreen(), container: container);

      backend.scenario = MockScenario.offline;
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(VisitCard), findsWidgets);
      expect(
        find.widgetWithText(SnackBar, te.errorNetwork),
        findsOneWidget,
        reason: 'says it is offline',
      );
    });

    testWidgets('renders in English', (tester) async {
      final container = await createTestContainer(language: Language.en);
      await pumpScreen(
        tester,
        const VisitsScreen(),
        container: container,
        locale: const Locale('en'),
      );
      expect(find.text('My visits'), findsOneWidget);
      expect(find.text('Next visit'), findsOneWidget);
      expect(find.text('Pink bollworm'), findsOneWidget);
      expect(find.text('గులాబీ రంగు పురుగు'), findsOneWidget);
      expect(find.text('Product: Sample 5 SG'), findsOneWidget);
      expect(find.text('Suresh K will call before coming'), findsOneWidget);
    });
  });

  group('VisitsController paging', () {
    test('pages with the cursor until the last page', () async {
      final container = await createTestContainer(
        overrides: [visitsPageSizeProvider.overrideWithValue(2)],
      );
      final first = await container.read(visitsControllerProvider.future);
      expect(first.visits.items, hasLength(2));
      expect(first.visits.hasMore, isTrue);
      expect(first.nextVisit, isNotNull);

      final controller = container.read(visitsControllerProvider.notifier);
      await controller.loadMore();
      expect(
        container.read(visitsControllerProvider).requireValue.visits.items,
        hasLength(4),
      );
      await controller.loadMore();
      final last = container.read(visitsControllerProvider).requireValue;
      expect(last.visits.items, hasLength(5));
      expect(last.visits.hasMore, isFalse);
      // Newest first, no duplicates.
      final ids = last.visits.items.map((v) => v.id).toList();
      expect(ids.toSet(), hasLength(5));
      final times = last.visits.items.map((v) => v.visitedAt).toList();
      expect(times, [...times]..sort((a, b) => b.compareTo(a)));

      // Nothing more to load: no request, no change.
      await controller.loadMore();
      expect(
        container.read(visitsControllerProvider).requireValue.visits.items,
        hasLength(5),
      );
    });

    test('another farmer signing in never sees the old visits', () async {
      final container = await createTestContainer();
      final ravi = await container.read(visitsControllerProvider.future);
      expect(ravi.visits.items, hasLength(5));

      final session = container.read(sessionProvider.notifier);
      await session.signOut();
      await session.requestOtp('9000000102');
      await session.verifyOtp(devOtp);
      final venkatesh = await container.read(visitsControllerProvider.future);
      expect(
        venkatesh.visits.items.map((v) => v.id),
        isNot(contains(ravi.visits.items.first.id)),
      );
    });

    test('a failed page shows on the footer and can be retried', () async {
      final backend = testBackend();
      final container = await createTestContainer(
        backend: backend,
        overrides: [visitsPageSizeProvider.overrideWithValue(2)],
      );
      await container.read(visitsControllerProvider.future);
      final controller = container.read(visitsControllerProvider.notifier);

      backend.scenario = MockScenario.offline;
      await controller.loadMore();
      var visits = container.read(visitsControllerProvider).requireValue.visits;
      expect(visits.items, hasLength(2));
      expect(visits.loadMoreError, isA<ApiError>());

      backend.scenario = MockScenario.normal;
      await controller.loadMore();
      visits = container.read(visitsControllerProvider).requireValue.visits;
      expect(visits.items, hasLength(4));
      expect(visits.loadMoreError, isNull);
    });
  });

  screenLayoutTest('My visits', () => const VisitsScreen());
  screenLayoutTest(
    'My visits with no visits',
    () => const VisitsScreen(),
    scenario: MockScenario.noVisits,
  );
  screenLayoutTest(
    'My visits offline',
    () => const VisitsScreen(),
    scenario: MockScenario.offline,
  );
}
