import 'package:objectbox/objectbox.dart';
import 'dart:convert';
import 'product.dart';

/// One extra of an order line with its money resolved (P15/P22).
///
/// Quantity always comes from the saved JSON; price and name come from the
/// sale-time snapshot written when the extra was added (new orders) or from
/// the live product link as fallback (old orders saved before snapshots).
class ExtraEntry {
  final int productId;
  final int quantity;
  final double price;
  final String name;

  const ExtraEntry({
    required this.productId,
    required this.quantity,
    required this.price,
    required this.name,
  });
}

@Entity()
class OrderItem {
  @Id()
  int id;

  final ToOne<Product> product = ToOne<Product>();
  final ToMany<Product> extras = ToMany<Product>();
  int quantity;
  String? extraQuantitiesJson;
  double? price; // Persisted price at order time
  String? productName; // Persisted name at order time

  OrderItem({
    this.id = 0,
    required this.quantity,
    this.extraQuantitiesJson,
    this.price,
    this.productName,
  });

  /// Decoded extras map. Understands both formats:
  /// old `{"5": 2}` and snapshot `{"5": {"q": 2, "p": 2.0, "n": "Lait"}}`.
  Map<String, dynamic> _extraMap() {
    if (extraQuantitiesJson == null || extraQuantitiesJson!.isEmpty) return {};
    try {
      final decoded = jsonDecode(extraQuantitiesJson!);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return {};
  }

  Product? _extraLink(int extraId) => extras
      .cast<Product?>()
      .firstWhere((e) => e!.id == extraId, orElse: () => null);

  static int _rawQty(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is Map) {
      final q = raw['q'];
      return q is num ? q.toInt() : 1;
    }
    return 1;
  }

  static double? _rawPrice(dynamic raw) {
    if (raw is! Map) return null;
    final p = raw['p'];
    return p is num ? p.toDouble() : null;
  }

  static String? _rawName(dynamic raw) {
    if (raw is! Map) return null;
    final n = raw['n'];
    return n is String ? n : null;
  }

  int getExtraQuantity(Product extra) {
    final raw = _extraMap()[extra.id.toString()];
    if (raw == null) return 1;
    return _rawQty(raw);
  }

  void setExtraQuantity(Product extra, int qty) {
    final map = _extraMap();
    final key = extra.id.toString();
    if (qty <= 0) {
      map.remove(key);
      extras.removeWhere((e) => e.id == extra.id);
    } else {
      final prev = map[key];
      // Snapshot the price/name charged today (P15/P22): once written it
      // survives price edits and product deletion. An existing snapshot is
      // kept — only the quantity changes on later edits.
      map[key] = {
        'q': qty,
        'p': _rawPrice(prev) ?? extra.price,
        'n': _rawName(prev) ?? extra.name,
      };
      if (!extras.any((e) => e.id == extra.id)) {
        extras.add(extra);
      }
    }
    extraQuantitiesJson = jsonEncode(map);
  }

  /// All extras of this line with money resolved: sale-time snapshot first,
  /// live product only as fallback for old orders. An entry that resolves to
  /// nothing (old format + product deleted) is dropped — the same behaviour
  /// as before snapshots existed.
  List<ExtraEntry> resolveExtras() {
    final map = _extraMap();
    final result = <ExtraEntry>[];
    final seen = <int>{};
    map.forEach((key, raw) {
      final id = int.tryParse(key);
      if (id == null) return;
      final link = _extraLink(id);
      final snapPrice = _rawPrice(raw);
      final snapName = _rawName(raw);
      // Legacy entry with a deleted product: nothing known about it.
      if (link == null && snapPrice == null && snapName == null) return;
      seen.add(id);
      result.add(ExtraEntry(
        productId: id,
        quantity: _rawQty(raw),
        price: snapPrice ?? link?.price ?? 0,
        name: snapName ?? link?.name ?? '',
      ));
    });
    // Safety net: a link that somehow has no JSON entry.
    for (final link in extras) {
      if (seen.contains(link.id)) continue;
      result.add(ExtraEntry(
        productId: link.id,
        quantity: getExtraQuantity(link),
        price: link.price,
        name: link.name,
      ));
    }
    return result;
  }
}
