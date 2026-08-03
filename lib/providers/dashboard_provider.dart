import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/repositories/order_repository.dart';
import 'package:Easify/repositories/expense_repository.dart';
import 'package:Easify/repositories/funds_repository.dart';
import 'package:Easify/repositories/config_repository.dart';
import 'package:Easify/service/pricing_service.dart';
import 'package:Easify/service/dashboard_service.dart';
import 'package:Easify/models/dashboard_metrics.dart';

// ObjectBox must be provided by overriding this provider in the ProviderScope
final objectBoxProvider = Provider<ObjectBox>((ref) {
  throw UnimplementedError('objectBoxProvider must be overridden');
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final ob = ref.watch(objectBoxProvider);
  return OrderRepository(ob);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final ob = ref.watch(objectBoxProvider);
  return ExpenseRepository(ob);
});

final fundsRepositoryProvider = Provider<FundsRepository>((ref) {
  final ob = ref.watch(objectBoxProvider);
  return FundsRepository(ob);
});

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  final ob = ref.watch(objectBoxProvider);
  return ConfigRepository(ob);
});

final pricingServiceProvider = Provider<PricingService>((ref) {
  return PricingService();
});

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(
    ref.watch(orderRepositoryProvider),
    ref.watch(expenseRepositoryProvider),
    ref.watch(fundsRepositoryProvider),
    ref.watch(configRepositoryProvider),
    ref.watch(pricingServiceProvider),
  );
});

class DashboardParams {
  final int? selectedUserId;
  final DateTime? startDate;
  final DateTime? endDate;

  DashboardParams({this.selectedUserId, this.startDate, this.endDate});
  
  DashboardParams copyWith({
    bool clearUserId = false,
    int? selectedUserId, 
    DateTime? startDate, 
    DateTime? endDate
  }) {
    return DashboardParams(
      selectedUserId: clearUserId ? null : (selectedUserId ?? this.selectedUserId),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

final dashboardParamsProvider = StateProvider<DashboardParams>((ref) {
  return DashboardParams(); 
});

// These stream providers watch ObjectBox changes and act as invalidation triggers.
// They are separate from the FutureProvider so there's no race condition.
final _orderChangeProvider = StreamProvider<void>((ref) {
  final orderRepo = ref.watch(orderRepositoryProvider);
  return orderRepo.watchOrders().map((_) {});
});

final _gameChangeProvider = StreamProvider<void>((ref) {
  final orderRepo = ref.watch(orderRepositoryProvider);
  return orderRepo.watchGameSessions().map((_) {});
});

final _expenseChangeProvider = StreamProvider<void>((ref) {
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  return expenseRepo.watchExpenses().map((_) {});
});

final _fundsChangeProvider = StreamProvider<void>((ref) {
  final fundsRepo = ref.watch(fundsRepositoryProvider);
  return fundsRepo.watchFunds().map((_) {});
});

final _configChangeProvider = StreamProvider<void>((ref) {
  final configRepo = ref.watch(configRepositoryProvider);
  return configRepo.watchConfig().map((_) {});
});

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  // Watching these stream providers causes this FutureProvider to
  // automatically re-run whenever any of them emit a new event.
  ref.watch(_orderChangeProvider);
  ref.watch(_gameChangeProvider);
  ref.watch(_expenseChangeProvider);
  ref.watch(_fundsChangeProvider);
  ref.watch(_configChangeProvider);

  final service = ref.watch(dashboardServiceProvider);
  final params = ref.watch(dashboardParamsProvider);

  return service.getDashboardMetrics(
    params.selectedUserId, 
    params.startDate, 
    params.endDate
  );
});

final unitsSoldProvider = FutureProvider<List<MapEntry<String, int>>>((ref) async {
  // Reuse the same change streams so units sold refreshes on order/game changes
  ref.watch(_orderChangeProvider);
  ref.watch(_gameChangeProvider);

  final params = ref.watch(dashboardParamsProvider);
  final orderRepo = ref.watch(orderRepositoryProvider);

  DateTime startDate;
  DateTime endDate;

  if (params.startDate != null && params.endDate != null) {
    startDate = params.startDate!;
    endDate = params.endDate!;
  } else {
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day);
    endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  final periodOrders = orderRepo.getOrdersByDateRange(startDate, endDate, params.selectedUserId);
  final periodGames = orderRepo.getGameSessionsByDateRange(startDate, endDate, params.selectedUserId);

  final Map<String, int> productCounts = {};
  for (final ruci in periodOrders) {
    for (final item in ruci.items) {
      final productName = item.productName ?? item.product.target?.name ?? 'Inconnu';
      productCounts[productName] = (productCounts[productName] ?? 0) + item.quantity;
    }
  }

  for (final session in periodGames) {
    if (session.relatedOrderId == null || session.relatedOrderId == 0) {
      final gameLabel = 'Jeux: ${session.tierLabel}';
      productCounts[gameLabel] = (productCounts[gameLabel] ?? 0) + 1;
    }
  }

  final sortedItems = productCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
    
  return sortedItems;
});
