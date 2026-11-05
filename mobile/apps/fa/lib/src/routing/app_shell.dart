import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../local/local.dart';
import 'routes.dart';

/// The signed-in frame: the four tabs (Farmers, Calendar, Enrol, Alerts),
/// each keeping its own page stack, and the bottom bar.
///
/// * The bar shows on the tab roots in [AppRoutes.barPaths] only; Farmer
///   360, the enrolment steps and plan visit fill the screen, as in the
///   designs, and their back arrow returns to the tab root.
/// * The Alerts tab's badge counts the open alerts in the territory on the
///   phone.
/// * Android back at the root of another tab goes to Farmers; back at the
///   root of Farmers leaves the app.
/// * The Enrol tab always opens a fresh step 1 ([enrolStartProvider]), never
///   the last enrolment's later steps or its "Enrolled" state.
class AppShell extends ConsumerWidget {
  /// Creates the shell.
  const AppShell({super.key, required this.shell, required this.location});

  /// The tabs' navigators.
  final StatefulNavigationShell shell;

  /// The current path, which decides whether the bar shows.
  final String location;

  /// Index of each tab, in bar order.
  static const farmersTab = 0, calendarTab = 1, enrolTab = 2, alertsTab = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final open = ref.watch(openAlertCountProvider);
    final showBar = AppRoutes.barPaths.contains(location);
    // Reached only once the tab's own pages can't go back any further.
    return PopScope(
      canPop: shell.currentIndex == farmersTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(farmersTab);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: showBar
            ? OrbitNavigationBar(
                selectedIndex: shell.currentIndex,
                // Tapping the current tab again goes back to its first page;
                // Enrol always starts over.
                onDestinationSelected: (index) {
                  final enrol = index == enrolTab;
                  if (enrol) ref.read(enrolStartProvider.notifier).startOver();
                  shell.goBranch(
                    index,
                    initialLocation: enrol || index == shell.currentIndex,
                  );
                },
                destinations: [
                  OrbitNavigationDestination(
                    icon: OrbitIcons.people,
                    label: l10n.faNavFarmers,
                  ),
                  OrbitNavigationDestination(
                    icon: OrbitIcons.calendar,
                    label: l10n.faNavCalendar,
                  ),
                  OrbitNavigationDestination(
                    icon: OrbitIcons.enrol,
                    label: l10n.faNavEnrol,
                  ),
                  OrbitNavigationDestination(
                    icon: OrbitIcons.bell,
                    label: l10n.faNavAlerts,
                    badge: open > 0 ? '$open' : null,
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

/// Open alerts in the territory on the phone (the Alerts tab's badge); 0
/// until the territory has loaded.
final openAlertCountProvider = Provider<int>((ref) {
  return ref.watch(territoryProvider).value?.openAlertCount ?? 0;
});

/// Counts the taps on the Enrol tab. The router keys step 1 with it, so
/// each tap opens a new, empty A4a.
final enrolStartProvider = NotifierProvider<EnrolStart, int>(EnrolStart.new);

/// Holds the [enrolStartProvider] count.
class EnrolStart extends Notifier<int> {
  @override
  int build() => 0;

  /// The FA tapped Enrol: the next step 1 is a new one.
  void startOver() => state++;
}
