import 'package:farmer/src/features/fas/fas_screen.dart';
import 'package:farmer/src/features/home/home_screen.dart';
import 'package:farmer/src/routing/router.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('Home -> Look for FAs -> back to Home in the real app', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);
    final router = container.read(routerProvider);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text(te.farmerHomeYourFa(name: 'సురేష్ కె')));
    await tester.pumpAndSettle();
    expect(currentPath(router), Routes.fas);
    expect(find.byType(FasScreen), findsOneWidget);
    expect(find.text(te.farmerFasYourFa), findsOneWidget);
    // Still inside the shell: the bottom bar stays.
    expect(find.byType(OrbitNavigationBar), findsOneWidget);

    await tester.tap(find.byIcon(OrbitIcons.back));
    await tester.pumpAndSettle();
    expect(currentPath(router), Routes.home);
    expect(find.byType(FasScreen), findsNothing);
    expect(find.text(te.farmerHomeGreeting(name: 'రవి కె')), findsOneWidget);
  });
}
