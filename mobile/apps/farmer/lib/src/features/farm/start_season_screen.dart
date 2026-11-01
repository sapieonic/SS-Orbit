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
import 'widgets/plot_state_card.dart';
import 'widgets/season_steps.dart';

/// Start a crop season on a plot (F10), one question per step (NFR-03):
/// season (today's preselected), crop, sowing date (optional, not in the
/// future), previous crop (optional). Saves with
/// `POST /v1/farmer/me/plots/{plot_id}/seasons`.
///
/// `active_season_exists` (someone started one meanwhile) goes back to My
/// farm, which then shows that season.
class StartSeasonScreen extends ConsumerStatefulWidget {
  const StartSeasonScreen({super.key, required this.plotId});

  final String plotId;

  @override
  ConsumerState<StartSeasonScreen> createState() => _StartSeasonScreenState();
}

enum _Step { season, crop, sowing, previousCrop }

class _StartSeasonScreenState extends ConsumerState<StartSeasonScreen> {
  var _step = _Step.season;
  String? _seasonCode;
  String? _cropId;
  LocalDate? _sowingDate;
  String? _previousCropId;
  bool _saving = false;

  void _back() {
    if (_saving) return;
    if (_step == _Step.season) {
      context.pop();
    } else {
      setState(() => _step = _Step.values[_step.index - 1]);
    }
  }

  void _next() => setState(() => _step = _Step.values[_step.index + 1]);

  Future<void> _save(String seasonCode) async {
    final cropId = _cropId;
    if (cropId == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final edits = ref.read(farmerEditsProvider);
    setState(() => _saving = true);
    try {
      // Refreshes Home (also on active_season_exists), even if this screen
      // is gone by the time the server answers.
      await edits.startSeason(
        plotId: widget.plotId,
        seasonCode: seasonCode,
        cropId: cropId,
        sowingDate: _sowingDate,
        previousCropId: _previousCropId,
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.farmerSeasonStartStarted)));
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
      if (e is ApiError && e.code == ApiErrorCode.activeSeasonExists) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final crops = ref.watch(cropsProvider).fresh;
    final home = ref.watch(farmerHomeProvider).fresh;
    final plot = home.value?.plots
        .where((p) => p.plot.id == widget.plotId)
        .firstOrNull;
    // Waiting for both, or one failed: the usual spinner or error card.
    final loading = switch ((crops, home)) {
      (AsyncValue(hasValue: true), AsyncValue(hasValue: true)) => null,
      (AsyncError(), _) => crops,
      (_, AsyncError()) => home,
      (AsyncValue(hasValue: false), _) => crops,
      _ => home,
    };

    if (loading != null) {
      return _Frame(
        child: AsyncValueView(
          value: loading,
          onRetry: () => ref
            ..invalidate(cropsProvider)
            ..invalidate(farmerHomeProvider),
          data: (_) => const SizedBox.shrink(),
        ),
      );
    }
    if (plot == null) {
      return const _Frame(
        child: PlotStateCard(
          errorCode: ApiErrorCode.notFound,
          voiceKey: VoiceKeys.farmerSeasonStartVoiceHelp,
        ),
      );
    }
    if (plot.activeSeason != null && !_saving) {
      return const _Frame(
        child: PlotStateCard(
          errorCode: ApiErrorCode.activeSeasonExists,
          voiceKey: VoiceKeys.farmerSeasonStartVoiceHelp,
        ),
      );
    }

    final list = crops.requireValue;
    final codes = list.seasonCodes;
    final season = _seasonCode ?? codes.current;
    final language = contentLanguage(context);
    final today = LocalDate.todayIst(ref.watch(clockProvider));
    final step = _step.index + 1;
    final stepLabel = l10n.commonStepOf(step: step, total: _Step.values.length);

    final (Widget body, Widget action) = switch (_step) {
      _Step.season => (
        SeasonStep(
          codes: codes,
          selected: season,
          onSelected: (code) => setState(() => _seasonCode = code),
        ),
        _nextButton(l10n, enabled: true),
      ),
      _Step.crop => (
        CropStep(
          question: l10n.farmerSeasonStartWhichCrop,
          crops: list.items,
          language: language,
          selected: _cropId,
          onSelected: (id) => setState(() => _cropId = id),
        ),
        _nextButton(l10n, enabled: _cropId != null),
      ),
      _Step.sowing => (
        SowingStep(
          date: _sowingDate,
          today: today,
          onChanged: (date) => setState(() => _sowingDate = date),
        ),
        _nextButton(l10n, enabled: true),
      ),
      _Step.previousCrop => (
        CropStep(
          question: l10n.farmerSeasonStartPreviousCrop,
          crops: list.items,
          language: language,
          selected: _previousCropId,
          onSelected: (id) => setState(() => _previousCropId = id),
          skipLabel: l10n.farmerSeasonStartSkip,
        ),
        OrbitButton(
          label: l10n.farmerFarmStartSeason,
          icon: OrbitIcons.crop,
          size: OrbitButtonSize.hero,
          loading: _saving,
          onPressed: _cropId == null ? null : () => _save(season),
        ),
      ),
    };

    return PopScope(
      canPop: _step == _Step.season && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: StepLayout(
        title: l10n.farmerSeasonStartTitle,
        subtitle: dotJoin(l10n, [plotName(l10n, plot.plot), stepLabel]),
        step: step,
        totalSteps: _Step.values.length,
        stepLabel: stepLabel,
        listen: const ScreenListenButton(
          voiceKey: VoiceKeys.farmerSeasonStartVoiceHelp,
        ),
        onBack: _back,
        action: action,
        child: body,
      ),
    );
  }

  Widget _nextButton(OrbitLocalizations l10n, {required bool enabled}) =>
      OrbitButton(
        label: l10n.commonNext,
        size: OrbitButtonSize.hero,
        onPressed: enabled ? _next : null,
      );
}

/// Header and body for the loading, error and "can't start here" states.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        ScreenHeader(
          title: context.l10n.farmerSeasonStartTitle,
          onBack: () => context.pop(),
          listen: const ScreenListenButton(
            voiceKey: VoiceKeys.farmerSeasonStartVoiceHelp,
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
