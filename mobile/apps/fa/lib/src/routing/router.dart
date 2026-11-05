import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';

import '../data/data.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/auth/change_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/setup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/unlock_screen.dart';
import '../features/blocked/removed_screen.dart';
import '../features/blocked/update_required_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/calendar/plan_visit_screen.dart';
import '../features/dev/dev_screen.dart';
import '../features/enrol/enrol_crop_screen.dart';
import '../features/enrol/enrol_farmer_screen.dart';
import '../features/enrol/enrol_plot_screen.dart';
import '../features/farmer360/farmer360_screen.dart';
import '../features/farmers/farmers_screen.dart';
import '../features/me/me_screen.dart';
import '../features/sync/sync_screen.dart';
import '../features/visit_log/visit_log_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

/// The entry page [phase] must show, or null when the FA may go anywhere
/// (active).
String? phaseLocation(SessionPhase phase) => switch (phase) {
  SessionPhase.restoring => AppRoutes.splash,
  SessionPhase.signedOut || SessionPhase.passwordNeeded => AppRoutes.login,
  SessionPhase.mustChangePassword => AppRoutes.changePassword,
  SessionPhase.setup => AppRoutes.setup,
  SessionPhase.locked => AppRoutes.unlock,
  SessionPhase.updateRequired => AppRoutes.updateRequired,
  SessionPhase.removed => AppRoutes.removed,
  SessionPhase.active => null,
};

/// Phases that keep the page the FA was on, to return to once active again:
/// a cold start (restoring, then the PIN) and the auto-lock. Signing in
/// again from scratch, or as another FA, starts on Farmers.
const _resumablePhases = {SessionPhase.restoring, SessionPhase.locked};

/// Pure redirect rule, kept separate so it is unit-testable.
///
/// The session phase owns the entry pages: until the FA is active they
/// always see the page for their phase, and once active they never see
/// those pages again. [location] is the requested location (path and
/// query). [resumeTo] is the app page held back by the last redirect to an
/// entry page (see [RedirectMemory]); an active FA leaving an entry page goes
/// there, else to Farmers. The dev menu is reachable in every phase when
/// [devMenu] (dev builds on mock data), and nowhere otherwise.
@visibleForTesting
String? redirectFor(
  SessionPhase phase,
  String location, {
  required bool devMenu,
  String? resumeTo,
}) {
  final path = Uri.parse(location).path;
  if (path == AppRoutes.dev) {
    if (devMenu) return null;
    return phaseLocation(phase) ?? AppRoutes.farmers;
  }
  final required = phaseLocation(phase);
  if (required != null) return path == required ? null : required;
  if (AppRoutes.entryPaths.contains(path)) return resumeTo ?? AppRoutes.farmers;
  return null;
}

/// Remembers the app page a deep link or the auto-lock asked for while the
/// session was not active, so the FA lands there after unlocking instead of
/// on Farmers. Owned by the router.
class RedirectMemory {
  String? _held;

  /// The held page, if any.
  String? get held => _held;

  /// The redirect for [location] in [phase], remembering or forgetting the
  /// page as it goes.
  String? redirect(
    SessionPhase phase,
    String location, {
    required bool devMenu,
  }) {
    final path = Uri.parse(location).path;
    final gate = phaseLocation(phase);
    if (gate != null) {
      if (_resumablePhases.contains(phase)) {
        if (!AppRoutes.entryPaths.contains(path) && path != AppRoutes.dev) {
          _held = location;
        }
      } else {
        _held = null;
      }
    }
    final target = redirectFor(
      phase,
      location,
      devMenu: devMenu,
      resumeTo: _held,
    );
    if (gate == null && target != null && target == _held) _held = null;
    if (gate == null && target == null) _held = null;
    return target;
  }
}

/// What the router and the lock overlay route on: the session phase, and
/// whether a lock is shown over the app's pages ([lockOverlay]) instead of
/// on its own page.
///
/// The auto-lock (and Me's lock) of an active FA covers the open pages with
/// the PIN screen ([LockOverlay]): the page stack, an in-progress visit
/// log or enrolment included, survives the unlock. A cold start
/// (restoring, then locked) has no stack to keep and goes to the PIN page.
/// Every other phase owns its own page, as before.
class AppGate extends ChangeNotifier {
  /// Creates the gate at [phase] (no overlay).
  AppGate(this._phase);

  SessionPhase _phase;
  bool _lockOverlay = false;

  /// The session phase.
  SessionPhase get phase => _phase;

  /// The FA locked an open app: the PIN screen covers its pages.
  bool get lockOverlay => _lockOverlay;

  /// The phase the redirect works with: active under the overlay (the
  /// pages stay; the overlay hides them).
  SessionPhase get routingPhase => _lockOverlay ? SessionPhase.active : _phase;

  /// Follows the session to [next].
  void update(SessionPhase next) {
    if (next == _phase) return;
    _lockOverlay = next == SessionPhase.locked && _phase == SessionPhase.active;
    _phase = next;
    notifyListeners();
  }
}

/// The [AppGate] following the session (one per app).
final appGateProvider = Provider<AppGate>((ref) {
  final gate = AppGate(ref.read(sessionProvider).phase);
  ref
    ..listen(sessionProvider.select((s) => s.phase), (_, next) {
      gate.update(next);
    })
    ..onDispose(gate.dispose);
  return gate;
});

/// Whether the dev menu exists in this build: dev flavour on mock data.
bool devMenuEnabled(OrbitEnv env) =>
    env.flavor == Flavor.dev && env.dataSource == DataSource.mock;

/// The root navigator: full-screen pages (Sync, Me, the visit log, the dev
/// menu) open on it, over the tabs.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app router. Built once; it re-runs [redirectFor] whenever the session
/// phase changes ([AppGate.routingPhase]: under the lock overlay the pages
/// stay where they are).
final routerProvider = Provider<GoRouter>((ref) {
  final gate = ref.watch(appGateProvider);
  final devMenu = devMenuEnabled(ref.read(orbitEnvProvider));
  final memory = RedirectMemory();

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: gate,
    redirect: (context, state) => memory.redirect(
      gate.routingPhase,
      state.uri.toString(),
      devMenu: devMenu,
    ),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'password',
            builder: (_, _) => const ChangePasswordScreen(),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.setup, builder: (_, _) => const SetupScreen()),
      GoRoute(path: AppRoutes.unlock, builder: (_, _) => const UnlockScreen()),
      GoRoute(
        path: AppRoutes.updateRequired,
        builder: (_, _) => const UpdateRequiredScreen(),
      ),
      GoRoute(
        path: AppRoutes.removed,
        builder: (_, _) => const RemovedScreen(),
      ),
      GoRoute(path: AppRoutes.sync, builder: (_, _) => const SyncScreen()),
      GoRoute(path: AppRoutes.me, builder: (_, _) => const MeScreen()),
      GoRoute(path: AppRoutes.dev, builder: (_, _) => const DevScreen()),
      GoRoute(
        path: AppRoutes.visitPath,
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return VisitLogScreen(
            // Missing: no such farmer, the screen says so.
            farmerId: q['farmerId'] ?? '',
            visitId: _present(q['visitId']),
            plotId: _present(q['plotId']),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, state, shell) =>
            AppShell(shell: shell, location: state.uri.path),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.farmers,
                builder: (_, state) => FarmersScreen(
                  filter: AppRoutes.farmerFilterFromWire(
                    state.uri.queryParameters['filter'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':farmerId',
                    builder: (_, state) => Farmer360Screen(
                      farmerId: state.pathParameters['farmerId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.calendar,
                builder: (_, _) => const CalendarScreen(),
                routes: [
                  GoRoute(
                    path: 'plan',
                    builder: (_, state) => PlanVisitScreen(
                      farmerId: _present(state.uri.queryParameters['farmerId']),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.enrol,
                builder: (_, state) => EnrolFarmerScreen(
                  // A new key for each tap on the Enrol tab and each link
                  // (another number or alert): step 1 starts fresh, never
                  // with the last enrolment's fields.
                  key: ValueKey((
                    ref.read(enrolStartProvider),
                    state.uri.query,
                  )),
                  phone: _present(state.uri.queryParameters['phone']),
                  alertId: _present(state.uri.queryParameters['alertId']),
                ),
                routes: [
                  GoRoute(
                    path: ':farmerId/plot',
                    builder: (_, state) => EnrolPlotScreen(
                      farmerId: state.pathParameters['farmerId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':farmerId/crop',
                    builder: (_, state) => EnrolCropScreen(
                      farmerId: state.pathParameters['farmerId']!,
                      // Missing: no such plot, the screen says so.
                      plotId: state.uri.queryParameters['plotId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.alerts,
                builder: (_, _) => const AlertsScreen(),
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

String? _present(String? value) =>
    value == null || value.isEmpty ? null : value;
