import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

/// "Not synced yet": on a farmer, plot or visit saved on this phone whose
/// change HO doesn't have yet (the territory's pending entity ids).
class PendingSyncTag extends StatelessWidget {
  /// Creates the tag.
  const PendingSyncTag({super.key});

  @override
  Widget build(BuildContext context) => StatusPill(
    label: context.l10n.faCommonNotSynced,
    tone: OrbitStatusTone.warning,
    icon: OrbitIcons.cloudOff,
  );
}
