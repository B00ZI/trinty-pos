import 'package:objectbox/objectbox.dart';
import 'order_item.dart';
import 'app_user.dart';

@Entity()
class Ruci {
  int id = 0;

  int orderNumber;

  DateTime date;

  bool isDeleted = false;

  bool isEdited = false;

  final items = ToMany<OrderItem>();
  final user = ToOne<AppUser>();

  Ruci({
    required this.orderNumber,
    required this.date,
    this.id = 0,
    this.isDeleted = false,
    this.isEdited = false,
  });
}
