import 'package:flutter_test/flutter_test.dart';
import 'package:rastro/utils/br_money_input.dart';

void main() {
  group('parseBrMoney', () {
    test('empty', () {
      expect(parseBrMoney(''), isNull);
      expect(parseBrMoney('   '), isNull);
    });

    test('masked values', () {
      expect(parseBrMoney('12,34'), 12.34);
      expect(parseBrMoney('1.234,56'), 1234.56);
      expect(parseBrMoney('0,05'), 0.05);
    });
  });

  group('formatBrMoneyInput', () {
    test('round-trip', () {
      expect(formatBrMoneyInput(1234.56), '1.234,56');
      expect(parseBrMoney(formatBrMoneyInput(99.9)), closeTo(99.9, 0.001));
    });
  });
}
