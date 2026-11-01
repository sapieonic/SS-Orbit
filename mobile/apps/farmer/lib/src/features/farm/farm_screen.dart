import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/farmer_data.dart';
import '../../shared/farmer_text.dart';
import '../../shared/launch.dart';
import '../../shared/voice.dart';
import 'widgets/edit_name_dialog.dart';
import 'widgets/farm_row.dart';
import 'widgets/farm_settings.dart';
import 'widgets/plot_card.dart';
import 'widgets/profile_card.dart';

/// F10 My farm: the farmer's profile (name, phone, village, plan), language,
/// plots with their seasons, consents, their FA, the helpline and sign out.
///
/// Reads `GET /v1/farmer/me` through [farmerHomeProvider]; pull to refresh.
/// SMS / WhatsApp preference (no endpoint yet), KYC and wallet (Phase 2) are
/// left out on purpose.
class FarmScreen extends ConsumerWidget {
  const FarmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final home = ref.watch(farmerHomeProvider).fresh;
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: l10n.farmerFarmTitle,
            listen: const ScreenListenButton(
              voiceKey: VoiceKeys.farmerFarmVoiceHelp,
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: home,
              onRetry: () => ref.invalidate(farmerHomeProvider),
              data: (home) => _FarmBody(home: home),
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmBody extends ConsumerWidget {
  const _FarmBody({required this.home});

  final FarmerHome home;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    ref
      ..invalidate(farmerHomeProvider)
      ..invalidate(cropsProvider);
    try {
      await ref.read(farmerHomeProvider.future);
    } on Object catch (e) {
      // The old details stay on screen; say why they did not refresh.
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = contentLanguage(context);
    final crops = ref.watch(cropsProvider).fresh.value;
    final fa = home.fa;
    const gap = SizedBox(height: OrbitSpace.s16);
    return RefreshIndicator(
      onRefresh: () => _refresh(context, ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(OrbitSpace.s16),
        children: [
          ProfileCard(
            home: home,
            language: language,
            onEditName: () => showEditNameDialog(
              context,
              farmer: home.farmer,
              language: language,
            ),
            onPhotoFailed: () {
              if (context.mounted) {
                ref.read(photoUrlRefreshProvider).photoFailed(home);
              }
            },
          ),
          gap,
          LanguageCard(language: language),
          const SizedBox(height: OrbitSpace.s24),
          SectionHeader(title: l10n.farmerFarmPlots),
          const SizedBox(height: OrbitSpace.s8),
          for (final plot in home.plots) ...[
            PlotCard(
              plot: plot,
              crop: switch (plot.activeSeason) {
                final season? => crops?.byId(season.cropId),
                null => null,
              },
              language: language,
              onStartSeason: () =>
                  context.push(Routes.startSeason(plot.plot.id)),
              onCloseSeason: () =>
                  context.push(Routes.closeSeason(plot.activeSeason!.id)),
            ),
            const SizedBox(height: OrbitSpace.s12),
          ],
          OrbitButton(
            label: l10n.farmerFarmAddPlot,
            icon: OrbitIcons.add,
            variant: OrbitButtonVariant.secondary,
            onPressed: () => context.push(Routes.addPlot),
          ),
          const SizedBox(height: OrbitSpace.s24),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                FarmRow(
                  icon: OrbitIcons.consent,
                  label: l10n.farmerFarmConsents,
                  secondaryLabel: l10n.farmerFarmConsentsHint,
                  onTap: () => context.push(Routes.consents),
                ),
                const Divider(height: 1),
                FarmRow(
                  icon: OrbitIcons.person,
                  label: l10n.farmerFarmYourFa,
                  secondaryLabel: fa == null
                      ? l10n.farmerStateNoFaTitle
                      : pickText(language, te: fa.nameTe, en: fa.name),
                  onTap: () => context.push(Routes.fas),
                ),
                const Divider(height: 1),
                FarmRow(
                  icon: OrbitIcons.helpline,
                  label: l10n.farmerFarmHelp,
                  secondaryLabel: l10n.commonDotJoin(
                    first: l10n.commonHelpline,
                    second: formatHelpline(helplinePhone),
                  ),
                  onTap: () => callHelpline(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: OrbitSpace.s24),
          const SignOutButton(),
          gap,
        ],
      ),
    );
  }
}
