import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/contact.dart';
import '../../shared/fa_header.dart';
import 'alert_card.dart';
import 'alerts_data.dart';

/// A6 Alerts from HO and farmers.
///
/// Reads the alerts in the territory on the phone, so it works offline;
/// "Got it" and closing a call-back go through `FaActions` and show at once.
/// Pull to refresh syncs (pushes what waits, pulls the snapshot) and then
/// loads the online alert list for older, closed alerts and contact details
/// (see `alerts_data.dart`).
class AlertsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  AlertTab _tab = AlertTab.all;
  bool _earlierOpen = false;

  /// Alerts acted on during this visit: they stay where the FA tapped.
  final _keepInPlace = <String>{};

  /// Call-backs the FA dialled from here: offer Close call-back.
  final _called = <String>{};

  /// Alerts with an action being saved.
  final _busy = <String>{};

  OrbitLocalizations get _l10n => context.l10n;

  Future<void> _refresh() async {
    if (!ref.read(connectivityProvider).isOnline) {
      showActionError(context, const ApiError.network());
      return;
    }
    // Push first (a queued "Got it" must not come back as open), then pull
    // the snapshot: it is what the tab shows, online or not.
    await ref.read(syncEngineProvider).syncNow();
    try {
      await ref.read(alertsHistoryProvider.notifier).refresh();
    } on ApiError catch (e) {
      if (mounted) showActionError(context, e);
    }
  }

  @override
  void initState() {
    super.initState();
    // The snapshot has no phone for a farmer outside the territory (a self
    // sign-up waiting for enrolment); the online list has it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistoryQuietly());
  }

  /// Loads the online alert list once, when online; errors are ignored (the
  /// tab already shows what the phone has).
  void _loadHistoryQuietly() {
    if (!mounted) return;
    final history = ref.read(alertsHistoryProvider.notifier);
    if (history.loaded || !ref.read(connectivityProvider).isOnline) return;
    unawaited(history.refresh().catchError((Object _) {}));
  }

  void _toggleEarlier() {
    setState(() => _earlierOpen = !_earlierOpen);
    if (_earlierOpen) _loadHistoryQuietly();
  }

  /// Opens the dialer for [item]'s farmer; says the number when no dialer
  /// opened.
  Future<void> _dial(AlertItem item) async {
    final phone = item.phone;
    if (phone == null) return;
    await callFarmer(context, ref, phone);
  }

  Future<void> _save(AlertItem item, Future<void> Function() write) async {
    final id = item.alert.id;
    setState(() => _busy.add(id));
    try {
      await write();
      _keepInPlace.add(id);
    } on Object catch (e) {
      if (mounted) showActionError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  late final _actions = AlertCardActions(
    onFinishEnrolment: (item) => context.go(
      AppRoutes.enrolFarmer(phone: item.nationalPhone, alertId: item.alert.id),
    ),
    onOpenFarmer: (item) {
      final farmer = item.farmer;
      if (farmer != null) context.go(AppRoutes.farmer(farmer.id));
    },
    onCallAndPlan: (item) async {
      final farmer = item.farmer;
      await _dial(item);
      if (!mounted || farmer == null) return;
      context.go(AppRoutes.planVisit(farmerId: farmer.id));
    },
    onCall: (item) async {
      await _dial(item);
      // Offer to close even when no dialer opened: the FA may have called
      // from another phone.
      if (mounted) setState(() => _called.add(item.alert.id));
    },
    onCloseCallback: (item) {
      final callbackId = item.alert.refId;
      if (callbackId == null) return;
      unawaited(
        _save(
          item,
          () => ref.read(faActionsProvider).closeCallback(callbackId),
        ),
      );
    },
    onAck: (item) => unawaited(
      _save(item, () => ref.read(faActionsProvider).ackAlert(item.alert.id)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final territory = ref.watch(territoryProvider);
    final history = ref.watch(alertsHistoryProvider);
    final online = ref.watch(phoneOnlineProvider);
    final now = ref.watch(clockProvider).now();
    final view = territory.value == null
        ? null
        : AlertsView.build(
            territory.requireValue,
            history: history,
            tab: _tab,
            keepInPlace: _keepInPlace,
          );
    final openCount = view?.openCounts[AlertTab.all] ?? 0;

    return Scaffold(
      body: Column(
        children: [
          FaHeader(
            title: l10n.faNavAlerts,
            subtitle: view == null
                ? null
                : l10n.faAlertsSubtitle(count: openCount),
            showMe: true,
          ),
          if (!online)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OrbitSpace.s16,
                OrbitSpace.s12,
                OrbitSpace.s16,
                0,
              ),
              child: OrbitBanner(
                kind: OrbitBannerKind.offline,
                title: l10n.faCommonOfflineTitle,
                message: l10n.faAlertsOfflineBody,
              ),
            ),
          Expanded(
            child: AsyncValueView<Territory>(
              value: territory,
              onRetry: () => ref.invalidate(territoryProvider),
              data: (_) => _body(view!, now),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AlertsView view, DateTime now) {
    final l10n = _l10n;
    final counts = view.openCounts;
    final chips = FilterChipsBar(
      semanticLabel: l10n.faAlertsTabsLabel,
      padding: const EdgeInsets.symmetric(horizontal: OrbitSpace.s16),
      selectedIndex: _tab.index,
      onSelected: (i) => setState(() => _tab = AlertTab.values[i]),
      items: [
        for (final t in AlertTab.values)
          FilterChipItem(label: _tabLabel(t), count: counts[t]),
      ],
    );

    Widget card(AlertItem item) => Padding(
      padding: const EdgeInsets.only(bottom: OrbitSpace.s10),
      child: AlertCard(
        key: ValueKey(item.alert.id),
        item: item,
        now: now,
        actions: _actions,
        called: _called.contains(item.alert.id),
        busy: _busy.contains(item.alert.id),
      ),
    );

    final nothing = view.open.isEmpty && view.earlier.isEmpty;
    return Column(
      children: [
        const SizedBox(height: OrbitSpace.s12),
        chips,
        const SizedBox(height: OrbitSpace.s10),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                OrbitSpace.s16,
                0,
                OrbitSpace.s16,
                OrbitSpace.s16,
              ),
              children: [
                if (nothing)
                  _tab == AlertTab.all
                      ? StateCard(
                          icon: OrbitIcons.bell,
                          title: l10n.faAlertsEmptyTitle,
                          subtitle: l10n.faAlertsEmptyBody,
                        )
                      : StateCard(
                          icon: OrbitIcons.inbox,
                          title: l10n.faAlertsEmptyTabTitle,
                          subtitle: l10n.faAlertsEmptyTabBody,
                        )
                else if (view.open.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: OrbitSpace.s10),
                    child: StateCard(
                      icon: OrbitIcons.synced,
                      title: _tab == AlertTab.all
                          ? l10n.faAlertsEmptyTitle
                          : l10n.faAlertsEmptyTabTitle,
                    ),
                  ),
                for (final item in view.open) card(item),
                if (view.earlier.isNotEmpty) ...[
                  _EarlierHeader(
                    count: view.earlier.length,
                    open: _earlierOpen,
                    onTap: _toggleEarlier,
                  ),
                  if (_earlierOpen)
                    for (final item in view.earlier) card(item),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _tabLabel(AlertTab tab) => switch (tab) {
    AlertTab.all => _l10n.faAlertsTabAll,
    AlertTab.newFarmers => _l10n.faAlertsTabNewFarmers,
    AlertTab.callbacks => _l10n.faAlertsTabCallbacks,
    AlertTab.ho => _l10n.faAlertsTabHo,
  };
}

/// "Earlier · 3" with a chevron: shows or hides the acknowledged and closed
/// alerts.
class _EarlierHeader extends StatelessWidget {
  const _EarlierHeader({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(OrbitSpace.s12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: OrbitSize.controlLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: OrbitSpace.s4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.faAlertsEarlier(count: count),
                    style: theme.textTheme.titleSmall!.copyWith(
                      color: orbit.textMuted,
                      fontWeight: OrbitFont.weightBold,
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      OrbitIcons.chevronRight,
                      color: orbit.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
