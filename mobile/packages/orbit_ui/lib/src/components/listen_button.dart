import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../tokens/orbit_tokens.g.dart';
import 'icon_label.dart';

/// Playback state shown by a [ListenButton]. The app (orbit_voice) owns the
/// audio; this widget only draws the state.
enum ListenState {
  /// Ready to play.
  idle,

  /// Fetching or preparing audio.
  loading,

  /// Audio is playing; a tap usually stops it.
  playing,

  /// No audio for this content (for example dynamic text without TTS).
  unavailable,
}

/// The speaker button every farmer screen carries (NFR-01).
///
/// Purely presentational: pass the [state] and an [onPressed] handler. Pass
/// a [label] that fits the state (for example "వినండి" when idle and
/// "ఆపండి" while playing); the widget never supplies text of its own.
///
/// Two looks:
/// - [ListenButton.new]: an inline 48 dp pill for headers and cards.
/// - [ListenButton.floating]: the dark 56 dp floating pill from the
///   wireframes, for `Scaffold.floatingActionButton`.
///
/// In [ListenState.unavailable] the button looks muted but still calls
/// [onPressed] if given, so the app can explain why there is no audio.
class ListenButton extends StatelessWidget {
  /// Creates the inline variant.
  const ListenButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.state = ListenState.idle,
    this.secondaryLabel,
  }) : _floating = false;

  /// Creates the floating dark pill variant.
  const ListenButton.floating({
    super.key,
    required this.label,
    required this.onPressed,
    this.state = ListenState.idle,
    this.secondaryLabel,
  }) : _floating = true;

  /// Visible label, already localised.
  final String label;

  /// Optional English sub-line.
  final String? secondaryLabel;

  /// Tap handler; null disables the button.
  final VoidCallback? onPressed;

  /// Current playback state.
  final ListenState state;

  final bool _floating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (Color bg, Color fg) = switch ((_floating, state)) {
      (true, ListenState.unavailable) => (
        scheme.inverseSurface,
        scheme.onInverseSurface.withValues(alpha: 0.72),
      ),
      (true, ListenState.playing) => (scheme.primary, scheme.onPrimary),
      (true, _) => (scheme.inverseSurface, scheme.onInverseSurface),
      (false, ListenState.unavailable) => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      (false, ListenState.playing) => (scheme.primary, scheme.onPrimary),
      (false, _) => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };

    final iconSize = _floating ? OrbitSize.iconLg : OrbitSize.iconMd;
    final Widget icon = switch (state) {
      ListenState.loading => SizedBox.square(
        dimension: iconSize,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
      ),
      ListenState.playing => Icon(OrbitIcons.stop, size: iconSize, color: fg),
      ListenState.unavailable => Icon(
        OrbitIcons.listenUnavailable,
        size: iconSize,
        color: fg,
      ),
      ListenState.idle => Icon(OrbitIcons.listen, size: iconSize, color: fg),
    };

    final textTheme = theme.textTheme;
    final content = IconLabel(
      leading: icon,
      label: label,
      style: textTheme.labelLarge!.copyWith(color: fg),
      secondary: secondaryLabel,
      secondaryStyle: textTheme.labelSmall!.copyWith(color: fg),
      textAlign: TextAlign.start,
    );

    const shape = StadiumBorder();
    final material = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: _floating ? OrbitSize.controlXl : OrbitSize.controlLg,
            minWidth: OrbitSize.controlLg,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _floating ? OrbitSpace.s20 : OrbitSpace.s16,
              vertical: OrbitSpace.s4,
            ),
            child: content,
          ),
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: _floating
            ? DecoratedBox(
                decoration: const ShapeDecoration(
                  shape: shape,
                  shadows: OrbitElevation.e3,
                ),
                child: material,
              )
            : material,
      ),
    );
  }
}
