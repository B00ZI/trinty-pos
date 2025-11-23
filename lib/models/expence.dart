// models/expence.dart
import 'package:objectbox/objectbox.dart';

@Entity() // ← THIS IS CRITICAL
class expence {
  @Id()
  int id;

  String title;
  double amount;
  DateTime date;

  expence({
    this.id = 0,
    required this.title,
    required this.amount,
    DateTime? date,
  }) : date = date ?? DateTime.now();
}
