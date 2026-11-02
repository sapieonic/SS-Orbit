/// Network state for the FA app: [ConnectivityService] and its provider.
///
/// The interface lives in `local/network.dart` (pure Dart, it moves to
/// packages/orbit_sync with the offline engine) and is re-exported here.
///
/// Mock data: a [MockConnectivityService], online unless the dev scenario is
/// offline (`isMockOffline` in `data/providers.dart`). API:
/// there is no platform implementation yet (connectivity_plus is not a
/// dependency), so the provider throws.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart'
    show isMockOffline, mockScenarioProvider, orbitEnvProvider;
import '../local/network.dart';

export '../local/network.dart'
    show ConnectivityService, MockConnectivityService;

/// The phone's network state. Override it in tests with a
/// [MockConnectivityService].
final connectivityProvider = Provider<ConnectivityService>((ref) {
  if (!ref.watch(orbitEnvProvider).usesMock) {
    throw UnimplementedError(
      'ConnectivityService on the API needs the connectivity_plus plugin (a '
      'platform implementation of ConnectivityService); only '
      'MockConnectivityService exists. See "Not done yet" in '
      'mobile/README.md.',
    );
  }
  final service = MockConnectivityService();
  ref.listen<bool>(
    mockScenarioProvider.select(isMockOffline),
    (_, offline) => service.setOnline(!offline),
    fireImmediately: true,
  );
  ref.onDispose(service.dispose);
  return service;
});
