import 'package:objectbox/objectbox.dart';
import 'order_item.dart';

@Entity()
class Ruci {
  int id = 0;

  int orderNumber;

  DateTime date;

  final items = ToMany<OrderItem>();

  Ruci({required this.orderNumber, required this.date, this.id = 0});
}
