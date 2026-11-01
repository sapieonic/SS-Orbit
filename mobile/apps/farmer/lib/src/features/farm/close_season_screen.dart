import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/farmer_data.dart';
import '../../shared/farmer_text.dart';
import '../../shared/voice.dart';
import 'farm_format.dart';
import 'widgets/plot_state_card.dart';

/// Close an active season (F10): harvested or abandoned as two big choices,
/// then one confirm button under a "can't undo" note. Saves with
/// `POST /v1/farmer/me/seasons/{season_id}/close`.
///
/// Back (header or system) waits while it saves.
///
/// A season that is no longer active (closed elsewhere: 409
/// `season_not_active`, or already gone from Home) shows one card that goes
/// back to My farm.
class CloseSeasonScreen extends ConsumerStatefulWidget {
  const CloseSeasonScreen({super.key, required this.seasonId});

  final String seasonId;

  @override
  ConsumerState<CloseSeasonScreen> createState() => _CloseSeasonScreenState();
}

class _CloseSeasonScreenState extends ConsumerState<CloseSeasonScreen> {
  SeasonOutcome? _outcome;
  bool _saving = false;

  /// The plot as last seen, kept while saving so the screen does not flash
  /// "already closed" when Home refreshes before the pop finishes.
  HomePlot? _plot;

  Future<void> _close() async {
    final outcome = _outcome;
    if (outcome == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final edits = ref.read(farmerEditsProvider);
    setState(() => _saving = true);
    try {
      // Refreshes Home (also on season_not_active), even if this screen is
      // gone by the time the server answers.
      await edits.closeSeason(seasonId: widget.seasonId, outcome: outcome);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.farmerSeasonCloseClosed)));
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
      if (e is ApiError && e.code == ApiErrorCode.seasonNotActive) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final home = ref.watch(farmerHomeProvider).fresh;
    final found = home.value?.plots
        .where((p) => p.activeSeason?.id == widget.seasonId)
        .firstOrNull;
    if (found != null) _plot = found;
    final plot = _saving ? _plot : found;

    final Widget body;
    Widget? action;
    if (!home.hasValue) {
      body = AsyncValueView(
        value: home,
        onRetry: () => ref.invalidate(farmerHomeProvider),
        data: (_) => const SizedBox.shrink(),
      );
    } else if (plot == null) {
      body = const PlotStateCard(
        errorCode: ApiErrorCode.seasonNotActive,
        voiceKey: VoiceKeys.farmerSeasonCloseVoiceHelp,
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: _OutcomeChoice(
          selected: _outcome,
          onSelected: _saving
              ? null
              : (outcome) => setState(() => _outcome = outcome),
        ),
      );
      action = _ConfirmBar(
        saving: _saving,
        onConfirm: _outcome == null ? null : _close,
      );
    }

    // System back waits for the save, like the header's back.
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        body: Column(
          children: [
            ScreenHeader(
              title: l10n.farmerSeasonCloseTitle,
              subtitle: plot == null ? null : _subtitle(plot),
              onBack: _saving ? null : () => context.pop(),
              listen: const ScreenListenButton(
                voiceKey: VoiceKeys.farmerSeasonCloseVoiceHelp,
              ),
            ),
            Expanded(child: body),
            ?action,
          ],
        ),
      ),
    );
  }

  /// "పొలం 1 · పత్తి · ఖరీఫ్ 2026".
  String _subtitle(HomePlot plot) {
    final l10n = context.l10n;
    final season = plot.activeSeason!;
    final crop = ref.watch(cropsProvider).fresh.value?.byId(season.cropId);
    final language = contentLanguage(context);
    return [
      plotName(l10n, plot.plot),
      if (crop != null) cropName(crop, language),
      seasonLabel(l10n, season.seasonCode),
    ].reduce((a, b) => l10n.commonDotJoin(first: a, second: b));
  }
}

class _OutcomeChoice extends StatelessWidget {
  const _OutcomeChoice({required this.selected, required this.onSelected});

  final SeasonOutcome? selected;
  final ValueChanged<SeasonOutcome>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final select = onSelected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepQuestion(l10n.farmerSeasonCloseQuestion),
        for (final (outcome, icon) in const [
          (SeasonOutcome.harvested, OrbitIcons.success),
          (SeasonOutcome.abandoned, OrbitIcons.error),
        ]) ...[
          ChoiceTile(
            icon: icon,
            label: l10n.labelSeasonStatus(outcome.wire),
            selected: outcome == selected,
            onTap: select == null ? null : () => select(outcome),
          ),
          const SizedBox(height: OrbitSpace.s12),
        ],
        const SizedBox(height: OrbitSpace.s4),
        InfoRow(icon: OrbitIcons.warning, text: l10n.farmerSeasonCloseNoUndo),
      ],
    );
  }
}

/// The confirm button, pinned at the bottom.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.saving, required this.onConfirm});

  final bool saving;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        OrbitSpace.s8,
        OrbitSpace.s16,
        OrbitSpace.s16,
      ),
      child: OrbitButton(
        label: context.l10n.farmerFarmCloseSeason,
        icon: OrbitIcons.check,
        size: OrbitButtonSize.hero,
        loading: saving,
        onPressed: onConfirm,
      ),
    ),
  );
}
