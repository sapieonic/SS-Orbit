/// Every route path in the farmer app, in one place.
///
/// Screens navigate with these constants (`context.go(Routes.fas)`), never
/// with string literals, so a path changes in one file.
abstract final class Routes {
  // Sign-in and sign-up. The router sends the farmer here from the session
  // phase; screens don't navigate between them by hand.
  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/login/otp';
  static const consent = '/onboarding/consent';
  static const village = '/onboarding/village';
  static const name = '/onboarding/name';
  static const paused = '/paused';

  // Bottom-bar tabs.
  static const home = '/home';
  static const visits = '/visits';
  static const advisory = '/advisory';
  static const farm = '/farm';

  // Pushed over a tab.
  static const fas = '/home/fas';
  static const calendar = '/home/calendar';
  static const consents = '/farm/consents';
  static const addPlot = '/farm/plots/new';
  static const dev = '/dev';

  /// F8a / F8b: one issue of one visit.
  static String advice(String visitId, int issueIndex) =>
      '/visits/$visitId/issues/$issueIndex';

  /// One crop advisory notice.
  static String notice(String noticeId) => '/advisory/$noticeId';

  /// Start a season on a plot.
  static String startSeason(String plotId) => '/farm/plots/$plotId/season';

  /// Close an active season.
  static String closeSeason(String seasonId) => '/farm/seasons/$seasonId/close';

  /// Paths the session phase owns; an active farmer never stays on these.
  static const signInPaths = {
    splash,
    login,
    otp,
    consent,
    village,
    name,
    paused,
  };
}
