class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String description;
  final String imageUrl;
  final bool isAvailable;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.isAvailable,
  });
}

class OrderItem {
  final Product product;
  int quantity;

  OrderItem({
    required this.product,
    required this.quantity,
  });

  double get subtotal => product.price * quantity;
}

class Order {
  final String id;
  final List<OrderItem> items;
  final DateTime timestamp;

  Order({
    required this.id,
    required this.items,
    required this.timestamp,
  });

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);
}

class Settings {
  String shopName;
  String currency;
  double taxRate;
  String receiptFooter;
  String printerIp;
  int printerPort;

  Settings({
    this.shopName = '',
    this.currency = 'USD',
    this.taxRate = 0.0,
    this.receiptFooter = 'Thank you for your order!',
    this.printerIp = '',
    this.printerPort = 9100,
  });
}