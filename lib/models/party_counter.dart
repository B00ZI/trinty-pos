import 'package:objectbox/objectbox.dart';

@Entity()
class PartyCounter {
  @Id(assignable: true)
  int id;
  int value;

  PartyCounter({this.id = 0, this.value = 1});
}
