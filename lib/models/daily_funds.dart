import 'package:objectbox/objectbox.dart';

@Entity()
class DailyFunds {
  @Id()
  int id = 0;

  final DateTime date;
  double amount;

  DailyFunds({
    required this.date,
    required this.amount,
  });
}
