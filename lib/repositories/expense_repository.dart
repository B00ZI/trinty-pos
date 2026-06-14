import 'package:Easify/models/expence.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';

class ExpenseRepository {
  final ObjectBox _objectbox;
  late final Box<expence> _expenceBox;

  ExpenseRepository(this._objectbox) {
    _expenceBox = _objectbox.store.box<expence>();
  }

  Stream<Query<expence>> watchExpenses() {
    return _expenceBox.query().watch();
  }

  List<expence> getExpensesByDateRange(DateTime start, DateTime end) {
    final query = _expenceBox.query(expence_.date
        .between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch))
        .build();
    final periodExpenses = query.find();
    query.close();
    return periodExpenses;
  }
}
