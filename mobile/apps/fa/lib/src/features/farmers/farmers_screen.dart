import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/fa_header.dart';
import '../../shared/formatters.dart';
import 'farmer_presenter.dart';
import 'farmer_widgets.dart';
import 'farmers_map.dart';

/// A2 Farmers near me: list and map.
///
/// Nearest first from the FA's GPS fix (the middle of the area when there is
/// none). The list has the filter chips (All, New, Visit due, 30+ days,
/// Finish enrolment, with counts) and one card per farmer; the map has the
/// pins and the selected farmer's card. The header's search icon opens a
/// name / phone search for both. Everything reads the territory on the
/// phone, so it works offline (the map's tiles excepted).
///
/// A link with a [filter] (`AppRoutes.farmersFiltered`, e.g. the calendar's
/// "Find farmers due a visit") opens the list with that chip picked.
class FarmersScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const FarmersScreen({super.key, this.filter});

  /// The chip to start on (`/farmers?filter=visit_due`), or null for All.
  final FarmerFilter? filter;

  @override
  ConsumerState<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends ConsumerState<FarmersScreen> {
  static const _filters = FarmerFilter.values;

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late FarmerFilter _filter = widget.filter ?? FarmerFilter.all;
  bool _searching = false;
  bool _map = false;

  @override
  void didUpdateWidget(FarmersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The tab keeps this state: a new link's filter replaces the chip.
    if (widget.filter != oldWidget.filter) {
      _filter = widget.filter ?? FarmerFilter.all;
      if (widget.filter != null) _map = false;
    }
  }

  String get _query => _searching ? _search.text.trim() : '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
    if (_searching) _searchFocus.requestFocus();
  }

  void _showAll() {
    setState(() {
      _filter = FarmerFilter.all;
      _searching = false;
      _search.clear();
    });
  }

  String _chipLabel(OrbitLocalizations l10n, FarmerFilter f) => switch (f) {
    FarmerFilter.all => l10n.faFarmersFilterAll,
    FarmerFilter.isNew => l10n.faFarmersFilterNew,
    FarmerFilter.visitDue => l10n.faFarmersFilterVisitDue,
    FarmerFilter.notVisited30 => l10n.faFarmersFilter30Days,
    FarmerFilter.finishEnrolment => l10n.faFarmersFilterFinishEnrolment,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final territory = ref.watch(territoryProvider);
    final gps = ref.watch(farmersGpsProvider);
    final t = territory.value;
    final origin = gps.value ?? (t == null ? null : territoryCentre(t));
    final filter = _map ? FarmerFilter.all : _filter;
    final rows = t?.farmerRows(from: origin, filter: filter, query: _query);
    final searchingOrFiltered = _query.isNotEmpty || filter != FarmerFilter.all;

    String? subtitle;
    if (t != null && t.hasData) {
      final area = origin == null ? null : t.nearestVillage(origin);
      subtitle = dotJoin(l10n, [
        area?.displayName(contentLanguage(context)),
        searchingOrFiltered
            ? l10n.faFarmersShown(count: rows!.length)
            : l10n.faFarmersCount(count: t.farmerCount),
        if (!_map) l10n.faFarmersNearestFirst,
      ]);
    }

    return Scaffold(
      body: Column(
        children: [
          FaHeader(
            title: l10n.faFarmersTitle,
            subtitle: subtitle,
            showMe: true,
            actions: [
              IconButton(
                onPressed: _toggleSearch,
                icon: Icon(_searching ? OrbitIcons.close : OrbitIcons.search),
                color: OrbitColors.of(context).onPrimaryBar,
                tooltip: _searching
                    ? l10n.faFarmersSearchClose
                    : l10n.faFarmersSearchOpen,
              ),
            ],
          ),
          if (_searching) _searchField(l10n),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OrbitSpace.s16,
              OrbitSpace.s12,
              OrbitSpace.s16,
              0,
            ),
            child: SegmentedTabs(
              labels: [l10n.faFarmersViewList, l10n.faFarmersViewMap],
              selectedIndex: _map ? 1 : 0,
              onChanged: (i) => setState(() => _map = i == 1),
            ),
          ),
          Expanded(
            child: AsyncValueView<Territory>(
              value: territory,
              onRetry: () => ref.invalidate(territoryProvider),
              data: (t) {
                if (!t.hasData) {
                  return _state(
                    icon: OrbitIcons.sync,
                    title: l10n.faFarmersNoDataTitle,
                    subtitle: l10n.faFarmersNoDataBody,
                    action: l10n.faFarmersNoDataAction,
                    onAction: () => openFrom(context, AppRoutes.sync),
                  );
                }
                if (t.farmerCount == 0) {
                  return _state(
                    icon: OrbitIcons.people,
                    title: l10n.faFarmersEmptyTitle,
                    subtitle: l10n.faFarmersEmptyBody,
                    action: l10n.faFarmersEmptyAction,
                    onAction: () => openFrom(context, AppRoutes.enrol),
                  );
                }
                return _map
                    ? _mapView(t, rows!, origin, isGps: gps.value != null)
                    : _list(l10n, t, rows!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(OrbitLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(
      OrbitSpace.s16,
      OrbitSpace.s12,
      OrbitSpace.s16,
      0,
    ),
    child: TextField(
      controller: _search,
      focusNode: _searchFocus,
      textInputAction: TextInputAction.search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: l10n.faFarmersSearchHint,
        prefixIcon: const Icon(OrbitIcons.search),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                onPressed: () => setState(_search.clear),
                icon: const Icon(OrbitIcons.close),
                tooltip: l10n.faFarmersSearchClear,
              ),
      ),
    ),
  );

  Widget _list(OrbitLocalizations l10n, Territory t, List<FarmerRow> rows) {
    final counts = t.filterCounts(query: _query);
    final chips = FilterChipsBar(
      semanticLabel: l10n.faFarmersFilterLabel,
      padding: const EdgeInsets.symmetric(horizontal: OrbitSpace.s16),
      items: [
        for (final f in _filters)
          FilterChipItem(label: _chipLabel(l10n, f), count: counts[f]),
      ],
      selectedIndex: _filters.indexOf(_filter),
      onSelected: (i) => setState(() => _filter = _filters[i]),
    );
    return Column(
      children: [
        const SizedBox(height: OrbitSpace.s12),
        chips,
        Expanded(
          child: rows.isEmpty
              ? _noMatch(l10n)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    OrbitSpace.s16,
                    OrbitSpace.s12,
                    OrbitSpace.s16,
                    OrbitSpace.s16,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: OrbitSpace.s10),
                  itemBuilder: (_, i) => FarmerCard(
                    key: ValueKey(rows[i].farmer.id),
                    row: rows[i],
                    today: t.today,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _mapView(
    Territory t,
    List<FarmerRow> rows,
    LatLng? origin, {
    required bool isGps,
  }) {
    final online = ref.watch(phoneOnlineProvider);
    if (ref.watch(farmersGpsProvider).isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rows.isEmpty) return _noMatch(context.l10n);
    return Padding(
      padding: const EdgeInsets.only(top: OrbitSpace.s12),
      child: FarmersMap(
        rows: rows,
        origin: origin,
        isGps: isGps,
        today: t.today,
        online: online,
      ),
    );
  }

  Widget _noMatch(OrbitLocalizations l10n) => _state(
    icon: OrbitIcons.search,
    title: l10n.faFarmersNoMatchTitle,
    subtitle: _query.isNotEmpty
        ? l10n.faFarmersNoMatchSearch(query: _query)
        : l10n.faFarmersNoMatchFilter,
    action: l10n.faFarmersShowAll,
    onAction: _showAll,
  );

  Widget _state({
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onAction,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(OrbitSpace.s16),
      child: StateCard(
        icon: icon,
        title: title,
        subtitle: subtitle,
        action: OrbitButton(
          label: action,
          variant: OrbitButtonVariant.secondary,
          onPressed: onAction,
        ),
      ),
    ),
  );
}
