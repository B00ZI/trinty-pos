import 'package:objectbox/objectbox.dart';
import 'order_item.dart';

@Entity()
class Ruci {
  int id = 0;

  int orderNumber;

  DateTime date;

  bool isDeleted = false;

  bool isEdited = false;

  final items = ToMany<OrderItem>();

  Ruci({
    required this.orderNumber,
    required this.date,
    this.id = 0,
    this.isDeleted = false,
    this.isEdited = false,
  });
}
