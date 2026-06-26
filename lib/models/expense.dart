// models/expense.dart
import 'package:objectbox/objectbox.dart';

@Entity(uid: 398202118687831166)
class Expense {
  @Id()
  int id;

  String title;
  double amount;
  DateTime date;

  Expense({
    this.id = 0,
    required this.title,
    required this.amount,
    DateTime? date,
  }) : date = date ?? DateTime.now();
}
