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

  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    final query = _expenseBox
        .query(Expense_.date
            .between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch))
        .build();
    final periodExpenses = query.find();
    query.close();
    return periodExpenses;
  }
}
