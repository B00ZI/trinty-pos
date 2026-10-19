import 'package:Easify/models/expense.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';

class ExpenseRepository {
  final ObjectBox _objectbox;
  late final Box<Expense> _expenseBox;

  ExpenseRepository(this._objectbox) {
    _expenseBox = _objectbox.store.box<Expense>();
  }

  Stream<Query<Expense>> watchExpenses() {
    return _expenseBox.query().watch();
  }

  /// Expenses in [start, end) — [end] EXCLUSIVE (P28: `between()` is
  /// inclusive on both ends and double-counted exact boundaries).
  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    final query = _expenseBox
        .query(Expense_.date.between(
            start.millisecondsSinceEpoch, end.millisecondsSinceEpoch - 1))
        .build();
    final periodExpenses = query.find();
    query.close();
    return periodExpenses;
  }
}
