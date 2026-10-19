import 'package:flutter_test/flutter_test.dart';
import 'package:Easify/models/order_item.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/service/pricing_service.dart';

/// Batch 2 — P15/P22: extras must be frozen at sale time.
///
/// Old orders (old JSON format, no snapshot) keep their previous
/// behaviour: price/name follow the live product link while it exists.
void main() {
  final pricing = PricingService();

  OrderItem teaWithExtra(Product lait, {double basePrice = 10}) {
    final item = OrderItem(quantity: 1);
    item.product.target = Product(id: 1, name: 'Thé', price: basePrice);
    item.price = basePrice;
    item.productName = 'Thé';
    item.setExtraQuantity(lait, 1);
    return item;
  }

  group('P15 — extras snapshot', () {
    test('extra price is frozen at add time even if the shelf price changes',
        () {
      final lait = Product(id: 5, name: 'Lait', price: 2);
      final item = teaWithExtra(lait);
      expect(pricing.calculateItemTotal(item), closeTo(12, 0.0001));

      lait.price = 7; // shop edits the extra's price afterwards
      expect(
        pricing.calculateItemTotal(item),
        closeTo(12, 0.0001),
        reason: 'editing an extra must not rewrite a saved sale',
      );
    });

    test('old-format JSON (no snapshot) still follows the live link price',
        () {
      final lait = Product(id: 5, name: 'Lait', price: 2);
      final item = OrderItem(quantity: 1);
      item.product.target = Product(id: 1, name: 'Thé', price: 10);
      item.price = 10;
      item.extras.add(lait);
      item.extraQuantitiesJson = '{"5": 2}'; // old format written before this fix
      expect(pricing.calculateItemTotal(item), closeTo(14, 0.0001));

      lait.price = 3;
      expect(pricing.calculateItemTotal(item), closeTo(16, 0.0001),
          reason: 'legacy orders behave exactly as they did before');
    });

    test('setExtraQuantity keeps the original snapshot on quantity change',
        () {
      final lait = Product(id: 5, name: 'Lait', price: 2);
      final item = OrderItem(quantity: 1);
      item.setExtraQuantity(lait, 1);

      lait.price = 9; // shelf edit between the two additions
      item.setExtraQuantity(lait, 2);

      final entry = item.resolveExtras().single;
      expect(entry.price, 2.0, reason: 'the first snapshot must be kept');
      expect(entry.quantity, 2);
    });

    test('snapshot includes the name and quantity math is price × qty', () {
      final lait = Product(id: 5, name: 'Lait', price: 2);
      final item = OrderItem(quantity: 1);
      item.price = 10;
      item.setExtraQuantity(lait, 3);
      lait.price = 99;

      final entry = item.resolveExtras().single;
      expect(entry.name, 'Lait');
      expect(pricing.calculateItemTotal(item), closeTo(16, 0.0001)); // 10 + 3×2
    });
  });

  group('P22 — deleted extras', () {
    test('snapshot price + name survive product deletion', () {
      final item = OrderItem(quantity: 1);
      item.price = 10;
      // Product 5 was deleted: only the JSON remains (extras link is empty).
      item.extraQuantitiesJson = '{"5": {"q": 2, "p": 2.5, "n": "Lait"}}';

      final entry = item.resolveExtras().single;
      expect(entry.name, 'Lait');
      expect(entry.price, 2.5);
      expect(pricing.calculateItemTotal(item), closeTo(15, 0.0001));
    });

    test('legacy entry with a deleted product is dropped (old behaviour)',
        () {
      final item = OrderItem(quantity: 1);
      item.price = 10;
      item.extraQuantitiesJson = '{"5": 2}'; // old format, product gone
      expect(item.resolveExtras(), isEmpty);
      expect(pricing.calculateItemTotal(item), closeTo(10, 0.0001));
    });
  });

  group('format compatibility', () {
    test('getExtraQuantity reads both formats', () {
      final lait = Product(id: 5, name: 'Lait', price: 2);
      final item = OrderItem(quantity: 1);

      item.extraQuantitiesJson = '{"5": 3}';
      expect(item.getExtraQuantity(lait), 3);

      item.extraQuantitiesJson = '{"5": {"q": 4, "p": 2.0, "n": "Lait"}}';
      expect(item.getExtraQuantity(lait), 4);

      item.extraQuantitiesJson = null;
      expect(item.getExtraQuantity(lait), 1, reason: 'default quantity');
    });

    test('a link without a JSON entry still resolves (safety net)', () {
      final lait = Product(id: 5, name: 'Lait', price: 2);
      final item = OrderItem(quantity: 1);
      item.extras.add(lait);

      final entry = item.resolveExtras().single;
      expect(entry.quantity, 1);
      expect(entry.price, 2.0);
      expect(entry.name, 'Lait');
    });

    test('removing an extra (qty 0) clears both json and link', () {
      final lait = Product(id: 5, name: 'Lait', price: 2);
      final item = OrderItem(quantity: 1);
      item.setExtraQuantity(lait, 1);
      item.setExtraQuantity(lait, 0);

      expect(item.resolveExtras(), isEmpty);
      expect(item.extraQuantitiesJson, '{}');
    });

    test('garbage json never crashes and falls back safely', () {
      final lait = Product(id: 5, name: 'Lait', price: 2);
      final item = OrderItem(quantity: 1);
      item.extraQuantitiesJson = 'not json';
      expect(item.getExtraQuantity(lait), 1);
      expect(item.resolveExtras(), isEmpty);

      item.extraQuantitiesJson = '{"5": {"q": "bad"}}';
      expect(item.getExtraQuantity(lait), 1);

      item.extraQuantitiesJson = '{"5": {"q": 2, "p": "abc", "n": 42}}';
      expect(item.getExtraQuantity(lait), 2);
      expect(item.resolveExtras(), isEmpty,
          reason: 'an entry with no readable price/name and no product is dead');
    });
  });
}
