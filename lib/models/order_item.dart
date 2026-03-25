import 'package:objectbox/objectbox.dart';
import 'dart:convert';
import 'product.dart';

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

  int getExtraQuantity(Product extra) {
    if (extraQuantitiesJson == null || extraQuantitiesJson!.isEmpty) return 1;
    try {
      final map = jsonDecode(extraQuantitiesJson!);
      return map[extra.id.toString()] as int? ?? 1;
    } catch (e) {
      return 1;
    }
  }

  void setExtraQuantity(Product extra, int qty) {
    Map<String, dynamic> map = {};
    if (extraQuantitiesJson != null && extraQuantitiesJson!.isNotEmpty) {
      try {
        map = jsonDecode(extraQuantitiesJson!);
      } catch (e) {}
    }
    if (qty <= 0) {
      map.remove(extra.id.toString());
      extras.removeWhere((e) => e.id == extra.id);
    } else {
      map[extra.id.toString()] = qty;
      if (!extras.any((e) => e.id == extra.id)) {
        extras.add(extra);
      }
    }
    extraQuantitiesJson = jsonEncode(map);
  }
}