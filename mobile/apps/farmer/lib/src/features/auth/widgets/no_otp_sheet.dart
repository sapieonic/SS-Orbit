import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../shared/call_buttons.dart';
import '../../../shared/voice.dart';

/// "OTP not received?": the helpline, since a voice OTP call is not built
/// yet (plan, F1 row). One message, one action.
Future<void> showNoOtpSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => const _NoOtpSheet(),
);

class _NoOtpSheet extends StatelessWidget {
  const _NoOtpSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OrbitSpace.s16,
          0,
          OrbitSpace.s16,
          OrbitSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.farmerLoginNoOtp, style: theme.textTheme.titleLarge),
            const SizedBox(height: OrbitSpace.s8),
            Text(l10n.farmerLoginNoOtpHelp, style: theme.textTheme.bodyLarge),
            const SizedBox(height: OrbitSpace.s12),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: ScreenListenButton(
                voiceKey: VoiceKeys.farmerLoginVoiceHelpNoOtp,
              ),
            ),
            const SizedBox(height: OrbitSpace.s20),
            const CallHelplineButton(size: OrbitButtonSize.hero),
            const SizedBox(height: OrbitSpace.s8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonClose),
            ),
          ],
        ),
      ),
    );
  }
}
