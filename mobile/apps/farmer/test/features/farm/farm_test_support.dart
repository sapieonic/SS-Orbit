import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/farm/add_plot_screen.dart';
import 'package:farmer/src/features/farm/close_season_screen.dart';
import 'package:farmer/src/features/farm/consents_screen.dart';
import 'package:farmer/src/features/farm/farm_screen.dart';
import 'package:farmer/src/features/farm/start_season_screen.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

/// Ravi's seeded active season (cotton, kharif-2026, sown 1 Jul 2026).
const raviSeasonId = '832fd852-3826-5dbe-b65a-de1ef9fbcc28';

/// Ravi's seeded plot ("Plot 1", 2.5 acres).
const raviPlotId = '99d707d8-1d63-59ea-bf0e-ada3da7dd10d';

/// Kondapur's centroid in the mock seed: the pin for a new plot.
const kondapurPin = LatLng(17.46, 78.357);

/// Pumps the My farm routes (same paths as the app router) starting at
/// [location], so screens can push and pop. Home and Look for FAs are stubs.
/// Returns the router, for `currentPath`.
Future<GoRouter> pumpFarmRoutes(
  WidgetTester tester, {
  required ProviderContainer container,
  String location = Routes.farm,
  Locale locale = const Locale('te'),
  double textScale = 1.0,
}) => pumpRouter(
  tester,
  container: container,
  location: location,
  locale: locale,
  textScale: textScale,
  routes: [
    GoRoute(
      path: Routes.farm,
      builder: (_, _) => const FarmScreen(),
      routes: [
        GoRoute(path: 'consents', builder: (_, _) => const ConsentsScreen()),
        GoRoute(path: 'plots/new', builder: (_, _) => const AddPlotScreen()),
        GoRoute(
          path: 'plots/:plotId/season',
          builder: (_, state) =>
              StartSeasonScreen(plotId: state.pathParameters['plotId']!),
        ),
        GoRoute(
          path: 'seasons/:seasonId/close',
          builder: (_, state) =>
              CloseSeasonScreen(seasonId: state.pathParameters['seasonId']!),
        ),
      ],
    ),
    GoRoute(
      path: Routes.home,
      builder: (_, _) => stubScreen(Routes.home),
      routes: [GoRoute(path: 'fas', builder: (_, _) => stubScreen(Routes.fas))],
    ),
  ],
);

/// The screen title in the [ScreenHeader] (the bottom bar may repeat it).
Finder headerTitle(String title) => find.widgetWithText(ScreenHeader, title);
