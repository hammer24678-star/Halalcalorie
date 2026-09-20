// num_input.dart — parse numbers the way people actually type them.
//
// A phone keyboard hands a text field whatever it produced: a decimal comma
// ("70,5" on French / Turkish / Indonesian keyboards), the Arabic decimal
// separator ("٫"), or Arabic-Indic / Persian digits ("٧٠", "۷۰"). Plain
// double.tryParse rejects all of those, so the value was silently dropped.

/// Rewrites [input] into something double.tryParse understands.
String normalizeNumberText(String input) {
  final b = StringBuffer();
  for (final r in input.trim().runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      b.writeCharCode(0x30 + (r - 0x0660)); // ٠-٩  Arabic-Indic digits
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      b.writeCharCode(0x30 + (r - 0x06F0)); // ۰-۹  Persian digits
    } else if (r == 0x066B || r == 0x002C) {
      b.write('.'); // ٫ or ,  -> decimal point
    } else if (r == 0x066C || r == 0x0020 || r == 0x00A0 || r == 0x202F) {
      continue; // thousands separator / spaces
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// Null for empty / unreadable input (and for NaN / Infinity).
double? parseDouble(String? input) {
  if (input == null) return null;
  final d = double.tryParse(normalizeNumberText(input));
  return (d == null || !d.isFinite) ? null : d;
}

/// Like [parseDouble] but rounds ("250.5" -> 251); null when unreadable.
int? parseInt(String? input) => parseDouble(input)?.round();
