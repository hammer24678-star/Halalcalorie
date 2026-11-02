// barcode_util.dart — HalalCalorie v62 (PATCH_V62)
// Pure Dart. A camera misread is the usual reason a scan returns the wrong
// product, so a code is only looked up when its GTIN check digit adds up.
class BarcodeUtil {
  BarcodeUtil._();

  /// Digits only, no spaces or separators.
  static String clean(String raw) => raw.replaceAll(RegExp(r'\s+'), '');

  /// True for a well-formed GTIN-8 / GTIN-12 (UPC-A) / GTIN-13 (EAN-13) /
  /// GTIN-14 whose check digit is correct.
  static bool isValid(String raw) {
    final s = clean(raw);
    if (!RegExp(r'^\d+$').hasMatch(s)) return false;
    if (s.length != 8 && s.length != 12 && s.length != 13 && s.length != 14) {
      return false;
    }
    var sum = 0;
    // Weights 3,1,3,1... starting from the digit next to the check digit.
    for (var i = 0; i < s.length - 1; i++) {
      final digit = s.codeUnitAt(s.length - 2 - i) - 48;
      sum += digit * (i.isEven ? 3 : 1);
    }
    final check = (10 - sum % 10) % 10;
    return check == s.codeUnitAt(s.length - 1) - 48;
  }
}
