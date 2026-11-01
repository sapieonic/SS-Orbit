import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../shared/async_view.dart';
import '../shared/farmer_data.dart';
import '../shared/voice.dart';
import 'resume_refresh.dart';

/// The signed-in frame: the four tabs (Home, Visits, Advisory, My farm) with
/// the bottom bar. Wallet joins in Phase 2.
///
/// * Coming back to the foreground refreshes what may have changed meanwhile
///   ([ResumeRefresh]).
/// * Switching tabs stops the voice playing on the tab left (one task per
///   screen; the router stops it on every other route change).
/// * Android back at the root of Visits, Advisory or My farm goes to Home;
///   back at the root of Home leaves the app.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Created now, so the first resume within minutes of opening the app
    // doesn't reload what was just loaded.
    final refresh = ref.read(resumeRefreshProvider);
    _lifecycle = AppLifecycleListener(onResume: refresh.onResume);
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // However the tab changed (bottom bar, a link to another tab), the
    // screen left behind stays alive in the stack: stop its voice.
    if (oldWidget.shell.currentIndex != widget.shell.currentIndex) {
      stopVoice(ref.read(voicePlayerProvider));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final l10n = context.l10n;
    // Keep Home loaded while signed in, whichever tab is open: its refetch
    // (another farmer, a dev-menu switch) re-checks the account, and resume
    // checks how old it is.
    ref.listen(farmerHomeProvider, (_, _) {});
    final unread = ref.watch(unreadNoticesCountProvider).fresh.value ?? 0;
    // Reached only once the tab's own screens can't go back any further.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: OrbitNavigationBar(
          selectedIndex: shell.currentIndex,
          // Tapping the current tab again goes back to its first screen.
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          destinations: [
            OrbitNavigationDestination(
              icon: OrbitIcons.home,
              label: l10n.farmerNavHome,
            ),
            OrbitNavigationDestination(
              icon: OrbitIcons.visit,
              label: l10n.farmerNavVisits,
            ),
            OrbitNavigationDestination(
              icon: OrbitIcons.notice,
              label: l10n.farmerNavAdvisory,
              badge: unread > 0 ? '$unread' : null,
            ),
            OrbitNavigationDestination(
              icon: OrbitIcons.crop,
              label: l10n.farmerNavFarm,
            ),
          ],
        ),
      ),
    );
  }
}
