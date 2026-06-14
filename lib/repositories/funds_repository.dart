import 'package:Easify/models/daily_funds.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';


class FundsRepository {
  final ObjectBox _objectbox;
  late final Box<DailyFunds> _dailyFundsBox;

  FundsRepository(this._objectbox) {
    _dailyFundsBox = _objectbox.store.box<DailyFunds>();
  }

  Stream<Query<DailyFunds>> watchFunds() {
    return _dailyFundsBox.query().watch();
  }

  double getTodayFunds() {
    final todayStart = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todayQuery = _dailyFundsBox
        .query(DailyFunds_.date.between(todayStart.millisecondsSinceEpoch,
            todayEnd.millisecondsSinceEpoch))
        .build();
    final todayResult = todayQuery.find();
    todayQuery.close();

    if (todayResult.isNotEmpty) {
      return todayResult.first.amount;
    }

    final latestQuery = _dailyFundsBox
        .query()
        .order(DailyFunds_.date, flags: Order.descending)
        .build();
    final latestResult = latestQuery.findFirst();
    latestQuery.close();

    return latestResult?.amount ?? 0.0;
  }

  bool checkIfFundsExist() {
    final todayStart =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final query = _dailyFundsBox
        .query(DailyFunds_.date.equals(todayStart.millisecondsSinceEpoch))
        .build();
    final count = query.count();
    query.close();
    return count > 0;
  }

  void saveFunds(double amount) {
    final DateTime todayStart = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final query = _dailyFundsBox
        .query(DailyFunds_.date.equals(todayStart.millisecondsSinceEpoch))
        .build();
    final result = query.find();
    query.close();

    if (result.isNotEmpty) {
      result.first.amount = amount;
      _dailyFundsBox.put(result.first);
    } else {
      final newFunds = DailyFunds(date: todayStart, amount: amount);
      _dailyFundsBox.put(newFunds);
    }
  }
}
