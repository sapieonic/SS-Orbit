/// Widgets the sign-in, blocked and Me screens share: the brand mark, a
/// scroll body with a pinned bottom, PIN entry, a password field, note cards
/// and the dev menu button.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../routing/routes.dart';

/// The app's mark: a blue rounded square with the FA icon, the app name and
/// "Field Assistant" (splash, login).
class BrandMark extends StatelessWidget {
  /// Creates the mark.
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(OrbitIcons.person, size: 36, color: scheme.onPrimary),
        ),
        const SizedBox(height: OrbitSpace.s8),
        Semantics(
          header: true,
          child: Text(
            l10n.commonAppName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium!.copyWith(
              fontWeight: OrbitFont.weightExtrabold,
            ),
          ),
        ),
        Text(
          l10n.faAuthRole,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium!.copyWith(
            color: OrbitColors.of(context).textMuted,
          ),
        ),
      ],
    );
  }
}

/// A full screen without the blue header (login, unlock, blocked): dark
/// status bar icons on the page colour, [child] inside the safe area.
class PlainPage extends StatelessWidget {
  /// Creates the page.
  const PlainPage({super.key, required this.child});

  /// The page body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ScreenHeader.overlayStyleFor(scheme.surface),
      child: Scaffold(body: SafeArea(child: child)),
    );
  }
}

/// [content] in a column that scrolls when it does not fit, with [bottom]
/// pushed to the bottom of the screen when it does (the designs' pinned
/// buttons), so nothing overflows at 130% text.
class FillScroll extends StatelessWidget {
  /// Creates the body.
  const FillScroll({
    super.key,
    required this.content,
    this.bottom = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.gap = 14,
  });

  /// The content, top down.
  final List<Widget> content;

  /// Pinned to the bottom when there is room (buttons, notes).
  final List<Widget> bottom;

  /// Space around everything.
  final EdgeInsets padding;

  /// Space between [children].
  final double gap;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: padding,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < content.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                content[i],
              ],
              if (bottom.isNotEmpty) ...[
                SizedBox(height: gap),
                const Spacer(),
                for (var i = 0; i < bottom.length; i++) ...[
                  if (i > 0) const SizedBox(height: OrbitSpace.s8),
                  bottom[i],
                ],
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

/// How a [NoteCard] reads.
enum NoteTone {
  /// Blue: information.
  info,

  /// Amber: a caution.
  warning,

  /// Red: something went wrong or will be lost.
  danger,

  /// Green: done.
  success,
}

/// A tinted card with an icon and text (the HO note, the 72-hours warning,
/// the logout warning). [title] is bold above [text]; [actions] go under.
class NoteCard extends StatelessWidget {
  /// Creates a note.
  const NoteCard({
    super.key,
    required this.text,
    this.title,
    this.tone = NoteTone.info,
    this.icon,
    this.actions,
  });

  /// The note.
  final String text;

  /// Optional bold first line.
  final String? title;

  /// Colour and default icon.
  final NoteTone tone;

  /// Replaces the tone's icon.
  final IconData? icon;

  /// Buttons under the text.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final (OrbitTone t, IconData defaultIcon) = switch (tone) {
      NoteTone.info => (orbit.info, OrbitIcons.info),
      NoteTone.warning => (orbit.warning, OrbitIcons.warning),
      NoteTone.danger => (orbit.danger, OrbitIcons.alert),
      NoteTone.success => (orbit.success, OrbitIcons.success),
    };
    final body = theme.textTheme.bodyMedium!.copyWith(
      color: t.strong,
      fontSize: 14,
      height: 1.45,
    );
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.tint,
          borderRadius: BorderRadius.circular(OrbitRadius.lg),
          border: Border.all(color: t.fg, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      icon ?? defaultIcon,
                      size: OrbitSize.iconMd,
                      color: t.strong,
                    ),
                  ),
                  const SizedBox(width: OrbitSpace.s10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (title != null)
                            TextSpan(
                              text: '$title ',
                              style: const TextStyle(
                                fontWeight: OrbitFont.weightBold,
                              ),
                            ),
                          TextSpan(text: text),
                        ],
                      ),
                      style: body,
                    ),
                  ),
                ],
              ),
              if (actions case final actions?) ...[
                const SizedBox(height: OrbitSpace.s10),
                actions,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A big round tick or icon in a coloured disc (success states, blocked).
class RoundBadge extends StatelessWidget {
  /// Creates the badge.
  const RoundBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 72,
    this.square = false,
  });

  /// The icon.
  final IconData icon;

  /// Disc colour.
  final Color background;

  /// Icon colour.
  final Color foreground;

  /// Diameter.
  final double size;

  /// A rounded square instead of a circle (blocked screens).
  final bool square;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(22) : null,
      ),
      child: Icon(icon, size: size / 2, color: foreground),
    ),
  );
}

/// The PIN part of a screen: [label], the dots, a [hint] (red when [error])
/// and the pad. The screen holds the digits; this only shows them.
class PinEntryView extends StatelessWidget {
  /// Creates the view.
  const PinEntryView({
    super.key,
    required this.label,
    required this.length,
    required this.filled,
    required this.onDigit,
    required this.onDelete,
    this.hint,
    this.error = false,
    this.enabled = true,
    this.leading,
    this.keyHeight = 60,
  });

  /// What to type ("Enter your 4-digit PIN").
  final String label;

  /// Digits in the PIN.
  final int length;

  /// Digits typed.
  final int filled;

  /// A tap on a digit.
  final ValueChanged<String> onDigit;

  /// Delete.
  final VoidCallback onDelete;

  /// Line under the dots.
  final String? hint;

  /// [hint] is an error (red, dots red).
  final bool error;

  /// False while checking.
  final bool enabled;

  /// The key left of 0 (Back on setup).
  final Widget? leading;

  /// Minimum key height.
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium!.copyWith(
            fontWeight: OrbitFont.weightExtrabold,
          ),
        ),
        const SizedBox(height: OrbitSpace.s12),
        Center(
          child: PinDots(
            length: length,
            filled: filled,
            error: error,
            semanticLabel: l10n.faAuthPinEntered(
              filled: filled,
              length: length,
            ),
          ),
        ),
        const SizedBox(height: OrbitSpace.s12),
        Semantics(
          liveRegion: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: Text(
              hint ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                fontSize: 14,
                color: error ? orbit.danger.strong : orbit.textMuted,
                fontWeight: error ? OrbitFont.weightBold : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: OrbitSpace.s12),
        PinPad(
          onDigit: onDigit,
          onDelete: onDelete,
          deleteLabel: l10n.faAuthPinDelete,
          leading: leading,
          enabled: enabled,
          keyHeight: keyHeight,
        ),
      ],
    );
  }
}

/// A labelled password field with a Show / Hide button.
class PasswordField extends StatefulWidget {
  /// Creates the field.
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.errorText,
    this.obscured,
    this.onToggle,
    this.showToggle = true,
    this.focusNode,
  });

  /// The text.
  final TextEditingController controller;

  /// Label above the field.
  final String label;

  /// Autofill hints.
  final Iterable<String> autofillHints;

  /// The keyboard's action key.
  final TextInputAction textInputAction;

  /// The action key was pressed.
  final ValueChanged<String>? onSubmitted;

  /// The text changed.
  final ValueChanged<String>? onChanged;

  /// False while saving.
  final bool enabled;

  /// Error under the field.
  final String? errorText;

  /// Shared hidden state (A1c shows or hides both boxes together); null keeps
  /// its own.
  final bool? obscured;

  /// Called by the Show / Hide button when [obscured] is given.
  final VoidCallback? onToggle;

  /// Shows the Show / Hide button.
  final bool showToggle;

  /// The field's focus.
  final FocusNode? focusNode;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  bool get _obscured => widget.obscured ?? _hidden;

  void _toggle() {
    if (widget.obscured != null) {
      widget.onToggle?.call();
    } else {
      setState(() => _hidden = !_hidden);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final toggle = Semantics(
      button: true,
      label: _obscured ? l10n.faAuthShowPassword : l10n.faAuthHidePassword,
      excludeSemantics: true,
      child: TextButton(
        onPressed: widget.enabled ? _toggle : null,
        style: TextButton.styleFrom(
          minimumSize: const Size(OrbitSize.controlLg, OrbitSize.controlLg),
        ),
        child: Text(_obscured ? l10n.faAuthShow : l10n.faAuthHide),
      ),
    );
    return LabelledField(
      label: widget.label,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        obscureText: _obscured,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          errorText: widget.errorText,
          errorMaxLines: 4,
          suffixIcon: widget.showToggle
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: toggle,
                )
              : null,
        ),
      ),
    );
  }
}

/// A bold [label] above a text field ([child]), as in the designs. Screen
/// readers hear the label on the field itself.
class LabelledField extends StatelessWidget {
  /// Creates the labelled field.
  const LabelledField({super.key, required this.label, required this.child});

  /// The label, e.g. "Login ID".
  final String label;

  /// The field.
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall!
              .copyWith(fontWeight: OrbitFont.weightBold),
        ),
      ),
      const SizedBox(height: OrbitSpace.s6),
      Semantics(label: label, child: child),
    ],
  );
}

/// A small way into the dev menu on the sign-in screens of dev builds, so a
/// mock scenario can be picked before logging in. Not shown elsewhere.
class DevMenuButton extends StatelessWidget {
  /// Creates the button.
  const DevMenuButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.faShellTitleDev,
    icon: Icon(
      OrbitIcons.settings,
      size: OrbitSize.iconMd,
      color: OrbitColors.of(context).textMuted,
    ),
    onPressed: () => context.push(AppRoutes.dev),
  );
}
