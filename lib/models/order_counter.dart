import 'package:objectbox/objectbox.dart';

@Entity()
class OrderCounter {
  @Id(assignable: true)
  int id;

  int value;

  OrderCounter({this.id = 0, this.value = 1});
}