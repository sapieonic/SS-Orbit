/// Helpers for the sign-in, blocked and Me screen tests.
library;

import 'package:fa/src/data/data.dart';
import 'package:fa/src/local/local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

/// Switches the mock (server and the phone's network) to [scenario].
void selectScenario(FaTest t, MockScenario scenario) =>
    t.read(mockScenarioProvider.notifier).select(scenario);

/// Leaves [count] records queued on the phone: goes offline, acknowledges
/// that many open alerts, and lets the engine's nudge pass. The phone stays
/// offline; select [MockScenario.normal] to push them.
Future<void> queueRecords(
  WidgetTester tester,
  FaTest t, {
  int count = 1,
}) async {
  selectScenario(t, MockScenario.offline);
  final open = [
    for (final a in t.territory.alerts)
      if (a.status == AlertStatus.open) a,
  ];
  expect(open.length, greaterThanOrEqualTo(count));
  for (final a in open.take(count)) {
    await t.read(faActionsProvider).ackAlert(a.id);
  }
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  expect(t.read(syncStateProvider).queuedCount, count);
}

/// Wrong PINs until the session moves on (locked out).
Future<void> lockOut(FaTest t) async {
  final session = t.read(sessionProvider.notifier);
  while (t.phase == SessionPhase.locked) {
    await session.unlock('0000');
  }
}

/// A 401 the data layer reports for a signed-in call.
const unauthorized = ApiError(
  code: ApiErrorCode.unauthorized,
  message: 'session ended',
  status: 401,
);

/// Checks on an [OrbitButton]'s enabled state.
abstract final class OrbitButtonFinder {
  static OrbitButton _button(WidgetTester tester, String label) =>
      tester.widget<OrbitButton>(orbitButton(label));

  /// The button labelled [label] can be tapped.
  static void expectEnabled(WidgetTester tester, String label) =>
      expect(_button(tester, label).onPressed, isNotNull);

  /// The button labelled [label] is disabled.
  static void expectDisabled(WidgetTester tester, String label) =>
      expect(_button(tester, label).onPressed, isNull);
}

/// Taps [pin] on the screen's [PinPad], digit by digit.
Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(
      find.descendant(of: find.byType(PinPad), matching: find.text(d)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
