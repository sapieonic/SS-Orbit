import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/data.dart';
import '../features/advisory/advisory_screen.dart';
import '../features/advisory/notice_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/dev/dev_screen.dart';
import '../features/farm/add_plot_screen.dart';
import '../features/farm/close_season_screen.dart';
import '../features/farm/consents_screen.dart';
import '../features/farm/farm_screen.dart';
import '../features/farm/start_season_screen.dart';
import '../features/fas/fas_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/consent_screen.dart';
import '../features/onboarding/name_screen.dart';
import '../features/onboarding/village_screen.dart';
import '../features/paused/paused_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/visits/advice_screen.dart';
import '../features/visits/visits_screen.dart';
import '../shared/voice.dart';
import 'app_shell.dart';
import 'routes.dart';

/// Where [phase] must be, or null when the farmer may go anywhere (active).
String? _phaseLocation(SessionPhase phase) => switch (phase) {
  SessionPhase.restoring => Routes.splash,
  SessionPhase.signedOut => Routes.login,
  SessionPhase.otpSent => Routes.otp,
  SessionPhase.needsConsent => Routes.consent,
  SessionPhase.needsVillage => Routes.village,
  SessionPhase.needsName => Routes.name,
  SessionPhase.inactive => Routes.paused,
  SessionPhase.active => null,
};

/// Pure redirect rule, kept separate so it is unit-testable.
///
/// The session phase owns the sign-in and sign-up screens: until the farmer is
/// active they always see the screen for their phase, and once active they
/// never see those screens again. The dev menu is reachable from anywhere.
@visibleForTesting
String? redirectFor(SessionPhase phase, String location) {
  if (location == Routes.dev) return null;
  final required = _phaseLocation(phase);
  if (required != null) return location == required ? null : required;
  return Routes.signInPaths.contains(location) ? Routes.home : null;
}

/// The app router. Rebuilt never; it re-runs [redirectFor] whenever the
/// session phase changes.
final routerProvider = Provider<GoRouter>((ref) {
  final phase = ValueNotifier(ref.read(sessionProvider).phase);
  ref
    ..listen(sessionProvider.select((s) => s.phase), (_, next) {
      phase.value = next;
    })
    ..onDispose(phase.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: phase,
    // Leaving a screen stops its voice; tab switches: see AppShell.
    observers: [VoiceStopObserver(() => ref.read(voicePlayerProvider))],
    redirect: (context, state) =>
        redirectFor(phase.value, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.otp, builder: (_, _) => const OtpScreen()),
      GoRoute(path: Routes.consent, builder: (_, _) => const ConsentScreen()),
      GoRoute(path: Routes.village, builder: (_, _) => const VillageScreen()),
      GoRoute(path: Routes.name, builder: (_, _) => const NameScreen()),
      GoRoute(path: Routes.paused, builder: (_, _) => const PausedScreen()),
      GoRoute(path: Routes.dev, builder: (_, _) => const DevScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, _) => const HomeScreen(),
                routes: [
                  GoRoute(path: 'fas', builder: (_, _) => const FasScreen()),
                  GoRoute(
                    path: 'calendar',
                    builder: (_, _) => const CalendarScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.visits,
                builder: (_, _) => const VisitsScreen(),
                routes: [
                  GoRoute(
                    path: ':visitId/issues/:issueIndex',
                    builder: (_, state) => AdviceScreen(
                      visitId: state.pathParameters['visitId']!,
                      // Not a number: no such issue, the screen says so.
                      issueIndex:
                          int.tryParse(state.pathParameters['issueIndex']!) ??
                          -1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.advisory,
                builder: (_, _) => const AdvisoryScreen(),
                routes: [
                  GoRoute(
                    path: ':noticeId',
                    builder: (_, state) => NoticeScreen(
                      noticeId: state.pathParameters['noticeId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.farm,
                builder: (_, _) => const FarmScreen(),
                routes: [
                  GoRoute(
                    path: 'consents',
                    builder: (_, _) => const ConsentsScreen(),
                  ),
                  GoRoute(
                    path: 'plots/new',
                    builder: (_, _) => const AddPlotScreen(),
                  ),
                  GoRoute(
                    path: 'plots/:plotId/season',
                    builder: (_, state) => StartSeasonScreen(
                      plotId: state.pathParameters['plotId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'seasons/:seasonId/close',
                    builder: (_, state) => CloseSeasonScreen(
                      seasonId: state.pathParameters['seasonId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
