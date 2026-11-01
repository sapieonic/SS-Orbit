import 'dart:math' as math;

import 'package:farmer/src/data/data.dart';
import 'package:orbit_core/orbit_core.dart';

import 'repository_contract.dart';

/// Runs the repository contract against the mock, with no latency and a
/// fixed clock (1 Nov 2026, 10:30 IST).
void main() {
  runRepositoryContract('mock', () async {
    final clock = FixedClock(DateTime.utc(2026, 11, 1, 5));
    final backend = MockBackend(
      clock: clock,
      latency: Duration.zero,
      random: math.Random(7),
    );
    final store = InMemorySessionStore();
    final hook = AuthFailureHook();
    return ContractHarness(
      repos: backend.repositories(store, authFailures: hook),
      store: store,
      authFailures: hook,
      fixture: ContractFixture.devSeed(random: math.Random(11)),
      clock: clock,
      closeCallbackAsFa: backend.simulateFaClosesCallback,
    );
  });
}
