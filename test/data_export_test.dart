// data_export_test.dart - v66
// The CSV field writer is the only pure part of the export; the rest reads
// the database. These cover quoting and the spreadsheet-formula guard.
import 'package:flutter_test/flutter_test.dart';
import 'package:halalcalorie/core/data_export.dart';

void main() {
  group('DataExport.field', () {
    test('plain text, Arabic text, null and empty pass through', () {
      expect(DataExport.field('Rice'), 'Rice');
      expect(DataExport.field('كشري'), 'كشري');
      expect(DataExport.field(null), '');
      expect(DataExport.field(''), '');
    });
    test('commas, quotes and line breaks are quoted', () {
      expect(DataExport.field('Rice, white'), '"Rice, white"');
      expect(DataExport.field('5" pizza'), '"5"" pizza"');
      expect(DataExport.field('two\nlines'), '"two\nlines"');
    });
    test('formula characters are neutralised with a leading apostrophe', () {
      expect(DataExport.field('-5'), "'-5");
      expect(DataExport.field('+1'), "'+1");
      expect(DataExport.field('@home'), "'@home");
      expect(DataExport.field('=SUM(A1)'), "'=SUM(A1)");
    });
    test('the formula guard and the quoting combine', () {
      expect(DataExport.field('=HYPERLINK("x")'), "\"'=HYPERLINK(\"\"x\"\")\"");
    });
  });
}
