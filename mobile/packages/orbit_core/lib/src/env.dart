import 'package:meta/meta.dart';

/// Build flavour. Android product flavours and iOS schemes use these names.
enum Flavor {
  /// Local development against the dev backend or mock data.
  dev,

  /// Pre-production backend.
  staging,

  /// Production backend.
  prod,
}

/// Where the app's repositories get their data.
enum DataSource {
  /// In-memory mock data (`Mock*Repository`). Dev flavour only.
  mock,

  /// The Orbit HTTP API (`Api*Repository`).
  api,
}

/// Runtime environment: flavour, API base URL and data source.
///
/// Built once at app start from plain strings, so it stays free of Flutter:
///
/// ```dart
/// final env = OrbitEnv.parse(
///   flavor: appFlavor, // package:flutter/services.dart
///   dataSource: const String.fromEnvironment('ORBIT_DATA_SOURCE'),
///   apiBaseUrl: const String.fromEnvironment('ORBIT_API_BASE_URL'),
/// );
/// ```
@immutable
final class OrbitEnv {
  /// Creates an environment. Prefer [OrbitEnv.parse], which applies the rules.
  const OrbitEnv({
    required this.flavor,
    required this.dataSource,
    required this.apiBaseUrl,
  });

  /// Parses the flavour, data source and optional base URL override.
  ///
  /// * [flavor]: `dev`, `staging` or `prod` (case-insensitive). Null or empty
  ///   means `dev` (unit tests, `flutter run` without `--flavor`).
  /// * [dataSource]: `mock` or `api`. Null or empty picks the default: mock in
  ///   dev, api in staging and prod.
  /// * [apiBaseUrl]: overrides [defaultApiBaseUrl], e.g.
  ///   `http://localhost:8080` for the iOS simulator. Null or empty keeps the
  ///   default.
  ///
  /// Throws [FormatException] for an unknown value, and [StateError] when
  /// mock data is asked for in staging or prod.
  factory OrbitEnv.parse({
    String? flavor,
    String? dataSource,
    String? apiBaseUrl,
  }) {
    final f = _parseFlavor(flavor);
    final source = switch (dataSource?.trim().toLowerCase()) {
      null || '' => f == Flavor.dev ? DataSource.mock : DataSource.api,
      'mock' => DataSource.mock,
      'api' => DataSource.api,
      final other => throw FormatException(
        'ORBIT_DATA_SOURCE must be "mock" or "api", got "$other"',
      ),
    };
    if (source == DataSource.mock && f != Flavor.dev) {
      throw StateError(
        'Mock data is dev-only; the ${f.name} flavour must use '
        'ORBIT_DATA_SOURCE=api.',
      );
    }
    final override = apiBaseUrl?.trim() ?? '';
    final base = override.isEmpty ? defaultApiBaseUrl(f) : override;
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('ORBIT_API_BASE_URL is not an absolute URL', base);
    }
    return OrbitEnv(
      flavor: f,
      dataSource: source,
      apiBaseUrl: base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base,
    );
  }

  /// Dev flavour with mock data: what unit and widget tests use.
  static const devMock = OrbitEnv(
    flavor: Flavor.dev,
    dataSource: DataSource.mock,
    apiBaseUrl: devApiBaseUrl,
  );

  /// The dev backend as seen from the Android emulator (host's port 8080).
  static const devApiBaseUrl = 'http://10.0.2.2:8080';

  /// TBD: placeholder until infra gives the staging host. `.invalid` never
  /// resolves, so a build that ships with it fails loudly.
  static const stagingApiBaseUrl = 'https://api.staging.orbit.invalid';

  /// TBD: placeholder until infra gives the production host.
  static const prodApiBaseUrl = 'https://api.orbit.invalid';

  /// The base URL for [flavor] when no override is given.
  static String defaultApiBaseUrl(Flavor flavor) => switch (flavor) {
    Flavor.dev => devApiBaseUrl,
    Flavor.staging => stagingApiBaseUrl,
    Flavor.prod => prodApiBaseUrl,
  };

  /// The build flavour.
  final Flavor flavor;

  /// Mock or API repositories.
  final DataSource dataSource;

  /// API root without a trailing slash, e.g. `http://10.0.2.2:8080`.
  final String apiBaseUrl;

  /// True for the dev flavour (dev tools such as the mock scenario switch).
  bool get isDev => flavor == Flavor.dev;

  /// True when repositories serve mock data.
  bool get usesMock => dataSource == DataSource.mock;

  static Flavor _parseFlavor(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        null || '' || 'dev' => Flavor.dev,
        'staging' => Flavor.staging,
        'prod' => Flavor.prod,
        final other => throw FormatException(
          'Unknown flavour "$other"; expected dev, staging or prod',
        ),
      };

  @override
  bool operator ==(Object other) =>
      other is OrbitEnv &&
      other.flavor == flavor &&
      other.dataSource == dataSource &&
      other.apiBaseUrl == apiBaseUrl;

  @override
  int get hashCode => Object.hash(flavor, dataSource, apiBaseUrl);

  @override
  String toString() =>
      'OrbitEnv(${flavor.name}, ${dataSource.name}, $apiBaseUrl)';
}
