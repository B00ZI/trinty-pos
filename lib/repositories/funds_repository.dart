import 'package:Easify/models/daily_funds.dart';
import 'package:Easify/models/store_config.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:Easify/service/business_day_helper.dart';


class FundsRepository {
  final ObjectBox _objectbox;
  late final Box<DailyFunds> _dailyFundsBox;

  FundsRepository(this._objectbox) {
    _dailyFundsBox = _objectbox.store.box<DailyFunds>();
  }

  StoreConfig _getStoreConfig() {
    final configs = _objectbox.storeConfigBox.getAll();
    return configs.isNotEmpty ? configs.first : StoreConfig();
  }

  /// The business date "today". P19: the funds screens used plain
  /// midnight while the dashboard used the business day — before the
  /// shop's opening hour the two showed two different "todays" (float
  /// re-prompted, yesterday's float displayed as today's).
  DateTime _businessDateNow() =>
      BusinessDayHelper.getBusinessDayDate(DateTime.now(), _getStoreConfig());

  Stream<Query<DailyFunds>> watchFunds() {
    return _dailyFundsBox.query().watch();
  }

  double getTodayFunds() {
    final businessDate = _businessDateNow();
    final todayEnd = businessDate.add(const Duration(days: 1));

    // P28: end-exclusive — between() is inclusive on both ends.
    final todayQuery = _dailyFundsBox
        .query(DailyFunds_.date.between(businessDate.millisecondsSinceEpoch,
            todayEnd.millisecondsSinceEpoch - 1))
        .build();
    final todayResult = todayQuery.find();
    todayQuery.close();

    if (todayResult.isNotEmpty) {
      return todayResult.first.amount;
    }

    // No float set for this business day yet: the drawer cash really
    // does continue (a shop's money doesn't reset in thin air), so the
    // latest record carries over — now correctly business-day aware.
    final latestQuery = _dailyFundsBox
        .query()
        .order(DailyFunds_.date, flags: Order.descending)
        .build();
    final latestResult = latestQuery.findFirst();
    latestQuery.close();

    return latestResult?.amount ?? 0.0;
  }

  bool checkIfFundsExist() {
    final businessDate = _businessDateNow();
    final query = _dailyFundsBox
        .query(DailyFunds_.date.equals(businessDate.millisecondsSinceEpoch))
        .build();
    final count = query.count();
    query.close();
    return count > 0;
  }

  void saveFunds(double amount) {
    // Records are stored under the BUSINESS date (midnight of the day
    // the float belongs to) — an owner who sets the float at 7am with a
    // 7:30 reset belongs to the previous business day, same as every
    // other screen shows.
    final DateTime businessDate = _businessDateNow();

    final query = _dailyFundsBox
        .query(DailyFunds_.date.equals(businessDate.millisecondsSinceEpoch))
        .build();
    final result = query.find();
    query.close();

    if (result.isNotEmpty) {
      result.first.amount = amount;
      _dailyFundsBox.put(result.first);
    } else {
      final newFunds = DailyFunds(date: businessDate, amount: amount);
      _dailyFundsBox.put(newFunds);
    }
  }
}
