import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../data/data.dart';
import 'async_view.dart';
import 'farmer_data.dart';
import 'launch.dart';

/// The big "Call Suresh" button (FAR-07: the FA is one tap away).
///
/// Uses the assigned FA from Home. With no FA yet, or when Home could not
/// load, it calls the helpline instead so the farmer is never stuck.
class FaCallButton extends ConsumerWidget {
  /// Creates the button.
  const FaCallButton({super.key, this.size = OrbitButtonSize.hero});

  /// Button height.
  final OrbitButtonSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final home = ref.watch(farmerHomeProvider).fresh;
    if (home.isLoading && !home.hasValue) {
      return OrbitButton(
        label: l10n.farmerStateCallFa,
        variant: OrbitButtonVariant.call,
        size: size,
        loading: true,
        onPressed: null,
      );
    }
    final fa = home.value?.fa;
    if (fa == null) {
      return OrbitButton(
        label: l10n.farmerStateNoFaAction,
        icon: OrbitIcons.helpline,
        variant: OrbitButtonVariant.call,
        size: size,
        onPressed: () => callHelpline(context, ref),
      );
    }
    return OrbitButton(
      label: l10n.commonCallName(name: fa.displayName(language)),
      variant: OrbitButtonVariant.call,
      size: size,
      onPressed: () => callPhone(context, ref, fa.phone),
    );
  }
}

/// The quiet "Helpline · 1800 123 4567" line at the bottom of the sign-in
/// screens; a tap opens the dialer.
class HelplineLink extends ConsumerWidget {
  /// Creates the line.
  const HelplineLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Center(
      child: TextButton.icon(
        onPressed: () => callHelpline(context, ref),
        icon: const Icon(OrbitIcons.helpline, size: OrbitSize.iconMd),
        label: Text(
          l10n.commonDotJoin(
            first: l10n.commonHelpline,
            second: formatHelpline(helplinePhone),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// The big green "Call helpline" button, with the number on a second line.
class CallHelplineButton extends ConsumerWidget {
  /// Creates the button.
  const CallHelplineButton({super.key, this.size = OrbitButtonSize.large});

  /// Button height.
  final OrbitButtonSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OrbitButton(
    label: context.l10n.farmerLoginCallHelpline,
    secondaryLabel: formatHelpline(helplinePhone),
    variant: OrbitButtonVariant.call,
    size: size,
    onPressed: () => callHelpline(context, ref),
  );
}
