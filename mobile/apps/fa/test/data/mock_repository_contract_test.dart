import 'dart:math' as math;

import 'package:fa/src/data/data.dart';
import 'package:orbit_core/orbit_core.dart';

import '../support/mock_support.dart';
import 'repository_contract.dart';

/// Runs the repository contract against the mock, with no latency and a
/// fixed clock (2 Nov 2026, 10:30 IST).
void main() {
  runRepositoryContract('mock', () async {
    final clock = FixedClock(mockTestNow);
    final backend = MockBackend(
      clock: clock,
      latency: Duration.zero,
      random: math.Random(7),
    );
    final store = InMemorySessionStore(random: math.Random(3));
    final hook = AuthFailureHook();
    return ContractHarness(
      repos: backend.repositories(store, authFailures: hook),
      store: store,
      authFailures: hook,
      fixture: ContractFixture.mock(random: math.Random(11)),
      clock: clock,
    );
  });
}
