import 'package:objectbox/objectbox.dart';

@Entity()
class Product {
  @Id()
  int id;

  String name = '';
  double price = 0.0;
  String? category;
  String? description;
  String? imageUrl;
  bool isAvailable = false;
  int displayOrder = 0;

  Product({
    this.id = 0,
    required this.name,
    required this.price,
    this.category,
    this.description,
    this.imageUrl,
    this.isAvailable = false,
    this.displayOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'displayOrder': displayOrder,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? false,
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }
}