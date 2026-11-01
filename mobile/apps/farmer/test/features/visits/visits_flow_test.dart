import 'package:farmer/src/features/advisory/advisory_screen.dart';
import 'package:farmer/src/features/advisory/notice_screen.dart';
import 'package:farmer/src/features/visits/advice_screen.dart';
import 'package:farmer/src/features/visits/visits_screen.dart';
import 'package:farmer/src/routing/router.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

Finder _tab(String label) => find.descendant(
  of: find.byType(OrbitNavigationBar),
  matching: find.textContaining(label),
);

void main() {
  testWidgets('Visits tab -> issue -> advice -> back', (tester) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);

    await tester.tap(_tab('సందర్శనలు'));
    await tester.pumpAndSettle();
    expect(find.byType(VisitsScreen), findsOneWidget);
    expect(currentPath(container.read(routerProvider)), Routes.visits);

    await tester.tap(find.text('గులాబీ రంగు పురుగు'));
    await tester.pumpAndSettle();
    expect(find.byType(AdviceScreen), findsOneWidget);
    expect(
      currentPath(container.read(routerProvider)),
      Routes.advice('4ab75e76-0167-5a52-8020-cdc3c833f2dc', 0),
    );
    expect(find.text('ఈ మందు కొనండి'), findsOneWidget);

    await tester.tap(find.byIcon(OrbitIcons.back));
    await tester.pumpAndSettle();
    expect(find.byType(AdviceScreen), findsNothing);
    expect(find.byType(VisitsScreen), findsOneWidget);
    expect(currentPath(container.read(routerProvider)), Routes.visits);
  });

  testWidgets('opening a notice lowers the Advisory badge', (tester) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);
    expect(_tab('3'), findsOneWidget);

    await tester.tap(_tab('సలహాలు'));
    await tester.pumpAndSettle();
    expect(find.byType(AdvisoryScreen), findsOneWidget);

    await tester.tap(find.text('గులాబీ రంగు పురుగు జాగ్రత్త'));
    await tester.pumpAndSettle();
    expect(find.byType(NoticeScreen), findsOneWidget);
    expect(_tab('2'), findsOneWidget);

    await tester.tap(find.byIcon(OrbitIcons.back));
    await tester.pumpAndSettle();
    expect(find.byType(AdvisoryScreen), findsOneWidget);
    expect(find.text('2 కొత్తవి'), findsOneWidget);
  });
}
