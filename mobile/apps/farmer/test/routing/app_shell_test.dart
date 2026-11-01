import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/fas/fas_screen.dart';
import 'package:farmer/src/features/home/home_screen.dart';
import 'package:farmer/src/features/visits/advice_screen.dart';
import 'package:farmer/src/routing/router.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/voice.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';
import 'package:orbit_voice/orbit_voice.dart';

import '../support/harness.dart';

/// A bottom-bar tab by its label.
Finder _tab(String label) => find.descendant(
  of: find.byType(OrbitNavigationBar),
  matching: find.textContaining(label),
);

/// The Listen button of the screen whose prompt is [voiceKey].
Finder _listen(String voiceKey) => find.byWidgetPredicate(
  (w) => w is ScreenListenButton && w.voiceKey == voiceKey,
);

void main() {
  late FakeVoicePlayer player;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    player = FakeVoicePlayer();
    container = await createTestContainer(voice: player);
    await pumpFarmerApp(tester, container: container);
    router = container.read(routerProvider);
  }

  Future<void> play(WidgetTester tester, String voiceKey) async {
    await tester.tap(_listen(voiceKey));
    await tester.pump();
    expect(player.state.value, VoicePlaying(voiceKey));
  }

  /// Android back, as the system sends it.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  group('voice stops when the farmer leaves the screen', () {
    testWidgets('switching tabs', (tester) async {
      await pumpApp(tester);
      await play(tester, VoiceKeys.farmerHomeVoiceHelp);

      await tester.tap(_tab(te.farmerNavVisits));
      await tester.pumpAndSettle();
      expect(player.state.value, const VoiceIdle());

      await play(tester, VoiceKeys.farmerVisitsVoiceHelp);
      // A link to another tab (Home's cards do this) is a tab switch too.
      router.go(Routes.advisory);
      await tester.pumpAndSettle();
      expect(player.state.value, const VoiceIdle());
    });

    testWidgets('opening a screen, and going back from it', (tester) async {
      await pumpApp(tester);
      await play(tester, VoiceKeys.farmerHomeVoiceHelp);

      router.go(Routes.fas);
      await tester.pumpAndSettle();
      expect(find.byType(FasScreen), findsOneWidget);
      expect(player.state.value, const VoiceIdle());

      await play(tester, VoiceKeys.farmerFasVoiceHelp);
      await systemBack(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(player.state.value, const VoiceIdle());
    });

    testWidgets('a failure shown on a Listen button is cleared too', (
      tester,
    ) async {
      await pumpApp(tester);
      player.fail(VoiceKeys.farmerHomeVoiceHelp);
      await tester.tap(_tab(te.farmerNavFarm));
      await tester.pumpAndSettle();
      expect(player.state.value, const VoiceIdle());
    });
  });

  group('Android back', () {
    /// Records the app asking Android to close it.
    List<String> watchExit(WidgetTester tester) {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return calls;
    }

    testWidgets('at the root of another tab goes to Home, then exits', (
      tester,
    ) async {
      await pumpApp(tester);
      final calls = watchExit(tester);

      for (final (tab, path) in [
        (te.farmerNavVisits, Routes.visits),
        (te.farmerNavAdvisory, Routes.advisory),
        (te.farmerNavFarm, Routes.farm),
      ]) {
        await tester.tap(_tab(tab));
        await tester.pumpAndSettle();
        expect(currentPath(router), path);

        await systemBack(tester);
        expect(currentPath(router), Routes.home, reason: 'back from $path');
        expect(calls, isNot(contains('SystemNavigator.pop')));
      }

      await systemBack(tester);
      expect(calls, contains('SystemNavigator.pop'));
    });

    testWidgets('inside a tab goes back within it first', (tester) async {
      await pumpApp(tester);
      final visits = await container
          .read(visitsRepositoryProvider)
          .listVisits();
      router.go(Routes.advice(visits.items.first.id, 0));
      await tester.pumpAndSettle();
      expect(find.byType(AdviceScreen), findsOneWidget);

      await systemBack(tester);
      expect(currentPath(router), Routes.visits);
      await systemBack(tester);
      expect(currentPath(router), Routes.home);
    });
  });
}
