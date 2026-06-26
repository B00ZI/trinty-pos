import 'package:objectbox/objectbox.dart';
import 'order_item.dart';
import 'app_user.dart';

@Entity(uid: 459141988423342695)
class Order {
  int id = 0;

  int orderNumber;

  DateTime date;

  bool isDeleted = false;

  bool isEdited = false;

  int? relatedGameSessionId;

  final items = ToMany<OrderItem>();
  final user = ToOne<AppUser>();

  Order({
    required this.orderNumber,
    required this.date,
    this.id = 0,
    this.isDeleted = false,
    this.isEdited = false,
    this.relatedGameSessionId,
  });
}
