/// Helpers the enrolment screen tests share.
library;

import 'package:fa/src/data/data.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/local.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../support/harness.dart';

/// [FaActions] without the engine nudge, so a test's writes stay queued (no
/// debounced sync timer left at the end of the test).
List<Override> quietActions() => [
  faActionsProvider.overrideWith(
    (ref) => FaActions(
      store: ref.watch(localStoreProvider),
      clock: ref.watch(clockProvider),
    ),
  ),
];

/// A test container signed in as Suresh with [quietActions].
Future<FaTest> enrolTest({
  MockScenario scenario = MockScenario.normal,
  Language language = Language.te,
}) => createFaTest(
  scenario: scenario,
  language: language,
  overrides: quietActions(),
);

/// The payloads of every outbox row of [type], oldest first.
List<T> queued<T extends CommandPayload>(FaTest t) => [
  for (final e in t.territory.outbox)
    if (e.command case final T c) c,
];

/// Enrols a new farmer straight through [FaActions] (as step 1 would,
/// offline), for tests that start at step 2 or 3. Returns the farmer ID.
Future<String> enrolDirect(
  FaTest t, {
  String phone = '9876500011',
  String name = 'Mahesh B',
}) async {
  final id = await t
      .read(faActionsProvider)
      .enrolFarmer(
        phone: phone,
        name: name,
        language: Language.te,
        villageId: MockBackend.kondapurId,
      );
  await t.container.read(territoryProvider.notifier).reload();
  return id;
}

/// Saves a typed 2 ac 4 gunta plot for [farmerId]. Returns the plot ID.
Future<String> plotDirect(FaTest t, String farmerId) async {
  final id = await t
      .read(faActionsProvider)
      .savePlot(
        farmerId: farmerId,
        label: 'Plot 1',
        pin: const LatLng(17.46, 78.36),
        areaAcres: 2.1,
        areaSource: AreaSource.typed,
      );
  await t.container.read(territoryProvider.notifier).reload();
  return id;
}
