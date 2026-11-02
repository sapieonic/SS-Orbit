import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'src/app.dart';
import 'src/data/data.dart';
import 'src/local/local.dart';

/// Entry point for every flavour.
///
/// Run: `flutter run --flavor dev` (mock data). Data source and mock options
/// come from dart-defines: `ORBIT_DATA_SOURCE` (`mock` | `api`),
/// `ORBIT_MOCK_SCENARIO`, `ORBIT_MOCK_LATENCY_MS`, `ORBIT_API_BASE_URL`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  OrbitFonts.registerLicenses();
  runApp(
    ProviderScope(
      overrides: [
        ...faDataOverrides(env: orbitEnvFromBuild()),
        // The session pushes and wipes local data through the engine.
        ...localEngineOverrides(),
      ],
      retry: orbitRetry,
      child: const FaApp(),
    ),
  );
}
