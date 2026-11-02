import 'package:flutter/material.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../data/models/enums.dart';
import '../data/models/snapshot.dart';
import 'formatters.dart';

/// A farmer's initials in a circle, coloured by where the farmer stands:
/// green for a farmer who still needs enrolment (self sign-up), grey when HO
/// deactivated them, a darker brown for Premium, the farmer brown otherwise
/// (A2, A8).
///
/// Decorative: the farmer's name is always shown next to it, so screen
/// readers skip it.
class FarmerAvatar extends StatelessWidget {
  /// An avatar from the parts.
  const FarmerAvatar({
    super.key,
    required this.name,
    this.plan = Plan.free,
    this.status = FarmerStatus.active,
    this.size = 44,
    this.outlined = false,
  });

  /// The avatar of [farmer] (initials from the English name).
  FarmerAvatar.of(
    SnapFarmer farmer, {
    super.key,
    this.size = 44,
    this.outlined = false,
  }) : name = farmer.name ?? farmer.nameTe,
       plan = farmer.plan,
       status = farmer.status;

  /// English name, for the initials. A person icon when it has none.
  final String? name;

  /// The farmer's plan.
  final Plan plan;

  /// The farmer's account status.
  final FarmerStatus status;

  /// Diameter.
  final double size;

  /// A white ring, for an avatar on the blue header (A8).
  final bool outlined;

  /// The fill for a farmer with [plan] and [status], with white text on it.
  static Color colorFor(
    BuildContext context, {
    required Plan plan,
    required FarmerStatus status,
  }) {
    final orbit = OrbitColors.of(context);
    return switch ((status, plan)) {
      (FarmerStatus.pendingProfile, _) => orbit.success.fg,
      (FarmerStatus.inactive, _) => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
      (_, Plan.premium) => OrbitFarmerTokens.primaryStrong,
      _ => OrbitFarmerTokens.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onFill = theme.colorScheme.onPrimary;
    final initials = nameInitials(name);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorFor(context, plan: plan, status: status),
          shape: BoxShape.circle,
          border: outlined ? Border.all(color: onFill, width: 2) : null,
        ),
        child: initials == null
            ? Icon(OrbitIcons.person, color: onFill, size: size * 0.5)
            : Text(
                initials,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: theme.textTheme.labelLarge!.copyWith(
                  color: onFill,
                  fontSize: size * 0.34,
                  fontWeight: OrbitFont.weightExtrabold,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
