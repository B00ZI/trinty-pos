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
}