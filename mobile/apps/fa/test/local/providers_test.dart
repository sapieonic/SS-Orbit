import 'package:fa/src/data/data.dart';
import 'package:fa/src/local/local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import 'support/fakes.dart';
import 'support/fixture.dart';

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('engine providers', () {
    late FakeServer server;
    late MockConnectivityService net;
    late ProviderContainer container;

    setUp(() {
      server = FakeServer(fixtureSnapshot());
      net = MockConnectivityService();
      container = ProviderContainer(
        overrides: [
          ...faDataOverrides(env: OrbitEnv.devMock),
          ...localEngineOverrides(),
          clockProvider.overrideWithValue(fixtureClock()),
          syncRepositoryProvider.overrideWithValue(server),
          visitPhotosRepositoryProvider.overrideWithValue(FakeVisitPhotos()),
          photoUploaderProvider.overrideWithValue(FakeUploader()),
          connectivityProvider.overrideWithValue(net),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await net.dispose();
    });

    test(
      'territory, actions, sync state and pending IDs work together',
      () async {
        final sub = container.listen(territoryProvider, (_, _) {});
        final stateSub = container.listen(syncStateProvider, (_, _) {});
        expect(
          (await container.read(territoryProvider.future)).hasData,
          isFalse,
        );

        await container.read(syncEngineProvider).syncNow();
        await _settle();
        var t = container.read(territoryProvider).value!;
        expect(t.hasData, isTrue);
        expect(t.farmerCount, 5);

        await container.read(faActionsProvider).ackAlert(alertNote);
        await _settle();
        t = container.read(territoryProvider).value!;
        expect(t.alert(alertNote)!.status, AlertStatus.acknowledged);
        expect(container.read(pendingEntityIdsProvider), contains(alertNote));
        expect(container.read(syncStateProvider).queuedCount, 1);

        final guard = container.read(localDataGuardProvider);
        expect(guard, isA<EngineLocalDataGuard>());
        expect(await guard.pendingCount(), 1);
        expect(await guard.pushPending(), isTrue);
        await _settle();
        expect(container.read(syncStateProvider).queuedCount, 0);
        expect(container.read(pendingEntityIdsProvider), isEmpty);

        sub.close();
        stateSub.close();
      },
    );
  });

  test('mock connectivity follows the offline scenario', () {
    final container = ProviderContainer(
      overrides: faDataOverrides(env: OrbitEnv.devMock),
    );
    addTearDown(container.dispose);
    final net = container.read(connectivityProvider);
    expect(net.isOnline, isTrue);
    container.read(mockScenarioProvider.notifier).select(MockScenario.offline);
    expect(net.isOnline, isFalse);
    container.read(mockScenarioProvider.notifier).select(MockScenario.normal);
    expect(net.isOnline, isTrue);
  });
}
