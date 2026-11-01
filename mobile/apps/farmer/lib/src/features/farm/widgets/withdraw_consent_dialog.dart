import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';
import '../../../shared/voice.dart';

/// Asks before withdrawing [purpose]. For the programme consent it warns, in
/// the danger colour, that advice and FA visits may stop.
Future<bool> confirmWithdrawConsent(
  BuildContext context,
  ConsentPurpose purpose,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final danger = OrbitColors.of(context).danger;
      return AlertDialog(
        title: Text(l10n.farmerConsentsWithdrawTitle),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.labelConsentPurpose(purpose.wire),
              style: theme.textTheme.titleMedium,
            ),
            if (purpose == ConsentPurpose.programme) ...[
              const SizedBox(height: OrbitSpace.s12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: danger.tint,
                  borderRadius: BorderRadius.circular(OrbitRadius.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(OrbitSpace.s12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(OrbitIcons.warning, color: danger.strong),
                      const SizedBox(width: OrbitSpace.s8),
                      Expanded(
                        child: Text(
                          l10n.farmerConsentsWithdrawProgrammeWarning,
                          style: theme.textTheme.bodyLarge!.copyWith(
                            color: danger.strong,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: OrbitSpace.s12),
            Text(l10n.farmerConsentsWithdrawBody),
            const SizedBox(height: OrbitSpace.s12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ScreenListenButton(
                voiceKey: purpose == ConsentPurpose.programme
                    ? VoiceKeys.farmerConsentsWithdrawProgrammeVoice
                    : VoiceKeys.farmerConsentsWithdrawVoice,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          OrbitButton(
            label: l10n.farmerConsentsWithdraw,
            variant: OrbitButtonVariant.danger,
            size: OrbitButtonSize.medium,
            fullWidth: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
