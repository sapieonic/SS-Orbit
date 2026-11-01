import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/orbit_tokens.g.dart';

/// One-time-code entry drawn as separate boxes (F1, FA consent OTP).
///
/// A single transparent [TextField] sits over the boxes, so the OS can
/// autofill the code (`oneTimeCode` hint, SMS on Android and iOS), long press
/// pastes, and non-digits in pasted text are dropped. [onCompleted] fires
/// once each time the last digit is entered.
class OtpInput extends StatefulWidget {
  /// Creates an OTP input.
  const OtpInput({
    super.key,
    this.length = 6,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onCompleted,
    this.errorText,
    this.semanticLabel,
    this.enabled = true,
    this.autofocus = false,
  }) : assert(length > 0, 'length must be positive');

  /// Number of digits. Defaults to 6.
  final int length;

  /// Holds the digits typed so far.
  final TextEditingController? controller;

  /// Focus node.
  final FocusNode? focusNode;

  /// Called with the digits on every change.
  final ValueChanged<String>? onChanged;

  /// Called with the full code when all [length] digits are entered.
  final ValueChanged<String>? onCompleted;

  /// Error line under the boxes; also turns the borders red.
  final String? errorText;

  /// Label for screen readers, e.g. "OTP", already localised.
  final String? semanticLabel;

  /// Whether the field accepts input.
  final bool enabled;

  /// Focus on first build.
  final bool autofocus;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(OtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      _focusNode.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = _controller.text;
    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;

    Widget box(int i) {
      final active = focused && i == code.length.clamp(0, widget.length - 1);
      final (Color color, double width) = hasError
          ? (scheme.error, 2)
          : active
          ? (scheme.primary, 2)
          : (scheme.outline, 1);
      return Container(
        constraints: const BoxConstraints(minHeight: OrbitSize.controlXxl),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.enabled
              ? scheme.surface
              : scheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
          border: Border.all(color: color, width: width),
        ),
        child: Text(
          i < code.length ? code[i] : '',
          style: theme.textTheme.headlineLarge,
        ),
      );
    }

    final boxes = ExcludeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: OrbitSpace.s8),
              Expanded(child: box(i)),
            ],
          ],
        ),
      ),
    );

    // Invisible field on top of the boxes: takes taps, keyboard input,
    // autofill and paste.
    final field = Semantics(
      label: widget.semanticLabel,
      child: TextSelectionTheme(
        data: const TextSelectionThemeData(selectionColor: Colors.transparent),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.length),
          ],
          onChanged: _handleChanged,
          showCursor: false,
          style: const TextStyle(color: Colors.transparent),
          // No decoration at all. `InputDecoration.collapsed` only clears
          // `border`: the theme's `enabledBorder` and `focusedBorder` still
          // apply and drew one outline around the whole row of boxes. Only
          // the active box shows focus.
          decoration: null,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            boxes,
            Positioned.fill(child: field),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: OrbitSpace.s8),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.errorText!,
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
