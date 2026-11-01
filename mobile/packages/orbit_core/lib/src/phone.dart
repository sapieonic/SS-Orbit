/// Indian mobile numbers. Mirrors `backend/internal/platform/phone`, so the
/// app shows and compares numbers exactly as the server stores them.
library;

/// Normalises an Indian mobile number to E.164 (`+91XXXXXXXXXX`), or returns
/// null when it is not one.
///
/// Accepts the usual ways people type it: `98480 12345`, `098480-12345`,
/// `+91 98480 12345`, `919848012345`, `0091 9848012345`. Mobile numbers have
/// 10 digits starting with 6-9. The API normalises too, so sending what the
/// user typed is fine; use this for validation and display.
String? normalizeIndianMobile(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  final digits = StringBuffer();
  var plus = false;
  for (final rune in s.runes) {
    final c = String.fromCharCode(rune);
    if (rune >= 0x30 && rune <= 0x39) {
      digits.write(c);
    } else if (c == '+' && !plus && digits.isEmpty) {
      plus = true; // A leading plus is fine; the country code is checked below.
    } else if (!' -().'.contains(c)) {
      return null;
    }
  }
  var d = digits.toString();
  if (d.length == 11 && d.startsWith('0')) {
    d = d.substring(1);
  } else if (d.length == 12 && d.startsWith('91')) {
    d = d.substring(2);
  } else if (d.length == 14 && d.startsWith('0091')) {
    d = d.substring(4);
  } else if (d.length != 10) {
    return null;
  }
  if (!'6789'.contains(d[0])) return null;
  return '+91$d';
}

/// True when [input] is a valid Indian mobile number in any accepted format.
bool isValidIndianMobile(String input) => normalizeIndianMobile(input) != null;

/// Hides all but the last four digits: `+919848012345` -> `+91******2345`
/// (same as the server's `phone_masked`). Input that does not normalise is
/// returned fully masked.
String maskPhone(String phone) {
  final e164 = normalizeIndianMobile(phone);
  if (e164 == null) return '****';
  return '${e164.substring(0, 3)}${'*' * (e164.length - 7)}'
      '${e164.substring(e164.length - 4)}';
}

/// The 10 national digits split for reading: `+919876543210` -> `98765 43210`.
/// Input that does not normalise is returned unchanged.
String formatIndianMobile(String phone) {
  final e164 = normalizeIndianMobile(phone);
  if (e164 == null) return phone;
  return '${e164.substring(3, 8)} ${e164.substring(8)}';
}
