import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/home/home_screen.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

const _sureshPhone = '+919000000014';

void main() {
  Future<FakeContactLauncher> pumpHome(
    WidgetTester tester, {
    MockScenario scenario = MockScenario.normal,
    FakeContactLauncher? launcher,
  }) async {
    final container = await createTestContainer(scenario: scenario);
    final fake = launcher ?? FakeContactLauncher();
    await pumpRouted(
      tester,
      container: container,
      path: Routes.home,
      screen: const HomeScreen(),
      launcher: fake,
    );
    return fake;
  }

  group('HomeScreen', () {
    testWidgets('greets Ravi with his village, crop, area and plan', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text(te.farmerHomeGreeting(name: 'రవి కె')), findsOneWidget);
      // Kondapur · Cotton · 2.5 acres = 2 acres 20 guntas.
      expect(
        find.text(
          'కొండాపూర్ · పత్తి · ${te.farmerHomeArea(acres: 2, guntas: 20)}',
        ),
        findsOneWidget,
      );
      expect(find.text(te.labelFarmerPlan('free')), findsOneWidget);
      expect(find.text(te.farmerHomeYourFa(name: 'సురేష్ కె')), findsOneWidget);
      expect(findLabel(te.farmerHomeFaVerified), findsOneWidget);
    });

    testWidgets('shows the next visit with the day, date and slot', (
      tester,
    ) async {
      await pumpHome(tester);

      // Seeded visit is tomorrow, 2 Nov 2026, in the morning.
      final date = te.commonDateWeekday(date: DateTime.utc(2026, 11, 2));
      expect(find.text('${te.commonTomorrow} · $date'), findsOneWidget);
      expect(
        find.text(
          '${te.farmerHomeNextVisit} · ${te.labelPlannedSlot('morning')}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the unread advice count and opens the inbox', (
      tester,
    ) async {
      final container = await createTestContainer();
      final unread = await container
          .read(noticesRepositoryProvider)
          .getUnreadCount();
      expect(unread, greaterThan(0), reason: 'the seed has unread advice');
      final router = await pumpRouted(
        tester,
        container: container,
        path: Routes.home,
        screen: const HomeScreen(),
      );

      final row = find.text(te.farmerHomeUnread(count: unread));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Read out as a button (TalkBack).
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(row),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
      await scrollAndTap(tester, row);
      expect(currentPath(router), Routes.advisory);
    });

    testWidgets('the big Call button dials the FA', (tester) async {
      final launcher = await pumpHome(tester);

      await tester.tap(findLabel(te.commonCallName(name: 'సురేష్ కె')));
      await tester.pump();
      expect(launcher.calls, [_sureshPhone]);
    });

    testWidgets('says the number when the phone has no dialer', (tester) async {
      await pumpHome(tester, launcher: FakeContactLauncher(opens: false));

      await tester.tap(findLabel(te.commonCallName(name: 'సురేష్ కె')));
      await tester.pumpAndSettle();
      expect(
        find.text(te.farmerFasCallFailed(phone: _sureshPhone)),
        findsOneWidget,
      );
    });

    testWidgets('the FA card and Look for FAs open F3', (tester) async {
      final container = await createTestContainer();
      final router = await pumpRouted(
        tester,
        container: container,
        path: Routes.home,
        screen: const HomeScreen(),
      );

      await tester.tap(find.text(te.farmerHomeYourFa(name: 'సురేష్ కె')));
      await tester.pumpAndSettle();
      expect(currentPath(router), Routes.fas);

      router.go(Routes.home);
      await tester.pumpAndSettle();
      await tester.tap(findLabel(te.farmerHomeLookForFas));
      await tester.pumpAndSettle();
      expect(currentPath(router), Routes.fas);
    });

    testWidgets('Calendar and Pests tiles open their screens', (tester) async {
      final container = await createTestContainer();
      final router = await pumpRouted(
        tester,
        container: container,
        path: Routes.home,
        screen: const HomeScreen(),
      );

      final calendar = find.text(te.farmerHomeTileCalendar);
      await scrollAndTap(tester, calendar);
      expect(currentPath(router), Routes.calendar);

      router.go(Routes.home);
      await tester.pumpAndSettle();
      final pests = find.text(te.farmerHomeTilePests);
      await scrollAndTap(tester, pests);
      expect(currentPath(router), Routes.visits);
    });

    testWidgets('locked tiles show a padlock and a coming-soon sheet', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpHome(tester);

      expect(find.bySemanticsLabel(RegExp(te.commonComingSoon)), findsWidgets);
      semantics.dispose();
      final soil = find.text(te.farmerHomeTileSoilTest);
      await scrollAndTap(tester, soil);

      expect(find.text(te.farmerHomeLockedTitle), findsOneWidget);
      expect(find.text(te.farmerHomeLockedBody), findsOneWidget);
      expect(find.byType(ListenButton), findsWidgets);

      await tester.tap(findLabel(te.commonOk));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerHomeLockedTitle), findsNothing);
    });

    testWidgets('no FA yet: one card with the helpline', (tester) async {
      final launcher = await pumpHome(
        tester,
        scenario: MockScenario.noFaAssigned,
      );

      expect(find.text(te.farmerStateNoFaTitle), findsOneWidget);
      expect(find.byType(FaCard), findsNothing);
      await tester.tap(findLabel(te.farmerStateNoFaAction));
      await tester.pump();
      expect(launcher.calls, [helplinePhone]);
    });

    testWidgets('a farmer without plots is pointed to My farm', (tester) async {
      final container = await createNewFarmerContainer();
      final router = await pumpRouted(
        tester,
        container: container,
        path: Routes.home,
        screen: const HomeScreen(),
      );

      expect(find.text(te.farmerHomeGreeting(name: 'రాము')), findsOneWidget);
      final card = find.text(te.farmerHomeNoPlotTitle);
      await tester.scrollUntilVisible(card, 200);
      expect(find.text(te.farmerHomeNoPlotBody), findsOneWidget);
      await scrollAndTap(tester, findLabel(te.farmerNavFarm));
      expect(currentPath(router), Routes.farm);
    });

    testWidgets('offline with nothing saved: the offline card', (tester) async {
      await pumpHome(tester, scenario: MockScenario.offline);

      expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
      expect(find.text(te.farmerStateOfflineNothingSaved), findsOneWidget);
      expect(find.byType(FaCard), findsNothing);
    });

    testWidgets('server error: the error card, Try again loads Home', (
      tester,
    ) async {
      final container = await createTestContainer(
        scenario: MockScenario.serverError,
      );
      await pumpRouted(
        tester,
        container: container,
        path: Routes.home,
        screen: const HomeScreen(),
      );
      expect(find.text(te.farmerStateErrorTitle), findsOneWidget);

      container.read(mockScenarioProvider.notifier).select(MockScenario.normal);
      await tester.tap(findLabel(te.commonRetry));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerHomeGreeting(name: 'రవి కె')), findsOneWidget);
    });

    testWidgets('a refresh that fails offline keeps the saved Home', (
      tester,
    ) async {
      final container = await createTestContainer();
      await pumpRouted(
        tester,
        container: container,
        path: Routes.home,
        screen: const HomeScreen(),
      );

      container
          .read(mockScenarioProvider.notifier)
          .select(MockScenario.offline);
      await pullToRefresh(tester, find.byType(ListView));

      expect(find.byType(OrbitBanner), findsOneWidget);
      expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
      // Loaded at 10:30 IST (the test clock).
      expect(
        find.text(
          te.farmerStateOfflineBody(time: DateTime.utc(2026, 11, 1, 10, 30)),
        ),
        findsOneWidget,
      );
      expect(find.text(te.farmerHomeGreeting(name: 'రవి కె')), findsOneWidget);
      expect(find.byType(FaCard), findsOneWidget);

      // Back online: Try again clears the banner.
      container.read(mockScenarioProvider.notifier).select(MockScenario.normal);
      await tester.tap(findLabel(te.commonRetry));
      await tester.pumpAndSettle();
      expect(find.byType(OrbitBanner), findsNothing);
    });

    testWidgets('renders in English', (tester) async {
      final container = await createTestContainer();
      await pumpRouted(
        tester,
        container: container,
        path: Routes.home,
        screen: const HomeScreen(),
        locale: const Locale('en'),
      );

      expect(find.text('Hello, Ravi K'), findsOneWidget);
      expect(find.text('Your FA: Suresh K'), findsOneWidget);
      expect(findLabel(en.commonCallName(name: 'Suresh K')), findsOneWidget);
      expect(
        find.text('Kondapur · Cotton · 2 acres 20 guntas'),
        findsOneWidget,
      );
    });
  });

  group('HomeScreen layout', () {
    screenLayoutTest('Home', () => const HomeScreen());
    screenLayoutTest(
      'Home without an FA',
      () => const HomeScreen(),
      scenario: MockScenario.noFaAssigned,
    );
    screenLayoutTest(
      'Home offline',
      () => const HomeScreen(),
      scenario: MockScenario.offline,
    );

    for (final scale in textScales) {
      testWidgets('coming-soon sheet fits 360x640 at text scale $scale', (
        tester,
      ) async {
        final container = await createTestContainer();
        await pumpRouted(
          tester,
          container: container,
          path: Routes.home,
          screen: const HomeScreen(),
          textScale: scale,
        );
        final premium = find.text(te.farmerHomeTilePremium);
        await scrollAndTap(tester, premium);
        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
      });
    }
  });
}
