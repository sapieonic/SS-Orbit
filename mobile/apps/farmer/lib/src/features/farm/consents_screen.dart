import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/voice.dart';
import 'farm_providers.dart';
import 'widgets/withdraw_consent_dialog.dart';

/// Consents (F10): who can see what. One card per purpose (programme, soil
/// partner, schemes and finance, loyalty) with what it is for, its state
/// (agreed, withdrawn, not asked yet) and one action: Agree or Withdraw.
///
/// Withdrawing asks first. Withdrawing `programme` warns that advice may
/// stop: the server then leaves the farmer out of promotional crop
/// advisories and HO targeting (visit advice and service messages still
/// come; the account stays active). The farmer can agree again here.
class ConsentsScreen extends ConsumerWidget {
  const ConsentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final consents = ref.watch(farmConsentsProvider).fresh;
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: l10n.farmerConsentsTitle,
            subtitle: l10n.farmerConsentsSubtitle,
            onBack: () => context.pop(),
            listen: const ScreenListenButton(
              voiceKey: VoiceKeys.farmerConsentsVoiceHelp,
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: consents,
              onRetry: () => ref.invalidate(farmConsentsProvider),
              data: (list) => _ConsentList(consents: list),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentList extends ConsumerWidget {
  const _ConsentList({required this.consents});

  final List<CurrentConsent> consents;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    ref.invalidate(farmConsentsProvider);
    try {
      await ref.read(farmConsentsProvider.future);
    } on Object catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final shown = consents
        .where((c) => c.purpose != ConsentPurpose.unknown)
        .toList();
    return RefreshIndicator(
      onRefresh: () => _refresh(context, ref),
      child: shown.isEmpty
          // The server lists every purpose, so an empty list means it could
          // not say: one card to load it again.
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(OrbitSpace.s16),
              children: [
                StateCard(
                  icon: OrbitIcons.consent,
                  title: l10n.farmerConsentsEmpty,
                  action: OrbitButton(
                    label: l10n.commonRetry,
                    icon: OrbitIcons.refresh,
                    variant: OrbitButtonVariant.secondary,
                    onPressed: () => ref.invalidate(farmConsentsProvider),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(OrbitSpace.s16),
              itemCount: shown.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: OrbitSpace.s12),
              itemBuilder: (_, i) => _ConsentCard(consent: shown[i]),
            ),
    );
  }
}

class _ConsentCard extends ConsumerStatefulWidget {
  const _ConsentCard({required this.consent});

  final CurrentConsent consent;

  @override
  ConsumerState<_ConsentCard> createState() => _ConsentCardState();
}

class _ConsentCardState extends ConsumerState<_ConsentCard> {
  bool _busy = false;

  Future<void> _change({required bool granted}) async {
    final purpose = widget.consent.purpose;
    if (!granted && !await confirmWithdrawConsent(context, purpose)) return;
    if (!mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(farmConsentsProvider.notifier)
          .setConsent(purpose, granted: granted);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.farmerConsentSaved)));
    } on Object catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = widget.consent;
    final granted = c.granted;
    final (String state, OrbitStatusTone tone) = switch (granted) {
      true => (l10n.labelConsentState('granted'), OrbitStatusTone.success),
      false => (l10n.labelConsentState('withdrawn'), OrbitStatusTone.danger),
      null => (l10n.labelConsentState('never_asked'), OrbitStatusTone.neutral),
    };
    final updated = switch (c.updatedAt) {
      final at? => toIstWallClock(at),
      null => null,
    };
    final method = c.method;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _icon(c.purpose),
                  size: OrbitSize.iconXl,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: OrbitSpace.s12),
                Expanded(
                  child: BilingualText(
                    l10n.labelConsentPurpose(c.purpose.wire),
                    secondary: _description(l10n, c.purpose),
                    primaryStyle: theme.textTheme.titleMedium,
                    secondaryStyle: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: OrbitSpace.s12),
            StatusPill(label: state, tone: tone),
            if (updated != null) ...[
              const SizedBox(height: OrbitSpace.s4),
              Text(
                method == null || method == ConsentMethod.unknown
                    ? l10n.farmerConsentsChangedOn(date: updated)
                    : l10n.commonDotJoin(
                        first: l10n.farmerConsentsChangedOn(date: updated),
                        second: l10n.labelConsentMethod(method.wire),
                      ),
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: OrbitSpace.s12),
            if (granted == true)
              OrbitButton(
                label: l10n.farmerConsentsWithdraw,
                variant: OrbitButtonVariant.secondary,
                size: OrbitButtonSize.medium,
                loading: _busy,
                onPressed: () => _change(granted: false),
              )
            else
              OrbitButton(
                label: l10n.farmerConsentsAgree,
                icon: OrbitIcons.check,
                variant: OrbitButtonVariant.secondary,
                size: OrbitButtonSize.medium,
                loading: _busy,
                onPressed: () => _change(granted: true),
              ),
          ],
        ),
      ),
    );
  }
}

IconData _icon(ConsentPurpose purpose) => switch (purpose) {
  ConsentPurpose.programme => OrbitIcons.crop,
  ConsentPurpose.soilPartner => OrbitIcons.soilTest,
  ConsentPurpose.schemesFinance => OrbitIcons.schemes,
  ConsentPurpose.loyalty => OrbitIcons.wallet,
  ConsentPurpose.unknown => OrbitIcons.consent,
};

String? _description(OrbitLocalizations l10n, ConsentPurpose purpose) =>
    switch (purpose) {
      ConsentPurpose.programme => l10n.farmerConsentsDescProgramme,
      ConsentPurpose.soilPartner => l10n.farmerConsentsDescSoilPartner,
      ConsentPurpose.schemesFinance => l10n.farmerConsentsDescSchemesFinance,
      ConsentPurpose.loyalty => l10n.farmerConsentsDescLoyalty,
      ConsentPurpose.unknown => null,
    };
