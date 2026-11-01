import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/orbit_tokens.g.dart';

/// Keeps the field to the 10 digits of an Indian mobile number.
///
/// Non-digits are dropped. An edit that would make the number longer than 10
/// digits is refused (the field keeps its old value), so an 11th digit typed
/// by mistake never shifts the number into another valid one: the OTP would
/// go to someone else.
///
/// The one exception is pasted or autofilled text (more than one digit
/// arriving in a single edit) that is a whole number with a recognised
/// prefix: "+91 98765 43210", "919876543210", "09876543210" and
/// "0091 98765 43210" all become "9876543210". Anything else too long is
/// refused.
class IndianMobileNumberFormatter extends TextInputFormatter {
  /// Creates the formatter.
  const IndianMobileNumberFormatter();

  /// Digits in an Indian mobile number without the country code.
  static const int length = 10;

  /// Prefixes stripped from a pasted or autofilled number: country code
  /// with the international `00` or `+` (the `+` is already dropped),
  /// country code alone, and the domestic trunk `0`.
  static const List<String> _prefixes = ['0091', '91', '0'];

  static final RegExp _nonDigit = RegExp('[^0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(_nonDigit, '');
    if (digits.length > length) {
      final pasted = _insertedDigits(oldValue.text, newValue.text) > 1;
      final number = pasted ? _withoutPrefix(digits) : null;
      if (number == null) return oldValue;
      digits = number;
    }
    if (digits == newValue.text) return newValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }

  /// [digits] without a recognised prefix, or null when it is not exactly
  /// one of [_prefixes] followed by 10 digits.
  static String? _withoutPrefix(String digits) {
    for (final prefix in _prefixes) {
      if (digits.length == length + prefix.length &&
          digits.startsWith(prefix)) {
        return digits.substring(prefix.length);
      }
    }
    return null;
  }

  /// Digits in the text this edit inserted: what is left of [newText] once
  /// the part it shares with [oldText] at both ends is taken off. Typing
  /// inserts one digit; a paste or autofill usually inserts many.
  static int _insertedDigits(String oldText, String newText) {
    final shorter = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    var start = 0;
    while (start < shorter &&
        oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
      start++;
    }
    var end = 0;
    while (end < shorter - start &&
        oldText.codeUnitAt(oldText.length - 1 - end) ==
            newText.codeUnitAt(newText.length - 1 - end)) {
      end++;
    }
    return newText
        .substring(start, newText.length - end)
        .replaceAll(_nonDigit, '')
        .length;
  }
}

/// Indian mobile number input: fixed "+91" prefix, 10 digits, phone keypad,
/// and the `telephoneNumber` autofill hint (F1).
///
/// The value in [controller] is the 10 digits only.
class PhoneField extends StatelessWidget {
  /// Creates a phone field.
  const PhoneField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.countryCode = '+91',
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
  });

  /// Holds the 10 digits.
  final TextEditingController? controller;

  /// Focus node.
  final FocusNode? focusNode;

  /// Floating label, already localised.
  final String? label;

  /// Hint shown when empty.
  final String? hint;

  /// Helper line under the field.
  final String? helperText;

  /// Error line; also turns the border red.
  final String? errorText;

  /// Prefix shown before the digits. Defaults to "+91".
  final String countryCode;

  /// Called with the digits on every change.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard action is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field accepts input.
  final bool enabled;

  /// Focus on first build.
  final bool autofocus;

  /// Keyboard action button.
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final digitStyle = textTheme.titleLarge!;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: const [IndianMobileNumberFormatter()],
      style: digitStyle,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: OrbitSpace.s16,
            end: OrbitSpace.s8,
          ),
          child: Text(countryCode, style: digitStyle),
        ),
        prefixIconConstraints: const BoxConstraints(
          minHeight: OrbitSize.controlLg,
        ),
      ),
    );
  }
}
