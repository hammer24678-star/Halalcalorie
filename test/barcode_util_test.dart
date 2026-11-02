// barcode_util_test.dart - PATCH_V62
import 'package:flutter_test/flutter_test.dart';
import 'package:halalcalorie/core/barcode_util.dart';

void main() {
  group('BarcodeUtil', () {
    test('accepts real EAN-13, UPC-A and EAN-8 codes', () {
      expect(BarcodeUtil.isValid('5449000000996'), isTrue);
      expect(BarcodeUtil.isValid('737628064502'), isTrue);
      expect(BarcodeUtil.isValid('96385074'), isTrue);
      expect(BarcodeUtil.isValid('6221000000041'), isTrue);
    });
    test('rejects a wrong check digit (a misread)', () {
      expect(BarcodeUtil.isValid('5449000000995'), isFalse);
      expect(BarcodeUtil.isValid('737628064503'), isFalse);
      expect(BarcodeUtil.isValid('96385075'), isFalse);
    });
    test('rejects wrong lengths and non-digits', () {
      expect(BarcodeUtil.isValid(''), isFalse);
      expect(BarcodeUtil.isValid('12345'), isFalse);
      expect(BarcodeUtil.isValid('54490000009961'), isFalse);
      expect(BarcodeUtil.isValid('abc4900000996'), isFalse);
      expect(BarcodeUtil.isValid('https://example.com'), isFalse);
    });
    test('ignores surrounding whitespace', () {
      expect(BarcodeUtil.isValid(' 5449000000996 '), isTrue);
      expect(BarcodeUtil.clean(' 5449 000000996\n'), '5449000000996');
    });
  });
}
