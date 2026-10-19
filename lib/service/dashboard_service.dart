import 'package:Easify/models/dashboard_metrics.dart';
import 'package:Easify/repositories/order_repository.dart';
import 'package:Easify/repositories/expense_repository.dart';
import 'package:Easify/repositories/funds_repository.dart';
import 'package:Easify/repositories/config_repository.dart';
import 'package:Easify/service/pricing_service.dart';
import 'package:Easify/service/business_day_helper.dart';
import 'package:intl/intl.dart';

class DashboardService {
  final OrderRepository _orderRepo;
  final ExpenseRepository _expenseRepo; 
  final FundsRepository _fundsRepo;
  final ConfigRepository _configRepo;
  final PricingService _pricingService;

  DashboardService(
    this._orderRepo,
    this._expenseRepo,
    this._fundsRepo,
    this._configRepo,
    this._pricingService,
  );

  Future<DashboardMetrics> getDashboardMetrics(int? selectedUserId, DateTime? overrideStartDate, DateTime? overrideEndDate) async {
    final config = _configRepo.getStoreConfig();
    
    DateTime startDate = overrideStartDate ?? DateTime.now();
    DateTime endDate = overrideEndDate ?? DateTime.now();

    if (overrideStartDate == null || overrideEndDate == null) {
      final businessDate = BusinessDayHelper.getBusinessDayDate(DateTime.now(), config);
      final range = BusinessDayHelper.getBusinessDayRange(businessDate, config);
      startDate = range.$1;
      // End is EXCLUSIVE (P28): repositories subtract the last
      // millisecond. The old "−1 second" trim made the dashboard lose
      // every order of the day's final second.
      endDate = range.$2;
    }

    // Previous period = the same-length window ending where today starts.
    final duration = endDate.difference(startDate);
    final prevEnd = startDate; // exclusive
    final prevStart = prevEnd.subtract(duration);
    final prevLabelEnd = prevEnd.subtract(const Duration(milliseconds: 1));

    final comparisonLabel = 'vs ${DateFormat('dd/MM').format(prevStart)} - ${DateFormat('dd/MM').format(prevLabelEnd)}';

    // Calculate Today's Metrics
    final todayRevenue = await _getRevenue(startDate, endDate, selectedUserId, config);
    final todayOrderCount = await _getOrderCount(startDate, endDate, selectedUserId);
    final todayExpenses = await _getExpense(startDate, endDate);
    final todayFunds = _fundsRepo.getTodayFunds();
    final todayProfit = todayRevenue - todayExpenses;
    final fundsAlreadySet = todayFunds > 0 || _fundsRepo.checkIfFundsExist();

    // Calculate Previous Period Metrics
    final prevRevenue = await _getRevenue(prevStart, prevEnd, selectedUserId, config);
    final prevOrderCount = await _getOrderCount(prevStart, prevEnd, selectedUserId);
    final prevExpenses = await _getExpense(prevStart, prevEnd);
    final prevProfit = prevRevenue - prevExpenses;

    return DashboardMetrics(
      todayRevenue: todayRevenue,
      todayOrderCount: todayOrderCount,
      todayExpenses: todayExpenses,
      todayProfit: todayProfit,
      todayFunds: todayFunds,
      
      revenueTrend: _calculateTrendPercentage(todayRevenue, prevRevenue),
      ordersTrend: _calculateTrendPercentage(todayOrderCount, prevOrderCount),
      expensesTrend: _calculateTrendPercentage(todayExpenses, prevExpenses),
      profitTrend: _calculateTrendPercentage(todayProfit, prevProfit),
      
      revenueTrendPositive: todayRevenue >= prevRevenue,
      ordersTrendPositive: todayOrderCount >= prevOrderCount,
      expensesTrendPositive: todayExpenses >= prevExpenses,
      profitTrendPositive: todayProfit >= prevProfit,
      
      comparisonLabel: comparisonLabel,
      fundsAlreadySet: fundsAlreadySet,
    );
  }

  Future<double> _getRevenue(DateTime start, DateTime end, int? userId, config) async {
    final periodOrders = _orderRepo.getOrdersByDateRange(start, end, userId);
    double totalRevenue = 0.0;
    for (final ruci in periodOrders) {
      for (final orderItem in ruci.items) {
        totalRevenue += _pricingService.calculateItemTotal(orderItem,
            config: config, debugContext: 'orderId=${ruci.id}');
      }
    }

    final periodGames = _orderRepo.getGameSessionsByDateRange(start, end, userId);
    for (final session in periodGames) {
      if (session.relatedOrderId == null || session.relatedOrderId == 0) {
        totalRevenue += session.currentCalculatedPrice;
      }
    }
    return totalRevenue;
  }

  Future<double> _getOrderCount(DateTime start, DateTime end, int? userId) async {
    final periodOrders = _orderRepo.getOrdersByDateRange(start, end, userId);
    final orderCount = periodOrders.length;

    final periodGames = _orderRepo.getGameSessionsByDateRange(start, end, userId);
    int unlinkedGames = 0;
    for (final session in periodGames) {
      if (session.relatedOrderId == null || session.relatedOrderId == 0) {
        unlinkedGames++;
      }
    }
    return (orderCount + unlinkedGames).toDouble();
  }

  Future<double> _getExpense(DateTime start, DateTime end) async {
    final periodExpenses = _expenseRepo.getExpensesByDateRange(start, end);
    double total = 0.0;
    for (final exp in periodExpenses) total += exp.amount;
    return total;
  }

  double _calculateTrendPercentage(double current, double previous) {
    if (previous == 0.0) {
      return current > 0.0 ? 100.0 : 0.0;
    }
    final change = ((current - previous) / previous) * 100;
    return change.abs();
  }
}
