import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../shared/voice.dart';

/// One card, one action for a season screen that cannot go on: the plot or
/// season is gone, or it changed meanwhile (another season started, the
/// season was already closed). The text is the API error's; the action goes
/// back to My farm, which shows the current state.
class PlotStateCard extends StatelessWidget {
  /// Creates the card for the API error [errorCode].
  const PlotStateCard({
    super.key,
    required this.errorCode,
    required this.voiceKey,
  });

  /// An `ApiErrorCode`, e.g. `season_not_active`.
  final String errorCode;

  /// The screen's voice prompt.
  final String voiceKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: StateCard(
          icon: OrbitIcons.info,
          tone: StateCardTone.info,
          title: l10n.describeError(errorCode),
          action: OrbitButton(
            label: l10n.commonBack,
            icon: OrbitIcons.back,
            variant: OrbitButtonVariant.secondary,
            onPressed: () => context.pop(),
          ),
          listen: ScreenListenButton(voiceKey: voiceKey),
        ),
      ),
    );
  }
}
