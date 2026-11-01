import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';
import '../../../shared/async_view.dart';
import '../../../shared/farmer_data.dart';
import '../../../shared/farmer_text.dart';
import '../../../shared/launch.dart';
import '../../../shared/voice.dart';
import '../farm_providers.dart';

/// Longest plot label the API takes (`AddPlotRequest.label`).
const _maxPlotLabelLength = 60;

/// Largest area one field may have. The API takes up to 10000 acres; a
/// smallholder's field is far smaller, so more than this is a typing slip.
const maxPlotAcres = 100;

/// Add plot, step 1: an optional name for the field.
class PlotLabelStep extends StatelessWidget {
  /// Creates the name step.
  const PlotLabelStep({
    super.key,
    required this.controller,
    required this.onDone,
  });

  /// The name being typed.
  final TextEditingController controller;

  /// Called when the keyboard's next key is pressed.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepQuestion(l10n.farmerPlotAddLabelTitle),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            LengthLimitingTextInputFormatter(_maxPlotLabelLength),
          ],
          onSubmitted: (_) => onDone(),
          decoration: InputDecoration(
            hintText: l10n.farmerPlotAddLabelHint,
            prefixIcon: const Icon(OrbitIcons.location),
          ),
        ),
      ],
    );
  }
}

/// Add plot, step 2: where the plot is. The village location while GPS is
/// not wired (see [plotPinProvider]); one card with one action when there is
/// no location to use.
class PlotLocationStep extends ConsumerWidget {
  /// Creates the location step over the [pin] lookup.
  const PlotLocationStep({super.key, required this.pin});

  /// The pin lookup ([plotPinProvider]).
  final AsyncValue<LatLng?> pin;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (pin) {
    // No village location and no other plot to borrow one from.
    AsyncValue(hasValue: true, value: null) => const _NoLocationCard(),
    _ => AsyncValueView(
      value: pin,
      onRetry: () => ref.invalidate(plotPinProvider),
      data: (_) => const _VillagePin(),
    ),
  };
}

/// The village the plot will be pinned at, and why.
class _VillagePin extends ConsumerWidget {
  const _VillagePin();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final village = ref.watch(farmerHomeProvider).fresh.value?.village;
    final language = contentLanguage(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepQuestion(
          l10n.farmerPlotAddVillagePinTitle,
          helper: l10n.farmerPlotAddVillagePinBody,
        ),
        if (village != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(OrbitSpace.s16),
              child: InfoRow(
                icon: OrbitIcons.location,
                text: pickText(language, te: village.nameTe, en: village.name),
                secondaryText: pickText(
                  language,
                  te: village.mandalNameTe,
                  en: village.mandalName,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One card, one action: call the FA (or the helpline without one), who can
/// add the plot with its real location.
class _NoLocationCard extends ConsumerWidget {
  const _NoLocationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fa = ref.watch(farmerHomeProvider).fresh.value?.fa;
    return StateCard(
      icon: OrbitIcons.location,
      tone: StateCardTone.warning,
      title: l10n.farmerPlotAddNoLocation,
      action: OrbitButton(
        label: fa == null ? l10n.farmerStateNoFaAction : l10n.farmerStateCallFa,
        variant: OrbitButtonVariant.call,
        icon: OrbitIcons.phone,
        onPressed: () => fa == null
            ? callHelpline(context, ref)
            : callPhone(context, ref, fa.phone),
      ),
      listen: const ScreenListenButton(
        voiceKey: VoiceKeys.farmerPlotAddVoiceHelpVillagePin,
      ),
    );
  }
}

/// Add plot, step 3: the area as acres and guntas, with the inline [error].
class PlotAreaStep extends StatelessWidget {
  /// Creates the area step.
  const PlotAreaStep({
    super.key,
    required this.acres,
    required this.guntas,
    required this.error,
    required this.enabled,
  });

  /// Whole acres.
  final TextEditingController acres;

  /// Guntas, 0-39.
  final TextEditingController guntas;

  /// Why the area is not valid, or null.
  final String? error;

  /// False while saving.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    InputDecoration field(String label) => InputDecoration(labelText: label);
    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter('$maxPlotAcres'.length),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepQuestion(
          l10n.farmerPlotAddAreaTitle,
          helper: l10n.farmerPlotAddGuntasHint,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: acres,
                enabled: enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: digits,
                style: theme.textTheme.headlineSmall,
                decoration: field(l10n.farmerPlotAddAcres),
              ),
            ),
            const SizedBox(width: OrbitSpace.s12),
            Expanded(
              child: TextField(
                controller: guntas,
                enabled: enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                style: theme.textTheme.headlineSmall,
                decoration: field(l10n.farmerPlotAddGuntas),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: OrbitSpace.s8),
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
