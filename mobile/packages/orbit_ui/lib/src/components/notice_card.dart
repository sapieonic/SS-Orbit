import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../tokens/orbit_tokens.g.dart';
import 'orbit_tag.dart';

/// An advisory notice in the farmer's inbox (F5): source tag, time, title,
/// body and actions such as a `ListenButton`.
///
/// [pinned] notices get a primary border and a pin tag; [unread] ones a dot
/// and a heavier title. Give [unreadLabel] so screen readers hear "new".
class NoticeCard extends StatelessWidget {
  /// Creates a notice card.
  const NoticeCard({
    super.key,
    required this.source,
    required this.title,
    this.meta,
    this.body,
    this.secondaryBody,
    this.pinned = false,
    this.pinnedLabel,
    this.unread = false,
    this.unreadLabel,
    this.actions = const [],
    this.onTap,
  }) : assert(!pinned || pinnedLabel != null, 'pinned needs pinnedLabel');

  /// Source tag text, e.g. "షణ్ముఖ", "HO", "CIV".
  final String source;

  /// Line next to the tag, e.g. "Shanmukha · 2 h ago".
  final String? meta;

  /// Notice title.
  final String title;

  /// Notice body.
  final String? body;

  /// Optional English line under the body.
  final String? secondaryBody;

  /// Pinned state.
  final bool pinned;

  /// Text of the pin tag, e.g. "PINNED".
  final String? pinnedLabel;

  /// Unread state.
  final bool unread;

  /// Read by screen readers on the unread dot, already localised.
  final String? unreadLabel;

  /// Buttons under the body (Listen, WhatsApp share, ...).
  final List<Widget> actions;

  /// Tap on the card (open the notice).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final header = Wrap(
      spacing: OrbitSpace.s8,
      runSpacing: OrbitSpace.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (unread)
          Semantics(
            label: unreadLabel,
            child: SizedBox.square(
              dimension: OrbitSpace.s10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        OrbitTag(label: source),
        if (meta != null)
          Text(
            meta!,
            style: textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        if (pinned)
          OrbitTag(
            label: pinnedLabel!,
            tone: OrbitTagTone.primary,
            icon: OrbitIcons.pin,
          ),
      ],
    );

    const radius = BorderRadius.all(Radius.circular(OrbitRadius.lg));
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: pinned
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(OrbitSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: OrbitSpace.s8),
              Text(
                title,
                style: textTheme.titleMedium!.copyWith(
                  fontWeight: unread ? OrbitFont.weightExtrabold : null,
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: OrbitSpace.s4),
                Text(body!, style: textTheme.bodyMedium),
              ],
              if (secondaryBody != null)
                Text(
                  secondaryBody!,
                  style: textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: OrbitSpace.s12),
                Wrap(
                  spacing: OrbitSpace.s8,
                  runSpacing: OrbitSpace.s8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
