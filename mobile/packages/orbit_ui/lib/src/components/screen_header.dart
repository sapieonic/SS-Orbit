import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';

/// Background of a [ScreenHeader].
enum ScreenHeaderTone {
  /// The page background with ink text.
  surface,

  /// The app's primary colour with white text.
  primary,

  /// The dark ink bar with white text.
  inverse,
}

/// The top of every screen: optional back button, a title that wraps, an
/// optional sub-line and a slot for the [ListenButton].
///
/// Put it at the top of the screen body (not in `Scaffold.appBar`): it grows
/// with the text scale instead of clipping Telugu in a fixed-height bar. It
/// pads for the status bar itself and sets the status bar icons to suit its
/// background (see [overlayStyleFor]), so the clock and battery stay visible
/// under edge-to-edge drawing on Android and in iOS dark mode.
///
/// The title always keeps most of the width: [trailing] and [listen]
/// together take at most [actionsMaxWidthFactor] of it. A longer label wraps
/// inside its button, and when both don't fit side by side they stack.
class ScreenHeader extends StatelessWidget {
  /// Creates a header.
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.listen,
    this.trailing,
    this.tone = ScreenHeaderTone.surface,
  });

  /// Screen title (Telugu-first), styled `headlineMedium` (farmer 26/800,
  /// FA 22/700).
  final String title;

  /// Optional sub-line, e.g. "My visits · Plot 1 · Cotton".
  final String? subtitle;

  /// Shows a back button when set. Its tooltip comes from
  /// [MaterialLocalizations], so it is already in the app's language.
  final VoidCallback? onBack;

  /// Slot for a [ListenButton] (inline variant).
  final Widget? listen;

  /// Extra widgets after the title, e.g. an icon button.
  final Widget? trailing;

  /// Background. Defaults to [ScreenHeaderTone.surface].
  final ScreenHeaderTone tone;

  /// Widest share of the header's content width that [trailing] and
  /// [listen] may take, so a long label can't squeeze the title to a few
  /// letters per line.
  static const double actionsMaxWidthFactor = 0.4;

  /// Status bar style over a header of colour [background]: dark icons on a
  /// light background, light icons on a dark one. Only the status bar fields
  /// are set, so the navigation bar keeps whatever the app chose.
  static SystemUiOverlayStyle overlayStyleFor(Color background) {
    final dark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Android: the icons' brightness.
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      // iOS: the bar's brightness (the opposite of its icons).
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final (Color bg, Color fg, Color fgSub) = switch (tone) {
      ScreenHeaderTone.surface => (
        theme.scaffoldBackgroundColor,
        scheme.onSurface,
        scheme.onSurfaceVariant,
      ),
      ScreenHeaderTone.primary => (
        scheme.primary,
        orbit.onPrimaryBar,
        orbit.onPrimaryBar,
      ),
      ScreenHeaderTone.inverse => (
        scheme.inverseSurface,
        orbit.onPrimaryBar,
        orbit.onPrimaryBar,
      ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyleFor(bg),
      child: Material(
        color: bg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              onBack == null ? OrbitSpace.s16 : OrbitSpace.s4,
              OrbitSpace.s8,
              OrbitSpace.s16,
              OrbitSpace.s12,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(OrbitIcons.back),
                      color: fg,
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                    ),
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
                            ),
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: fgSub,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null || listen != null) ...[
                    const SizedBox(width: OrbitSpace.s8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * actionsMaxWidthFactor,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: OrbitSpace.s8,
                        runSpacing: OrbitSpace.s8,
                        children: [?trailing, ?listen],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
