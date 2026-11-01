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
import 'advice_text.dart';
import 'dealers_section.dart';
import 'visits_providers.dart';

/// The advice for one issue of one visit: the Shanmukha product and dose
/// (F8a, without cashback, pack or MRP: farmer SKU detail is backlog), or the
/// salt to ask for at the shop (F8b), with a big Call FA button.
///
/// Shows only what the visit data says; never another brand.
class AdviceScreen extends ConsumerWidget {
  /// Creates the screen for issue [issueIndex] of visit [visitId].
  const AdviceScreen({
    super.key,
    required this.visitId,
    required this.issueIndex,
  });

  /// The visit.
  final String visitId;

  /// Position of the issue in the visit's issue list.
  final int issueIndex;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(Routes.visits);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final visit = ref.watch(visitByIdProvider(visitId)).fresh;
    final loaded = visit.value;
    final advice =
        loaded != null && issueIndex >= 0 && issueIndex < loaded.issues.length
        ? loaded.issues[issueIndex]
        : null;
    final type = advice == null ? null : adviceTypeOf(advice);

    final fa = loaded?.fa;
    final subtitle = loaded == null
        ? null
        : fa == null
        ? l10n.commonDateShort(date: toIstWallClock(loaded.visitedAt))
        : l10n.farmerAdviceAdvisedBy(
            name: fa.displayName(language),
            date: toIstWallClock(loaded.visitedAt),
          );

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            // Loading, pending or not found: a title that promises neither
            // a product nor a salt.
            title: switch (type) {
              AdviceType.product => l10n.farmerAdviceProductTitle,
              AdviceType.saltOnly => l10n.farmerAdviceSaltTitle,
              AdviceType.pending || null => l10n.farmerAdviceTitle,
            },
            subtitle: subtitle,
            onBack: () => _back(context),
            listen: ScreenListenButton(
              voiceKey: switch (type) {
                AdviceType.product => VoiceKeys.farmerAdviceVoiceHelpProduct,
                AdviceType.saltOnly => VoiceKeys.farmerAdviceVoiceHelpSalt,
                AdviceType.pending => VoiceKeys.farmerAdviceVoiceHelpPending,
                null => VoiceKeys.farmerVisitsVoiceHelp,
              },
            ),
          ),
          Expanded(
            // Loaded but no such visit or issue: AsyncValueView only knows
            // non-null data, so not-found is decided here.
            child: visit.hasValue && advice == null
                ? NotFoundCard(onBack: () => _back(context))
                : AsyncValueView(
                    value: visit,
                    onRetry: () {
                      ref
                        ..invalidate(visitsControllerProvider)
                        ..invalidate(visitByIdProvider(visitId));
                    },
                    data: (_) => _AdviceBody(visit: loaded!, advice: advice!),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdviceBody extends ConsumerWidget {
  const _AdviceBody({required this.visit, required this.advice});

  final FarmerVisit visit;
  final FarmerAdvice advice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final language = ref.watch(appLanguageProvider);
    final home = ref.watch(farmerHomeProvider).fresh.value;
    final (name, otherName) = issueNames(l10n, language, advice);
    final severity = orbitSeverity(advice.severity);
    final plot = _plotOf(home, visit.plotId);
    final plotLabel = plot == null ? '' : plotName(l10n, plot);
    final stage = pickText(
      language,
      te: visit.stageNameTe,
      en: visit.stageName,
    );
    final type = adviceTypeOf(advice);

    return ListView(
      padding: const EdgeInsets.all(OrbitSpace.s16),
      children: [
        BilingualText(
          name,
          secondary: otherName,
          primaryStyle: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: OrbitSpace.s8),
        Wrap(
          spacing: OrbitSpace.s8,
          runSpacing: OrbitSpace.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (severity != null)
              SeverityPill(
                severity: severity,
                label: l10n.labelSeverity(advice.severity.wire),
              ),
            if (plotLabel.isNotEmpty)
              OrbitTag(label: plotLabel, icon: OrbitIcons.location),
            if (stage.isNotEmpty)
              OrbitTag(
                label: l10n.farmerVisitsStage(stage: stage),
                icon: OrbitIcons.crop,
              ),
          ],
        ),
        const SizedBox(height: OrbitSpace.s16),
        switch (type) {
          AdviceType.product => AdviceResult.product(
            heading: l10n.farmerVisitsShanmukhaProduct,
            name: shopName(
              language,
              te: advice.productNameTe,
              en: advice.productName,
            ),
            dose: doseText(language, advice),
            note: l10n.farmerAdviceShowAtShop,
          ),
          AdviceType.saltOnly => AdviceResult.saltOnly(
            heading: l10n.farmerAdviceNoProduct,
            secondaryHeading: l10n.farmerAdviceAskAtShopLabel,
            name: shopName(
              language,
              te: advice.saltNameTe,
              en: advice.saltName,
            ),
            dose: doseText(language, advice),
            note: l10n.farmerAdviceAskAtShopBody,
          ),
          AdviceType.pending => StateCard(
            icon: OrbitIcons.pending,
            tone: StateCardTone.info,
            title: l10n.farmerVisitsAdvicePending,
          ),
        },
        const SizedBox(height: OrbitSpace.s16),
        const FaCallButton(),
        if (type == AdviceType.product)
          if ((advice.skuId, plot?.pin) case (final sku?, final pin?)) ...[
            const SizedBox(height: OrbitSpace.s24),
            // Dealers near the plot the advice is for. Device location is not
            // wired yet, and the farmer API's village (FarmerVillage) has no
            // lat/lng, so the plot pin from Home is the only honest location.
            // A plot without a pin gets no dealer list rather than a guess.
            DealersSection(query: (near: pin, skuId: sku)),
          ],
      ],
    );
  }
}

/// The plot [plotId] from Home, or null when Home is not loaded or does not
/// list it (archived).
Plot? _plotOf(FarmerHome? home, String plotId) {
  if (home == null) return null;
  for (final hp in home.plots) {
    if (hp.plot.id == plotId) return hp.plot;
  }
  return null;
}
