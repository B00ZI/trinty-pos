import 'package:flutter_test/flutter_test.dart';
import 'package:Easify/service/money_parser.dart';

/// Batch 2 — P17 comma / P18: one parser for every money input.
void main() {
  group('MoneyParser — what people actually type', () {
    test('French comma is accepted', () {
      expect(MoneyParser.parse('12,5'), closeTo(12.5, 0.0001));
      expect(MoneyParser.parse('2,50'), closeTo(2.5, 0.0001));
      expect(MoneyParser.parse('0,05'), closeTo(0.05, 0.0001));
    });

    test('English dot still works (old habit)', () {
      expect(MoneyParser.parse('12.5'), closeTo(12.5, 0.0001));
      expect(MoneyParser.parse('12'), closeTo(12.0, 0.0001));
    });

    test('stray spaces are ignored', () {
      expect(MoneyParser.parse(' 12 , 5 '), closeTo(12.5, 0.0001));
      expect(MoneyParser.parse('1 000,50'), closeTo(1000.5, 0.0001));
    });

    test('zero typed explicitly is valid', () {
      expect(MoneyParser.parse('0'), 0.0);
      expect(MoneyParser.parse('0,00'), 0.0);
    });
  });

  group('MoneyParser — garbage returns null so callers refuse to save', () {
    test('empty and whitespace return null', () {
      expect(MoneyParser.parse(''), isNull);
      expect(MoneyParser.parse('   '), isNull);
    });

    test('letters, units and scientific notation return null', () {
      expect(MoneyParser.parse('abc'), isNull);
      expect(MoneyParser.parse('12,5 DH'), isNull);
      expect(MoneyParser.parse('12e5'), isNull);
    });

    test('double separators and junk return null', () {
      expect(MoneyParser.parse('12,5,6'), isNull);
      expect(MoneyParser.parse('1.2.3'), isNull);
      expect(MoneyParser.parse('--5'), isNull);
    });

    test('NaN / Infinity can never leak into money', () {
      expect(MoneyParser.parse('NaN'), isNull);
      expect(MoneyParser.parse('Infinity'), isNull);
      expect(MoneyParser.parse('-Infinity'), isNull);
    });
  });
}
