import 'package:flutter_test/flutter_test.dart';
import 'package:Easify/models/order.dart' as order_model;
import 'package:Easify/models/order_item.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/service/pricing_service.dart';
import 'package:Easify/service/printer_helper.dart';

// Batch 1 (Receipts & printing) regression tests — PROBLEMS.md P13/P14/P31.
// Run with: flutter test test/batch1_printing_test.dart
void main() {
  group('printableText (P31: printers can only encode Latin-1)', () {
    test('replaces characters that used to crash the printer mid-ticket',
        () {
      expect(printableText('✅ OK'), 'OK OK');
      expect(printableText('Prix: 12 €'), 'Prix: 12 EUR');
      expect(printableText('bœuf'), 'boeuf');
      expect(printableText('Œuf'), 'OEuf');
      expect(printableText('‘quote’'), "'quote'");
      expect(printableText('“double”'), '"double"');
      expect(printableText('a…b'), 'a...b');
      expect(printableText('pizza🍕'), 'pizza'); // emoji dropped silently
    });

    test('keeps normal French receipt text byte-for-byte', () {
      const s = 'Crème brûlée & café, déjà 25,50 DH';
      expect(printableText(s), s);
    });

    test('never throws on any modern text', () {
      expect(() => printableText('€✅œ🍕漢❤✔'), returnsNormally);
    });
  });

  group('PricingService.calculateItemTotal (P14: one money formula)', () {
    test('uses the price stored on the sale, not today\'s product price',
        () {
      final item = OrderItem(quantity: 2, price: 10.0);
      item.product.target = Product(name: 'Thé', price: 99.0); // edited AFTER
      expect(PricingService().calculateItemTotal(item), 20.0);
    });

    test('falls back to the live product price when nothing was stored', () {
      final item = OrderItem(quantity: 3);
      item.product.target = Product(name: 'Café', price: 5.0);
      expect(PricingService().calculateItemTotal(item), 15.0);
    });

    test('deleted product with no stored price = 0, no crash', () {
      expect(PricingService().calculateItemTotal(OrderItem(quantity: 4)),
          0.0);
    });

    test('adds extras together with their quantities', () {
      final item = OrderItem(quantity: 1, price: 10.0);
      final extra = Product(name: 'Lait', price: 2.0);
      item.extras.add(extra);
      item.setExtraQuantity(extra, 3);
      expect(PricingService().calculateItemTotal(item), 16.0);
    });
  });

  group('convertRuciToReceiptData — reprint (P14)', () {
    test('reprint shows the SOLD price, the SOLD name and the extras', () {
      final order = order_model.Order(
          date: DateTime(2026, 1, 5, 12), orderNumber: 42);
      final item = OrderItem(
          quantity: 2, price: 10.0, productName: 'Thé à la menthe');
      item.product.target = Product(name: 'Renamed', price: 77.0);
      item.extras.add(Product(name: 'Sucre', price: 1.5));
      item.setExtraQuantity(item.extras.first, 2);
      order.items.add(item);

      final receipt = ReceiptData.convertRuciToReceiptData(order);

      expect(receipt.total, '23.00'); // 2×10 sold price + 2×1.5 extras
      expect(receipt.items.first.title, 'Thé à la menthe');
      expect(receipt.items.first.price, 10.0);
      expect(receipt.items.first.extras.single.price, 1.5);
      // The printed lines must add up to the printed total.
      expect(double.parse(receipt.total),
          receipt.items.fold<double>(0, (s, i) => s + i.total));
    });

    test('deleted product without stored name still prints something sane',
        () {
      final order =
          order_model.Order(date: DateTime(2026, 1, 5), orderNumber: 7);
      order.items.add(OrderItem(quantity: 1)); // no name, no product link

      final receipt = ReceiptData.convertRuciToReceiptData(order);
      expect(receipt.items.first.title, 'Article');
      expect(receipt.total, '0.00');
    });
  });
}
