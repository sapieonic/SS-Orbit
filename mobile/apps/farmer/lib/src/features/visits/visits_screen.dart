import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/call_buttons.dart';
import '../../shared/farmer_data.dart';
import '../../shared/farmer_text.dart';
import '../../shared/voice.dart';
import 'visit_widgets.dart';
import 'visits_providers.dart';

/// My visits (F4): the next planned FA visit, then every logged visit
/// grouped by plot, each issue with its advice. Tapping an issue opens the
/// advice (F8a / F8b).
class VisitsScreen extends ConsumerWidget {
  /// Creates the screen.
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visits = ref.watch(visitsControllerProvider).fresh;
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: l10n.farmerVisitsTitle,
            listen: const ScreenListenButton(
              voiceKey: VoiceKeys.farmerVisitsVoiceHelp,
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: visits,
              onRetry: () => ref.invalidate(visitsControllerProvider),
              data: (state) => _VisitsList(state: state),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitsList extends ConsumerWidget {
  const _VisitsList({required this.state});

  final VisitsState state;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    // Plot names come from Home; reload it too if it failed earlier.
    if (ref.read(farmerHomeProvider).hasError) {
      ref.invalidate(farmerHomeProvider);
    }
    ref.invalidate(visitsControllerProvider);
    try {
      await ref.read(visitsControllerProvider.future);
    } on Object catch (error) {
      // The old list stays on screen; say why it did not update.
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final today = LocalDate.todayIst(ref.watch(clockProvider));
    final plotNames = _plotNames(
      l10n,
      language,
      ref.watch(farmerHomeProvider).fresh.value,
      ref.watch(cropsProvider).fresh.value,
    );
    final visits = state.visits;

    final children = <Widget>[
      if (state.nextVisit != null || visits.items.isNotEmpty)
        NextVisitCard(
          nextVisit: state.nextVisit,
          today: today,
          language: language,
        ),
      if (visits.items.isEmpty)
        StateCard(
          icon: OrbitIcons.visit,
          title: l10n.farmerStateNoVisitsTitle,
          subtitle: state.nextVisit == null
              ? l10n.farmerStateNoVisitsBody
              : null,
          action: const FaCallButton(size: OrbitButtonSize.large),
          listen: const ScreenListenButton(
            voiceKey: VoiceKeys.farmerStateNoVisitsVoice,
          ),
        ),
      for (final group in _groupByPlot(visits.items)) ...[
        if (plotNames[group.plotId] case final name?)
          SectionHeader(title: name),
        for (final visit in group.visits)
          VisitCard(
            visit: visit,
            language: language,
            onOpenIssue: (index) => context.go(Routes.advice(visit.id, index)),
          ),
      ],
      if (visits.hasMore || visits.loadMoreError != null)
        LoadMoreFooter(
          key: ValueKey(visits.nextCursor),
          loading: visits.loadingMore,
          errorText: switch (visits.loadMoreError) {
            final error? => errorText(context, error),
            null => null,
          },
          loadingLabel: l10n.commonLoading,
          retryLabel: l10n.commonRetry,
          onLoadMore: () =>
              ref.read(visitsControllerProvider.notifier).loadMore(),
        ),
    ];

    return RefreshIndicator(
      onRefresh: () => _refresh(context, ref),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(OrbitSpace.s16),
        itemCount: children.length,
        itemBuilder: (_, i) => children[i],
        separatorBuilder: (_, _) => const SizedBox(height: OrbitSpace.s12),
      ),
    );
  }
}

/// Visits of one plot, newest first.
typedef _PlotGroup = ({String plotId, List<FarmerVisit> visits});

/// Groups [visits] (newest first) by plot; the plot visited most recently
/// comes first.
List<_PlotGroup> _groupByPlot(List<FarmerVisit> visits) {
  final groups = <String, List<FarmerVisit>>{};
  for (final v in visits) {
    groups.putIfAbsent(v.plotId, () => []).add(v);
  }
  return [
    for (final MapEntry(:key, :value) in groups.entries)
      (plotId: key, visits: value),
  ];
}

/// Plot ID -> "పొలం 1 · పత్తి" from the Home payload. Plots Home does not
/// know (archived, or Home not loaded yet) get no header.
Map<String, String> _plotNames(
  OrbitLocalizations l10n,
  Language language,
  FarmerHome? home,
  FarmerCropList? crops,
) => {
  for (final plot in home?.plots ?? const <HomePlot>[])
    plot.plot.id: plotAndCrop(l10n, plot, crops, language),
};
