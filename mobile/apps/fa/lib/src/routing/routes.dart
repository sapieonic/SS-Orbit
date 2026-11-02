/// Every route path in the FA app, in one place.
///
/// Screens navigate with these constants and helpers
/// (`context.go(AppRoutes.farmers)`, `context.push(AppRoutes.farmer(id))`),
/// never with string literals, so a path changes in one file. Helpers build
/// the query string and leave out parameters that are null or empty.
library;

import '../local/territory.dart' show FarmerFilter;

/// Every route path in the FA app (see the library comment).
abstract final class AppRoutes {
  // Sign-in, setup, unlock and the blocked screens. The router sends the FA
  // here from the session phase; screens don't navigate between them by hand.

  /// Reading the saved session.
  static const splash = '/splash';

  /// A1 issued login (also when the password is needed again).
  static const login = '/login';

  /// A1c set your own password (temporary password).
  static const changePassword = '/login/password';

  /// A1d language and PIN, after the first login.
  static const setup = '/setup';

  /// A1b PIN unlock.
  static const unlock = '/unlock';

  /// A12 update the app.
  static const updateRequired = '/blocked/update';

  /// A12 this phone was removed.
  static const removed = '/blocked/removed';

  // Bottom-bar tabs.

  /// A2 Farmers near me (list and map).
  static const farmers = '/farmers';

  /// A3 Visit calendar.
  static const calendar = '/calendar';

  /// A4a Enrol a farmer, step 1 (no farmer picked).
  static const enrol = '/enrol';

  /// A6 Alerts.
  static const alerts = '/alerts';

  // Full-screen pages over the tabs (no bottom bar). Open them with `push`
  // so back returns to where the FA was.

  /// A7 Sync.
  static const sync = '/sync';

  /// A11 Me.
  static const me = '/me';

  /// Dev menu: dev builds on mock data only.
  static const dev = '/dev';

  /// The visit log route's path, without its query.
  static const visitPath = '/visit';

  /// Plan visit's path, without its query.
  static const planVisitPath = '/calendar/plan';

  /// A2 Farmers with [filter]'s chip picked (`/farmers?filter=visit_due`);
  /// [FarmerFilter.all] is plain [farmers].
  static String farmersFiltered(FarmerFilter filter) => _withQuery(farmers, {
    'filter': filter == FarmerFilter.all ? null : farmerFilterWire(filter),
  });

  /// The `filter` query value for [filter] (snake_case of its name:
  /// `visit_due`, `not_visited_30`).
  static String farmerFilterWire(FarmerFilter filter) => switch (filter) {
    FarmerFilter.all => 'all',
    FarmerFilter.isNew => 'new',
    FarmerFilter.visitDue => 'visit_due',
    FarmerFilter.notVisited30 => 'not_visited_30',
    FarmerFilter.finishEnrolment => 'finish_enrolment',
  };

  /// The [FarmerFilter] a `filter` query value names, or null (missing or
  /// unknown: no chip is forced).
  static FarmerFilter? farmerFilterFromWire(String? wire) =>
      FarmerFilter.values.where((f) => farmerFilterWire(f) == wire).firstOrNull;

  /// A8 Farmer 360 for [farmerId].
  static String farmer(String farmerId) => '/farmers/${_seg(farmerId)}';

  /// A3 plan a visit, for [farmerId] when it is known.
  static String planVisit({String? farmerId}) =>
      _withQuery(planVisitPath, {'farmerId': farmerId});

  /// A5 visit log: a planned visit ([visitId]) or a new visit for
  /// [farmerId], on [plotId] when it is known.
  static String visit({
    required String farmerId,
    String? visitId,
    String? plotId,
  }) => _withQuery(visitPath, {
    'farmerId': farmerId,
    'visitId': visitId,
    'plotId': plotId,
  });

  /// A4a enrol, with the farmer's [phone] already typed, opened from alert
  /// [alertId] (a new farmer signed up).
  static String enrolFarmer({String? phone, String? alertId}) =>
      _withQuery(enrol, {'phone': phone, 'alertId': alertId});

  /// A4 enrolment step 2: the farm of [farmerId].
  static String enrolPlot(String farmerId) => '/enrol/${_seg(farmerId)}/plot';

  /// A4c enrolment step 3: the crop on [plotId] of [farmerId].
  static String enrolCrop(String farmerId, {required String plotId}) =>
      _withQuery('/enrol/${_seg(farmerId)}/crop', {'plotId': plotId});

  /// Paths the session phase owns; an active FA never stays on these.
  static const entryPaths = {
    splash,
    login,
    changePassword,
    setup,
    unlock,
    updateRequired,
    removed,
  };

  /// The tab roots that show the bottom bar. Every other page in a tab
  /// (Farmer 360, the enrolment steps, plan visit) and A4a itself fill the
  /// screen as in the designs: back returns to the tab root.
  static const barPaths = {farmers, calendar, alerts};

  static String _seg(String value) => Uri.encodeComponent(value);

  static String _withQuery(String path, Map<String, String?> query) {
    final present = {
      for (final MapEntry(:key, :value) in query.entries)
        if (value != null && value.isNotEmpty) key: value,
    };
    return present.isEmpty
        ? path
        : Uri(path: path, queryParameters: present).toString();
  }
}
