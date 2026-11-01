import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../routing/routes.dart';
import '../../shared/voice.dart';

/// Home's feature grid. Calendar and Pests work today; the Phase 2/3
/// features show a padlock (FAR-06) so farmers see what is coming, and
/// explain themselves in a sheet when tapped.
class HomeTiles extends StatelessWidget {
  /// Creates the grid.
  const HomeTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final soon = l10n.commonComingSoon;

    Widget locked(IconData icon, String label) => IconTile(
      icon: icon,
      label: label,
      locked: true,
      lockedSemanticLabel: soon,
      onTap: () => showComingSoonSheet(context, icon: icon, feature: label),
    );

    return IconTileGrid(
      children: [
        IconTile(
          icon: OrbitIcons.cropCalendar,
          label: l10n.farmerHomeTileCalendar,
          onTap: () => context.go(Routes.calendar),
        ),
        IconTile(
          icon: OrbitIcons.pests,
          label: l10n.farmerHomeTilePests,
          onTap: () => context.go(Routes.visits),
        ),
        locked(OrbitIcons.mic, l10n.farmerHomeTileAsk),
        locked(OrbitIcons.soilTest, l10n.farmerHomeTileSoilTest),
        locked(OrbitIcons.schemes, l10n.farmerHomeTileSchemes),
        locked(OrbitIcons.services, l10n.farmerHomeTileServices),
        locked(OrbitIcons.premium, l10n.farmerHomeTilePremium),
      ],
    );
  }
}

/// "This service is coming soon · we will tell you by SMS", with Listen and
/// one OK button.
Future<void> showComingSoonSheet(
  BuildContext context, {
  required IconData icon,
  required String feature,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _ComingSoonSheet(icon: icon, feature: feature),
);

class _ComingSoonSheet extends StatelessWidget {
  const _ComingSoonSheet({required this.icon, required this.feature});

  final IconData icon;
  final String feature;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OrbitSpace.s20,
          0,
          OrbitSpace.s20,
          OrbitSpace.s20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: OrbitSize.iconXl, color: scheme.primary),
                const SizedBox(width: OrbitSpace.s12),
                Expanded(
                  child: Text(feature, style: theme.textTheme.titleLarge),
                ),
                Icon(
                  OrbitIcons.lock,
                  color: scheme.onSurfaceVariant,
                  semanticLabel: l10n.commonComingSoon,
                ),
              ],
            ),
            const SizedBox(height: OrbitSpace.s16),
            Text(
              l10n.farmerHomeLockedTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: OrbitSpace.s4),
            Text(
              l10n.farmerHomeLockedBody,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: OrbitSpace.s16),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: ScreenListenButton(
                voiceKey: VoiceKeys.farmerHomeLockedVoice,
              ),
            ),
            const SizedBox(height: OrbitSpace.s16),
            OrbitButton(
              label: l10n.commonOk,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
