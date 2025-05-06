import 'package:myapp/models.dart';

final List<Product> mockProducts = [
  Product(
    id: 'prod-001',
    name: 'Classic Burger',
    price: 8.99,
    category: 'Main Course',
    description: 'Beef patty, lettuce, tomato, cheese, and special sauce in a brioche bun.',
    imageUrl: 'https://example.com/images/classic_burger.jpg', // Replace with a valid URL
    isAvailable: true,
  ),
  Product(
    id: 'prod-002',
    name: 'French Fries',
    price: 3.49,
    category: 'Side',
    description: 'Crispy golden French fries with a sprinkle of salt.',
    imageUrl: 'https://example.com/images/french_fries.jpg', // Replace with a valid URL
    isAvailable: true,
  ),
  Product(
    id: 'prod-003',
    name: 'Coca-Cola',
    price: 1.99,
    category: 'Drink',
    description: 'A refreshing bottle of Coca-Cola.',
    imageUrl: 'https://example.com/images/coca_cola.jpg', // Replace with a valid URL
    isAvailable: true,
  ),
  Product(
    id: 'prod-004',
    name: 'Caesar Salad',
    price: 7.50,
    category: 'Appetizer',
    description: 'Fresh romaine lettuce, croutons, parmesan cheese, and Caesar dressing.',
    imageUrl: 'https://example.com/images/caesar_salad.jpg', // Replace with a valid URL
    isAvailable: true,
  ),
  Product(
    id: 'prod-005',
    name: 'Chocolate Cake',
    price: 5.99,
    category: 'Dessert',
    description: 'Rich and moist chocolate cake with chocolate frosting.',
    imageUrl: 'https://example.com/images/chocolate_cake.jpg', // Replace with a valid URL
    isAvailable: true,
  ),
];

final List<Order> mockOrders = [
  Order(
    id: 'order-001',
    items: [
      OrderItem(product: mockProducts[0], quantity: 2),
      OrderItem(product: mockProducts[1], quantity: 1),
      OrderItem(product: mockProducts[2], quantity: 3),
    ],
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  Order(
    id: 'order-002',
    items: [
      OrderItem(product: mockProducts[3], quantity: 1),
      OrderItem(product: mockProducts[4], quantity: 1),
    ],
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Order(
    id: 'order-003',
    items: [
      OrderItem(product: mockProducts[0], quantity: 1),
      OrderItem(product: mockProducts[1], quantity: 2),
    ],
    timestamp: DateTime.now().subtract(const Duration(days: 3)),
  ),
];

final Settings mockSettings = Settings(
  shopName: 'Drywich',
  currency: 'USD',
  taxRate: 5.0,
  receiptFooter: 'Thank you for your order from Drywich!',
  printerIp: '192.168.1.100',
  printerPort: 9100,
);