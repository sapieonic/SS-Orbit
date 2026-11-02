import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../data/data.dart';
import '../local/local.dart';
import '../routing/routes.dart';
import 'formatters.dart';
import 'navigation.dart';

/// The blue bar at the top of every signed-in FA screen (A2 to A11): an
/// optional back arrow, an optional [leading] avatar, the title and a
/// sub-line that wrap, then [actions], the [SyncPill] and the [MeAvatar].
///
/// Put it at the top of the screen body, not in `Scaffold.appBar`, so it
/// grows with Telugu text at 130% instead of clipping. It pads for the
/// status bar and makes the status bar icons light.
class FaHeader extends StatelessWidget {
  /// Creates the header.
  const FaHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.back = false,
    this.onBack,
    this.backLabel,
    this.leading,
    this.actions = const [],
    this.showSync = true,
    this.showMe = false,
  });

  /// Screen title.
  final String title;

  /// Sub-line, e.g. "Kondapur · 46 farmers · nearest first".
  final String? subtitle;

  /// Shows a back arrow that pops, or goes to Farmers when there is
  /// nothing to pop ([goBack]).
  final bool back;

  /// Shows a back arrow that does this instead (leave a flow, confirm
  /// first).
  final VoidCallback? onBack;

  /// Screen reader label of the back arrow when "Back" alone is unclear
  /// ("Back to farmers"); Flutter's localised "Back" otherwise.
  final String? backLabel;

  /// After the back arrow, e.g. the farmer's [FarmerAvatar] on Farmer 360.
  final Widget? leading;

  /// Before the sync pill: an icon button (search) or a small pill button
  /// (Add on the calendar). Keep them 48 dp tall.
  final List<Widget> actions;

  /// Shows the sync pill. Off on Sync itself.
  final bool showSync;

  /// Shows the FA's initials, which open Me (the tab roots).
  final bool showMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final fg = orbit.onPrimaryBar;
    final hasBack = back || onBack != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ScreenHeader.overlayStyleFor(scheme.primary),
      child: Material(
        color: scheme.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              hasBack ? OrbitSpace.s4 : OrbitSpace.s16,
              OrbitSpace.s12,
              OrbitSpace.s12,
              OrbitSpace.s12,
            ),
            child: Row(
              children: [
                if (hasBack)
                  IconButton(
                    onPressed: onBack ?? () => goBack(context),
                    icon: const Icon(OrbitIcons.back),
                    color: fg,
                    tooltip:
                        backLabel ??
                        MaterialLocalizations.of(context).backButtonTooltip,
                  ),
                if (leading case final leading?) ...[
                  leading,
                  const SizedBox(width: OrbitSpace.s8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.textTheme.headlineMedium!.copyWith(
                            color: fg,
                            fontWeight: OrbitFont.weightExtrabold,
                          ),
                        ),
                      ),
                      if (subtitle case final subtitle?)
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: scheme.primaryContainer,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                for (final action in actions) ...[
                  const SizedBox(width: OrbitSpace.s4),
                  action,
                ],
                if (showSync) ...[
                  const SizedBox(width: OrbitSpace.s6),
                  const SyncPill(),
                ],
                if (showMe) ...[
                  const SizedBox(width: OrbitSpace.s6),
                  const MeAvatar(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the sync pill shows: records waiting, records that need the FA
/// (conflicts, rejected), and whether a sync is running.
typedef SyncPillStatus = ({int queued, int needsYou, bool running});

/// The header's sync status, from the engine's [syncStateProvider].
final syncPillStatusProvider = Provider<SyncPillStatus>((ref) {
  final s = ref.watch(syncStateProvider);
  return (
    queued: s.queuedCount,
    needsYou: s.conflicts.length + s.rejected.length,
    running: s.running,
  );
});

/// The header's cloud and count of records waiting to sync (A2 to A11). Tap
/// opens Sync. Reads out what it means ("3 records waiting to sync", "All
/// records synced"), never just the number. Records that need the FA (a
/// conflict, a rejected change) turn the cloud into an alert.
class SyncPill extends ConsumerWidget {
  /// Creates the pill.
  const SyncPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final status = ref.watch(syncPillStatusProvider);
    final (IconData icon, String label) = status.needsYou > 0
        ? (OrbitIcons.alert, l10n.faShellSyncNeedsYou(count: status.needsYou))
        : status.running
        ? (OrbitIcons.upload, l10n.faShellSyncRunning)
        : status.queued > 0
        ? (OrbitIcons.sync, l10n.faShellSyncWaiting(count: status.queued))
        : (OrbitIcons.synced, l10n.faShellSyncAllSynced);
    const shape = StadiumBorder();
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: orbit.onPrimaryBarFill,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () => openPage(context, AppRoutes.sync),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: OrbitSize.controlLg,
              minWidth: OrbitSize.controlLg,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: OrbitSize.iconMd, color: orbit.onPrimaryBar),
                  const SizedBox(width: OrbitSpace.s6),
                  Text(
                    '${status.queued}',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: orbit.onPrimaryBar,
                      fontSize: 15,
                      fontWeight: OrbitFont.weightExtrabold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The signed-in FA's initials on the header; tap opens Me.
class MeAvatar extends ConsumerWidget {
  /// Creates the avatar.
  const MeAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = ref.watch(sessionProvider.select((s) => s.fa?.name));
    final initials = nameInitials(name);
    return Semantics(
      button: true,
      label: context.l10n.faShellMe,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => openPage(context, AppRoutes.me),
        radius: OrbitSize.controlLg / 2,
        child: SizedBox.square(
          dimension: OrbitSize.controlLg,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
              ),
              child: initials == null
                  ? Icon(OrbitIcons.person, color: scheme.primary)
                  : Text(
                      initials,
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: scheme.primary,
                        fontWeight: OrbitFont.weightExtrabold,
                        height: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
