import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/utils/format_utils.dart';

void main() {
  group('FormatUtils', () {
    group('formatCountWithCap', () {
      test('returns count as string when count is less than 100', () {
        expect(FormatUtils.formatCountWithCap(0), '0');
        expect(FormatUtils.formatCountWithCap(1), '1');
        expect(FormatUtils.formatCountWithCap(42), '42');
        expect(FormatUtils.formatCountWithCap(99), '99');
      });

      test('returns "99+" when count is 100 or greater', () {
        expect(FormatUtils.formatCountWithCap(100), '99+');
        expect(FormatUtils.formatCountWithCap(101), '99+');
        expect(FormatUtils.formatCountWithCap(999), '99+');
        expect(FormatUtils.formatCountWithCap(1000), '99+');
      });
    });
  });
}
