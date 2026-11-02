// The device providers follow the data source: mocks on mock data, a clear
// UnimplementedError on the API (no generated photos or scripted GPS behind
// real data).

import 'package:fa/src/data/data.dart';
import 'package:fa/src/device/device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

void main() {
  ProviderContainer container(OrbitEnv env) {
    final c = ProviderContainer.test(overrides: faDataOverrides(env: env));
    return c;
  }

  test('mock data: the mock camera, GPS and network', () {
    final c = container(OrbitEnv.devMock);
    expect(c.read(photoCaptureProvider), isA<MockPhotoCapture>());
    expect(c.read(locationServiceProvider), isA<MockLocationService>());
    expect(c.read(connectivityProvider), isA<MockConnectivityService>());
    expect(mockBuildAllowed, isTrue); // tests build without --flavor
  });

  test('mock data: the network follows the offline scenario', () {
    final c = container(OrbitEnv.devMock);
    final net = c.read(connectivityProvider);
    expect(net.isOnline, isTrue);
    c.read(mockScenarioProvider.notifier).select(MockScenario.offline);
    expect(net.isOnline, isFalse);
    c.read(mockScenarioProvider.notifier).select(MockScenario.slowNetwork);
    expect(net.isOnline, isTrue);
  });

  test('the API: each provider names the plugin it still needs', () {
    final c = container(
      OrbitEnv.parse(
        flavor: 'dev',
        dataSource: 'api',
        apiBaseUrl: 'http://10.0.2.2:8080',
      ),
    );
    Matcher needs(String plugin) => throwsA(
      predicate(
        (Object? e) =>
            '$e'.contains('UnimplementedError') && '$e'.contains(plugin),
        'UnimplementedError naming $plugin',
      ),
    );
    expect(() => c.read(photoCaptureProvider), needs('image_picker'));
    expect(() => c.read(locationServiceProvider), needs('geolocator'));
    expect(() => c.read(connectivityProvider), needs('connectivity_plus'));
    expect(c.read(mockScenarioProvider), isNull);
  });
}
