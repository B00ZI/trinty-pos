import 'package:objectbox/objectbox.dart';

@Entity()
class PartyTier {
  @Id()
  int id;
  String label;          // e.g. "30 min"
  int durationMinutes;   // 0 = open/unlimited
  double price;

  PartyTier({
    this.id = 0,
    required this.label,
    required this.durationMinutes,
    required this.price,
  });
}
