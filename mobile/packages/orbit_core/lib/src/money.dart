/// Indian money formatting. The API sends money as integer paise
/// (`mrp_paise: 45000` is ₹450).
library;

/// Formats [paise] as rupees with Indian digit grouping.
///
/// Whole rupees drop the paise: `formatInr(10000000)` is `₹1,00,000`,
/// `formatInr(360050)` is `₹3,600.50`. Set [alwaysShowPaise] for `₹450.00`.
/// Negative amounts get a leading minus: `-₹180`.
String formatInr(int paise, {bool alwaysShowPaise = false}) {
  final negative = paise < 0;
  final abs = paise.abs();
  final rupees = abs ~/ 100;
  final rest = abs % 100;
  final buf = StringBuffer(negative ? '-₹' : '₹')..write(groupIndian(rupees));
  if (rest != 0 || alwaysShowPaise) {
    buf
      ..write('.')
      ..write(rest.toString().padLeft(2, '0'));
  }
  return buf.toString();
}

/// Groups a non-negative integer the Indian way: last three digits, then
/// pairs (`1234567` is `12,34,567`).
String groupIndian(int value) {
  if (value < 0) return '-${groupIndian(-value)}';
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final parts = <String>[];
  for (var end = head.length; end > 0; end -= 2) {
    parts.insert(0, head.substring(end - 2 < 0 ? 0 : end - 2, end));
  }
  return '${parts.join(',')},$tail';
}
