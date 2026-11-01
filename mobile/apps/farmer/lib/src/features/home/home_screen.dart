import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/farmer_data.dart';
import '../../shared/farmer_text.dart';
import '../../shared/voice.dart';
import 'home_sections.dart';
import 'home_tiles.dart';

/// F2 Home: greeting, the farmer's FA one tap away, the next visit, new
/// advice and the feature tiles.
///
/// Weather (FAR-05) is not shown: there is no feed yet, and the plan hides
/// the card outside dev. A placeholder would only teach farmers to ignore it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(farmerHomeProvider).fresh;

    Future<void> refresh() async {
      ref
        ..invalidate(unreadNoticesCountProvider)
        ..invalidate(cropsProvider);
      try {
        ref.invalidate(farmerHomeProvider);
        await ref.read(farmerHomeProvider.future);
      } on Object {
        // The banner (or the error card) shows what went wrong.
      }
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HomeHeader(home: home.value),
          Expanded(
            child: switch (home) {
              AsyncValue(hasValue: true, :final value?) => RefreshIndicator(
                onRefresh: refresh,
                child: _HomeBody(
                  home: value,
                  refreshError: home.hasError ? home.error : null,
                  onRetry: refresh,
                ),
              ),
              AsyncError(:final error) => ErrorStateCard(
                error: error,
                onRetry: () => ref.invalidate(farmerHomeProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

/// "నమస్కారం, రవి", then village · crop · area of the active plot, and the
/// Listen button. The plan badge sits just under it, at the top of the body:
/// in the header it would squeeze the greeting at 130% text.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.home});

  final FarmerHome? home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final home = this.home;
    const listen = ScreenListenButton(voiceKey: VoiceKeys.farmerHomeVoiceHelp);
    if (home == null) {
      return ScreenHeader(title: l10n.farmerNavHome, listen: listen);
    }
    final language = contentLanguage(context);
    final crops = ref.watch(cropsProvider).fresh.value;
    final village = home.village;
    final plot = _activePlot(home.plots);
    final season = plot?.activeSeason;
    final name = home.farmer.displayName(language);
    return ScreenHeader(
      title: name.isEmpty
          ? l10n.farmerNavHome
          : l10n.farmerHomeGreeting(name: name),
      subtitle: dotJoin(l10n, [
        if (village != null)
          pickText(language, te: village.nameTe, en: village.name),
        if (plot != null && home.plots.length > 1) plotName(l10n, plot.plot),
        if (season != null) cropNameById(crops, season.cropId, language),
        if (plot != null) plotArea(l10n, plot.plot.areaAcres),
      ]),
      listen: listen,
    );
  }
}

/// Everything under the header, in one pull-to-refresh list.
class _HomeBody extends ConsumerWidget {
  const _HomeBody({
    required this.home,
    required this.refreshError,
    required this.onRetry,
  });

  final FarmerHome home;

  /// Set when the last refresh failed and [home] is the saved data.
  final Object? refreshError;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNoticesCountProvider).fresh.value ?? 0;
    final error = refreshError;
    final plan = home.farmer.plan;
    const gap = SizedBox(height: OrbitSpace.s16);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        0,
        OrbitSpace.s16,
        OrbitSpace.s24,
      ),
      children: [
        if (plan != Plan.unknown) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OrbitTag(
              label: context.l10n.labelFarmerPlan(plan.wire),
              tone: OrbitTagTone.highlight,
            ),
          ),
          const SizedBox(height: OrbitSpace.s12),
        ],
        if (error != null) ...[
          _RefreshFailedBanner(error: error, onRetry: onRetry),
          gap,
        ],
        if (home.fa case final fa?)
          HomeFaSection(fa: fa)
        else
          const HomeNoFaCard(),
        if (home.nextVisit case final visit?) ...[
          gap,
          HomeNextVisitCard(visit: visit),
        ],
        if (unread > 0) ...[gap, HomeUnreadAdviceCard(count: unread)],
        if (home.plots.isEmpty) ...[gap, const HomeNoPlotCard()],
        gap,
        const HomeTiles(),
      ],
    );
  }
}

/// Over saved data when a refresh failed: "No internet · showing saved
/// details from 7:00 am", or the error, with Try again and Listen.
class _RefreshFailedBanner extends ConsumerWidget {
  const _RefreshFailedBanner({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final savedAt = ref.watch(homeSavedAtProvider);
    final offline = error is ApiError && (error as ApiError).isNetwork;
    return OrbitBanner(
      kind: offline ? OrbitBannerKind.offline : OrbitBannerKind.error,
      title: offline
          ? l10n.farmerStateOfflineTitle
          : l10n.farmerStateErrorTitle,
      message: offline
          ? (savedAt == null
                ? null
                : l10n.farmerStateOfflineBody(time: toIstWallClock(savedAt)))
          : errorText(context, error),
      action: Wrap(
        spacing: OrbitSpace.s8,
        runSpacing: OrbitSpace.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OrbitButton(
            label: l10n.commonRetry,
            icon: OrbitIcons.refresh,
            variant: OrbitButtonVariant.secondary,
            size: OrbitButtonSize.medium,
            fullWidth: false,
            onPressed: onRetry,
          ),
          // Offline: "No internet, showing the details saved earlier".
          ScreenListenButton(
            voiceKey: offline
                ? VoiceKeys.farmerStateOfflineVoice
                : VoiceKeys.farmerStateErrorVoice,
          ),
        ],
      ),
    );
  }
}

/// The plot Home talks about: the first plot with an active season, else the
/// first plot, else null when the farmer has none.
HomePlot? _activePlot(List<HomePlot> plots) =>
    plots.where((p) => p.activeSeason != null).firstOrNull ?? plots.firstOrNull;
