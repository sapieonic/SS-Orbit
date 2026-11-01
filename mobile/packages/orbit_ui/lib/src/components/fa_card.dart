import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';
import 'orbit_button.dart';
import 'orbit_tag.dart';

/// A Field Assistant: avatar, name, sub-lines, an optional "your FA" tag and
/// Call / WhatsApp actions (F2 Home, F3 Look for FAs).
///
/// The avatar shows [image] when given, else [initials], else a person icon.
class FaCard extends StatelessWidget {
  /// Creates an FA card.
  const FaCard({
    super.key,
    required this.name,
    this.initials,
    this.image,
    this.subtitle,
    this.detail,
    this.tag,
    this.verified = false,
    this.highlighted = false,
    this.callLabel,
    this.onCall,
    this.whatsAppLabel,
    this.onWhatsApp,
    this.onTap,
  }) : assert(onCall == null || callLabel != null, 'onCall needs callLabel'),
       assert(
         onWhatsApp == null || whatsAppLabel != null,
         'onWhatsApp needs whatsAppLabel',
       );

  /// FA name, e.g. "సురేష్".
  final String name;

  /// Up to two letters for the avatar, e.g. "SK".
  final String? initials;

  /// Photo; wins over [initials].
  final ImageProvider? image;

  /// First sub-line, e.g. "Verified Shanmukha FA · 2.1 km".
  final String? subtitle;

  /// Second sub-line, e.g. coverage or a note.
  final String? detail;

  /// Tag above the name, e.g. "మీ FA".
  final String? tag;

  /// Adds a verified badge before [subtitle] (decorative; say "Verified"
  /// in the text too).
  final bool verified;

  /// Primary-coloured border, for the farmer's own FA.
  final bool highlighted;

  /// Call button text, e.g. "కాల్".
  final String? callLabel;

  /// Call handler; shows the Call button when set.
  final VoidCallback? onCall;

  /// WhatsApp button text.
  final String? whatsAppLabel;

  /// WhatsApp handler; shows the WhatsApp button when set.
  final VoidCallback? onWhatsApp;

  /// Tap on the card body.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final subStyle = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final avatar = ExcludeSemantics(
      child: CircleAvatar(
        radius: OrbitSize.avatarMd / 2,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        backgroundImage: image,
        child: image != null
            ? null
            : initials != null
            ? Text(
                initials!,
                style: theme.textTheme.titleSmall!.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              )
            : const Icon(OrbitIcons.person),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tag != null) ...[
          OrbitTag(label: tag!, tone: OrbitTagTone.primary),
          const SizedBox(height: OrbitSpace.s4),
        ],
        Text(name, style: theme.textTheme.titleMedium),
        if (subtitle != null)
          Text.rich(
            TextSpan(
              children: [
                if (verified)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: OrbitSpace.s4,
                      ),
                      child: Icon(
                        OrbitIcons.verified,
                        size: OrbitSize.iconSm,
                        color: orbit.success.fg,
                      ),
                    ),
                  ),
                TextSpan(text: subtitle),
              ],
            ),
            style: subStyle,
          ),
        if (detail != null) Text(detail!, style: subStyle),
      ],
    );

    final actions = [
      if (onCall != null)
        Expanded(
          child: OrbitButton(
            label: callLabel!,
            onPressed: onCall,
            variant: OrbitButtonVariant.call,
            size: OrbitButtonSize.medium,
          ),
        ),
      if (onWhatsApp != null)
        Expanded(
          child: OrbitButton(
            label: whatsAppLabel!,
            onPressed: onWhatsApp,
            variant: OrbitButtonVariant.secondary,
            size: OrbitButtonSize.medium,
            icon: OrbitIcons.whatsApp,
          ),
        ),
    ];

    const radius = BorderRadius.all(Radius.circular(OrbitRadius.lg));
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: highlighted
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(OrbitSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(width: OrbitSpace.s12),
                  Expanded(child: info),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: OrbitSpace.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: OrbitSpace.s8),
                      actions[i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
