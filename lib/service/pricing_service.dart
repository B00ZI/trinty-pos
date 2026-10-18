import 'package:Easify/models/order_item.dart';
import 'package:Easify/models/store_config.dart';
import 'package:flutter/foundation.dart';

class PricingService {
  /// The one money formula (P14): price stored on the sale first, live
  /// product price only as a fallback, extras on top — so every screen
  /// agrees. [config] optional (kept for older callers).
  double calculateItemTotal(OrderItem item,
      {StoreConfig? config, String? debugContext}) {
    final tag = debugContext != null ? '[$debugContext]' : '';
    final persistedPrice = item.price;
    final productPrice = item.product.target?.price;
    double basePrice = (persistedPrice ?? productPrice ?? 0.0).toDouble();
    // Surge logic handled at order creation; price already includes surge if applicable
    // No additional surge adjustments needed here.

    double extrasTotal = 0.0;
    for (final extra in item.extras) {
      final extraQty = item.getExtraQuantity(extra);
      extrasTotal += extra.price * extraQty;
    }

    final double total = item.quantity * basePrice + extrasTotal;
    debugPrint(
      '[REVENUE] $tag itemId=${item.id} productId=${item.product.target?.id} qty=${item.quantity} '
      'persistedPrice=$persistedPrice productPrice=$productPrice '
      'basePrice=${basePrice.toStringAsFixed(2)} extrasTotal=${extrasTotal.toStringAsFixed(2)} total=${total.toStringAsFixed(2)}',
    );

    if (total == 0.0) {
      debugPrint('[REVENUE] WARNING $tag zero total for item id=${item.id}');
    }
    return total;
  }
}
