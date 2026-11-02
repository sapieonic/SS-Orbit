import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/helpline.dart';
import '../auth/auth_widgets.dart';

/// A12 HO removed this phone; its data was wiped (`device_revoked` or a
/// heartbeat `wipe`).
///
/// The wipe also forgot who was signed in, so the text does not name the
/// login. Call HO, or "Log in with a new password" (`startOver`) once HO
/// has given one.
class RemovedScreen extends ConsumerWidget {
  /// Creates the screen.
  const RemovedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    return PlainPage(
      child: FillScroll(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
        content: [
          Center(
            child: RoundBadge(
              icon: OrbitIcons.lock,
              square: true,
              background: orbit.danger.tint,
              foreground: orbit.danger.strong,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              l10n.faShellTitleRemoved,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall!.copyWith(
                fontWeight: OrbitFont.weightExtrabold,
              ),
            ),
          ),
          Text(
            l10n.faBlockedRemovedBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: orbit.textMuted,
              height: 1.45,
            ),
          ),
          NoteCard(text: l10n.faBlockedRemovedNote),
        ],
        bottom: [
          OrbitButton(
            label: l10n.faAuthCallHo(
              phone: formatHelpline(ref.watch(hoHelplineProvider)),
            ),
            icon: OrbitIcons.phone,
            onPressed: () => callHo(context, ref),
          ),
          OrbitButton(
            label: l10n.faBlockedNewLogin,
            variant: OrbitButtonVariant.secondary,
            onPressed: () => ref.read(sessionProvider.notifier).startOver(),
          ),
        ],
      ),
    );
  }
}
