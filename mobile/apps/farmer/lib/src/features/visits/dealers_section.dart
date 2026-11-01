import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/launch.dart';
import 'advice_text.dart';
import 'visits_providers.dart';

/// "దగ్గర దుకాణాలు": dealers near the plot that stock the advised product,
/// each with a Call button. A secondary part of the advice screen, so its
/// loading and error states stay small and inline.
class DealersSection extends ConsumerWidget {
  /// Creates the section for [query].
  const DealersSection({super.key, required this.query});

  /// Where to look and which product.
  final DealerQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dealers = ref.watch(nearbyDealersProvider(query));
    final Widget body = switch (dealers) {
      AsyncValue(hasValue: true, :final value?) when value.isEmpty => Text(
        l10n.farmerAdviceNoDealers,
        style: theme.textTheme.bodyMedium,
      ),
      AsyncValue(hasValue: true, :final value?) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final dealer in value) ...[
            _DealerTile(dealer: dealer),
            const SizedBox(height: OrbitSpace.s8),
          ],
        ],
      ),
      AsyncError(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(errorText(context, error), style: theme.textTheme.bodyMedium),
          const SizedBox(height: OrbitSpace.s8),
          OrbitButton(
            label: l10n.commonRetry,
            icon: OrbitIcons.refresh,
            variant: OrbitButtonVariant.secondary,
            size: OrbitButtonSize.medium,
            onPressed: () => ref.invalidate(nearbyDealersProvider(query)),
          ),
        ],
      ),
      _ => Center(
        child: Semantics(
          label: l10n.commonLoading,
          child: const CircularProgressIndicator(),
        ),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.farmerAdviceNearbyDealers),
        const SizedBox(height: OrbitSpace.s8),
        body,
      ],
    );
  }
}

class _DealerTile extends ConsumerWidget {
  const _DealerTile({required this.dealer});

  final NearbyDealer dealer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final (name, otherName) = bilingual(
      language,
      te: dealer.nameTe,
      en: dealer.name,
      fallback: dealer.name,
    );
    final distance = l10n.farmerAdviceDealerDistance(
      km: NumberFormat('0.0', l10n.localeName).format(dealer.distanceM / 1000),
    );
    final phone = dealer.phone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s12),
        child: InfoRow(
          icon: OrbitIcons.shop,
          text: name,
          secondaryText: otherName == null
              ? distance
              : l10n.commonDotJoin(first: otherName, second: distance),
          trailing: phone == null
              ? null
              : OrbitButton(
                  label: l10n.commonCall,
                  variant: OrbitButtonVariant.call,
                  size: OrbitButtonSize.medium,
                  fullWidth: false,
                  onPressed: () => callPhone(context, ref, phone),
                ),
        ),
      ),
    );
  }
}
