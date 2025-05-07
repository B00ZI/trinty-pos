import 'package:objectbox/objectbox.dart';
import 'product.dart';

@Entity()
class OrderItem {
  @Id()
  int id;

  final ToOne<Product> product = ToOne<Product>();
  int quantity;

  OrderItem({
    this.id = 0,
    required this.quantity,
  });
}