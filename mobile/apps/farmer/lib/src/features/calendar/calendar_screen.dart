import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/farmer_data.dart';
import '../../shared/farmer_text.dart';
import '../../shared/voice.dart';
import 'calendar_model.dart';
import 'calendar_view.dart';

/// F11 Crop calendar (phase 1b): the crop's stages with today's stage
/// marked, "day 123 of about 160", and a note that tasks and reminders come
/// later (the calendar module is not built).
///
/// With several plots in season the farmer picks one with chips; with none
/// they are sent to My farm to start a season.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String? _plotId;

  Future<void> _refresh() async {
    try {
      await Future.wait([
        ref.refresh(farmerHomeProvider.future),
        ref.refresh(cropsProvider.future),
      ]);
    } on Object catch (error) {
      // The calendar on screen stays; say why it didn't refresh.
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  void _retry() {
    ref
      ..invalidate(farmerHomeProvider)
      ..invalidate(cropsProvider);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final home = ref.watch(farmerHomeProvider).fresh;
    final crops = ref.watch(cropsProvider).fresh;

    final Widget body;
    String? subtitle;
    if (home.value case final h? when crops.hasValue) {
      final plots = seasonPlots(h);
      final plot =
          plots.where((p) => p.plot.id == _plotId).firstOrNull ??
          plots.firstOrNull;
      if (plot == null) {
        body = _NoSeason(onRefresh: _refresh);
      } else {
        final calendar = CalendarPlot.of(plot, crops.requireValue);
        subtitle = dotJoin(l10n, [
          plotName(l10n, plot.plot),
          if (calendar.crop case final crop?)
            cropName(crop, contentLanguage(context)),
        ]);
        body = RefreshIndicator(
          onRefresh: _refresh,
          child: CalendarView(
            calendar: calendar,
            seasonPlots: plots,
            crops: crops.requireValue,
            onPlotSelected: (id) => setState(() => _plotId = id),
          ),
        );
      }
    } else if (home.error ?? crops.error case final error?) {
      body = ErrorStateCard(error: error, onRetry: _retry);
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: l10n.farmerCalendarTitle,
            subtitle: subtitle,
            onBack: _back,
            listen: const ScreenListenButton(
              voiceKey: VoiceKeys.farmerCalendarVoiceHelp,
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// No plot in season: one card, one action (start a season in My farm).
class _NoSeason extends StatelessWidget {
  const _NoSeason({required this.onRefresh});

  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(OrbitSpace.s16),
        children: [
          StateCard(
            icon: OrbitIcons.cropCalendar,
            title: l10n.farmerCalendarNoSeason,
            action: OrbitButton(
              label: l10n.farmerFarmStartSeason,
              icon: OrbitIcons.crop,
              onPressed: () => context.go(Routes.farm),
            ),
          ),
        ],
      ),
    );
  }
}
