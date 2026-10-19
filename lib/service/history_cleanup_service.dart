import 'package:Easify/models/daily_funds.dart';
import 'package:Easify/models/expense.dart';
import 'package:Easify/models/game_session.dart';
import 'package:Easify/models/order.dart' as order_model;
import 'package:Easify/models/order_counter.dart';
import 'package:Easify/models/order_item.dart';
import 'package:Easify/models/store_config.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:Easify/service/business_day_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Summary of what a cleanup deleted (for user feedback).
class CleanupResult {
  final int orders;
  final int sessions;
  final int expenses;

  const CleanupResult({this.orders = 0, this.sessions = 0, this.expenses = 0});

  int get total => orders + sessions + expenses;
}

/// Removes history data (orders, game sessions, expenses) to keep the
/// database small and the app fast (PROBLEMS.md P04).
///
/// Never touches products, categories, users, printers or settings.
class HistoryCleanupService {
  static const _autoCleanPrefKey = 'auto_clean_days';

  final ObjectBox _objectbox;

  HistoryCleanupService(this._objectbox);

  Box<order_model.Order> get _orderBox =>
      _objectbox.store.box<order_model.Order>();
  Box<OrderItem> get _orderItemBox => _objectbox.store.box<OrderItem>();
  Box<GameSession> get _gameSessionBox => _objectbox.store.box<GameSession>();
  Box<Expense> get _expenseBox => _objectbox.store.box<Expense>();
  Box<DailyFunds> get _dailyFundsBox => _objectbox.store.box<DailyFunds>();
  Box<OrderCounter> get _orderCounterBox =>
      _objectbox.store.box<OrderCounter>();

  /// P19: cleanup cutoffs use the BUSINESS day, like every other screen —
  /// an auto-clean at 7am (before an 7:30 opening) no longer eats part of
  /// the day the owner is still looking at.
  StoreConfig get _config {
    final configs = _objectbox.storeConfigBox.getAll();
    return configs.isNotEmpty ? configs.first : StoreConfig();
  }

  /// Auto-clean setting: how many days of history to keep. 0 = OFF.
  /// Stored in SharedPreferences like the auth-mode setting.
  Future<int> getAutoCleanDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoCleanPrefKey) ?? 0;
  }

  Future<void> setAutoCleanDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoCleanPrefKey, days);
  }

  /// Called at app startup (main.dart): if the owner enabled auto-clean,
  /// quietly delete history older than the configured number of days.
  /// Scoped cleans keep DailyFunds so long-term totals survive.
  Future<void> runAutoClean() async {
    final days = await getAutoCleanDays();
    if (days <= 0) return;
    cleanOlderThan(days);
  }

  /// Deletes orders, game sessions and expenses started before
  /// ([days] days ago), plus any soft-deleted order at any age.
  /// DailyFunds (one small row per day) is kept.
  ///
  /// P19: "days" are BUSINESS days now — the cutoff is the start of the
  /// business day [days] back, so exactly [days] business days (today
  /// included) survive, matching what the owner sees as "days".
  CleanupResult cleanOlderThan(int days) {
    final config = _config;
    final today =
        BusinessDayHelper.getBusinessDayDate(DateTime.now(), config);
    final cutoffDate = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    final cutoff = BusinessDayHelper.getBusinessDayRange(cutoffDate, config)
        .$1
        .millisecondsSinceEpoch;
    return _cleanBefore(cutoff, deleteOldDailyFunds: false);
  }

  /// Deletes everything except the current BUSINESS day's data. Daily
  /// totals of past days are removed too; order numbering continues.
  CleanupResult cleanKeepingToday() {
    final config = _config;
    final start = BusinessDayHelper.getBusinessDayRange(
            BusinessDayHelper.getBusinessDayDate(DateTime.now(), config),
            config)
        .$1;
    return _cleanBefore(start.millisecondsSinceEpoch,
        deleteOldDailyFunds: true);
  }

  /// Deletes every order, game session, expense and daily total, and
  /// resets order numbering to 1 ("repartir à zéro").
  CleanupResult cleanAll() {
    final result = CleanupResult(
      orders: _orderBox.count(),
      sessions: _gameSessionBox.count(),
      expenses: _expenseBox.count(),
    );
    _orderItemBox.removeAll();
    _orderBox.removeAll();
    _gameSessionBox.removeAll();
    _expenseBox.removeAll();
    _dailyFundsBox.removeAll();
    _orderCounterBox.removeAll();
    _orderCounterBox.put(OrderCounter(id: 1, value: 1));
    return result;
  }

  /// Shared implementation: remove orders/sessions/expenses dated before
  /// [cutoffMillis] (soft-deleted orders are purged at any date).
  CleanupResult _cleanBefore(int cutoffMillis,
      {required bool deleteOldDailyFunds}) {
    // Orders + their items (relations are separate rows in ObjectBox).
    final orderQuery = _orderBox
        .query(Order_.date
            .lessThan(cutoffMillis)
            .or(Order_.isDeleted.equals(true)))
        .build();
    final oldOrders = orderQuery.find();
    orderQuery.close();

    final orderIds = <int>[];
    final itemIds = <int>[];
    for (final order in oldOrders) {
      orderIds.add(order.id);
      itemIds.addAll(order.items.map((item) => item.id));
    }
    if (itemIds.isNotEmpty) _orderItemBox.removeMany(itemIds);
    if (orderIds.isNotEmpty) _orderBox.removeMany(orderIds);

    // Game sessions.
    final sessionQuery = _gameSessionBox
        .query(GameSession_.startTime.lessThan(cutoffMillis))
        .build();
    final oldSessions = sessionQuery.find();
    sessionQuery.close();
    final sessionIds = oldSessions.map((s) => s.id).toList();
    if (sessionIds.isNotEmpty) _gameSessionBox.removeMany(sessionIds);

    // Expenses.
    final expenseQuery = _expenseBox
        .query(Expense_.date.lessThan(cutoffMillis))
        .build();
    final oldExpenses = expenseQuery.find();
    expenseQuery.close();
    final expenseIds = oldExpenses.map((e) => e.id).toList();
    if (expenseIds.isNotEmpty) _expenseBox.removeMany(expenseIds);

    // Daily totals: only for "keep today" and "delete everything".
    if (deleteOldDailyFunds) {
      final fundsQuery = _dailyFundsBox
          .query(DailyFunds_.date.lessThan(cutoffMillis))
          .build();
      final oldFunds = fundsQuery.find();
      fundsQuery.close();
      final fundsIds = oldFunds.map((f) => f.id).toList();
      if (fundsIds.isNotEmpty) _dailyFundsBox.removeMany(fundsIds);
    }

    return CleanupResult(
      orders: orderIds.length,
      sessions: sessionIds.length,
      expenses: expenseIds.length,
    );
  }
}
