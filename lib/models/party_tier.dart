import 'package:objectbox/objectbox.dart';

@Entity()
class PartyTier {
  @Id()
  int id;
  String label;          // e.g. "PS5"
  double ratePerHour;

  PartyTier({
    this.id = 0,
    required this.label,
    required this.ratePerHour,
  });
}
