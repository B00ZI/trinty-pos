import 'package:objectbox/objectbox.dart';
import 'order_item.dart';

@Entity()
class Ruci {
  @Id()
  int id;

  DateTime date;

  final items = ToMany<OrderItem>();

  Ruci({this.id = 0, required this.date});
}
