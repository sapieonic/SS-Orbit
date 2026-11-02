/// What the Alerts tab reads: the territory's alerts (offline), the online
/// alert list for history and contact details.
///
/// The snapshot is the source of the open alerts: it works offline and
/// already carries the FA's own "Got it" and closed call-backs (projected
/// from the outbox). `GET /v1/fa/alerts` only adds what the snapshot does
/// not keep: closed alerts for "Earlier", and the farmer's name and phone
/// for alerts about farmers who are not in the territory.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../shared/formatters.dart';

/// The last online alert list (newest first, at most [AlertsHistory.limit]),
/// empty until the FA refreshed once. Forgotten when another FA signs in.
final alertsHistoryProvider = NotifierProvider<AlertsHistory, List<FaAlert>>(
  AlertsHistory.new,
);

/// Loads the online alert list on pull-to-refresh (and when "Earlier" is
/// opened online for the first time).
class AlertsHistory extends Notifier<List<FaAlert>> {
  /// How many alerts one refresh asks for.
  static const limit = 50;

  bool _loaded = false;

  /// True once a refresh succeeded for the signed-in FA.
  bool get loaded => _loaded;

  @override
  List<FaAlert> build() {
    ref.watch(sessionProvider.select((s) => s.fa?.id));
    _loaded = false;
    return const [];
  }

  /// `GET /v1/fa/alerts`; throws `ApiError` (the list stays as it was).
  Future<void> refresh() async {
    final faId = ref.read(sessionProvider).fa?.id;
    final page = await ref
        .read(alertsRepositoryProvider)
        .listAlerts(limit: limit);
    if (!ref.mounted) return;
    _loaded = true;
    state = [
      for (final a in page.items)
        if (faId == null || a.alert.faId == faId) a,
    ];
  }
}

/// The filter chips of the Alerts tab, in order.
enum AlertTab {
  /// Every alert.
  all,

  /// `new_farmer`.
  newFarmers,

  /// `callback`.
  callbacks,

  /// `ho_note`.
  ho;

  /// True when an alert of [kind] shows under this chip.
  bool matches(AlertKind kind) => switch (this) {
    AlertTab.all => true,
    AlertTab.newFarmers => kind == AlertKind.newFarmer,
    AlertTab.callbacks => kind == AlertKind.callback,
    AlertTab.ho => kind == AlertKind.hoNote,
  };
}

/// One alert card: the alert with what its actions need.
final class AlertItem {
  /// Creates an item.
  const AlertItem({
    required this.alert,
    this.farmer,
    this.farmerRow,
    this.farmerName,
    this.phone,
    this.callbackOpen = false,
    this.pendingSync = false,
  });

  /// The alert (status as the phone sees it: "Got it" and closed call-backs
  /// included).
  final SnapAlert alert;

  /// The farmer in the territory, or null.
  final SnapFarmer? farmer;

  /// The farmer's list row (enrolment gaps), or null.
  final FarmerRow? farmerRow;

  /// The farmer's English name from the online list, when the farmer is not
  /// in the territory.
  final String? farmerName;

  /// The farmer's E.164 phone, or null.
  final String? phone;

  /// For a call-back: the request is still open on the phone.
  final bool callbackOpen;

  /// The FA's change to it ("Got it") has not synced yet.
  final bool pendingSync;

  /// The farmer's name in [language], or null when unknown.
  String? name(Language language) {
    final f = farmer;
    if (f != null) {
      final n = f.displayName(language);
      if (n.isNotEmpty) return n;
    }
    final n = farmerName?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  /// The farmer is on the phone with a crop, so Plan a visit can save a
  /// visit (it needs an active season).
  bool get canPlanVisit =>
      farmer != null &&
      (farmerRow?.plots.any((p) => p.season != null) ?? false);

  /// The phone as 10 digits for the enrol form, or null.
  String? get nationalPhone => nationalMobile(phone);
}

/// The alerts to show, split into open cards and "Earlier".
final class AlertsView {
  /// Creates the view.
  const AlertsView({
    required this.open,
    required this.earlier,
    required this.openCounts,
  });

  /// Builds the view from [territory] and the online [history]. Alerts in
  /// [keepInPlace] (acknowledged or closed on this visit of the screen) stay
  /// among the open cards so their confirmation shows where the FA tapped.
  factory AlertsView.build(
    Territory territory, {
    required List<FaAlert> history,
    required AlertTab tab,
    Set<String> keepInPlace = const {},
  }) {
    final byId = {for (final h in history) h.id: h};
    AlertItem item(SnapAlert a) {
      final farmerId = a.farmerId;
      final farmer = farmerId == null ? null : territory.farmer(farmerId);
      final online = byId[a.id];
      final refId = a.refId;
      return AlertItem(
        alert: a,
        farmer: farmer,
        farmerRow: farmer == null ? null : territory.farmerRow(farmer.id),
        farmerName: online?.farmerName,
        phone: farmer?.phone ?? online?.farmerPhone,
        callbackOpen:
            a.kind == AlertKind.callback &&
            refId != null &&
            territory.callback(refId) != null,
        pendingSync: territory.isPending(a.id),
      );
    }

    // Every alert on the phone: open ones (and those acted on during this
    // visit of the screen) on top, acknowledged and closed ones in Earlier.
    final onPhone = territory.allAlerts;
    final onPhoneIds = {for (final a in onPhone) a.id};
    final open = <SnapAlert>[];
    final earlier = <SnapAlert>[];
    for (final a in onPhone) {
      if (a.status == AlertStatus.open || keepInPlace.contains(a.id)) {
        open.add(a);
      } else {
        earlier.add(a);
      }
    }
    // History the snapshot doesn't keep (closed alerts).
    for (final h in history) {
      final a = h.alert;
      if (onPhoneIds.contains(a.id)) continue;
      if (a.kind == AlertKind.invoiceCheck || a.status == AlertStatus.open) {
        continue;
      }
      earlier.add(a);
    }
    int newestFirst(SnapAlert a, SnapAlert b) =>
        b.createdAt.compareTo(a.createdAt);
    open.sort(newestFirst);
    earlier.sort(newestFirst);

    final counts = {for (final t in AlertTab.values) t: 0};
    for (final a in onPhone) {
      if (a.status != AlertStatus.open) continue;
      for (final t in AlertTab.values) {
        if (t.matches(a.kind)) counts[t] = counts[t]! + 1;
      }
    }
    return AlertsView(
      open: [
        for (final a in open)
          if (tab.matches(a.kind)) item(a),
      ],
      earlier: [
        for (final a in earlier)
          if (tab.matches(a.kind)) item(a),
      ],
      openCounts: counts,
    );
  }

  /// Cards shown at the top (open, plus those just acted on).
  final List<AlertItem> open;

  /// Acknowledged and closed alerts (collapsed section).
  final List<AlertItem> earlier;

  /// Open alerts per chip.
  final Map<AlertTab, int> openCounts;
}
