import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/insight_item.dart';
import '../widgets/charts.dart';
import '../widgets/daily_funds_dialog.dart';
import '../widgets/expense_tracking.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {

  Future<void> _selectDateRange() async {
    final currentParams = ref.read(dashboardParamsProvider);
    final initialStart = currentParams.startDate ?? DateTime.now();
    final initialEnd = currentParams.endDate ?? DateTime.now();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );

    if (picked != null) {
      final newStart =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      final newEnd = DateTime(
          picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      ref.read(dashboardParamsProvider.notifier).state = currentParams.copyWith(
        startDate: newStart,
        endDate: newEnd,
      );
    }
  }

  void _showFundsDialog(double currentAmount, bool fundsAlreadySet) {
    showDialog(
      context: context,
      builder: (ctx) => DailyFundsDialog(
        currentFunds: null, // Let user input the amount
        onSave: (amount) {
          ref.read(fundsRepositoryProvider).saveFunds(amount);
        },
      ),
    );
  }

  void _showUnitsSoldPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unités Vendues'),
        content: SizedBox(
          width: 400,
          height: 500,
          child: Consumer(
            builder: (context, ref, child) {
              final unitsAsync = ref.watch(unitsSoldProvider);
              return unitsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Erreur: $err')),
                data: (sortedItems) {
                  if (sortedItems.isEmpty) {
                    return const Center(
                        child: Text('Aucune vente sur cette période'));
                  }
                  return ListView.builder(
                    itemCount: sortedItems.length,
                    itemBuilder: (context, index) {
                      final entry = sortedItems[index];
                      return ListTile(
                        title: Text(entry.key),
                        trailing: Text(
                          '${entry.value}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final params = ref.watch(dashboardParamsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Dashboard'),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: metricsAsync.when(
        data: (metrics) => FloatingActionButton.extended(
          onPressed: () =>
              _showFundsDialog(metrics.todayFunds, metrics.fundsAlreadySet),
          backgroundColor: const Color(0xFF0F172A),
          elevation: 6,
          icon: const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white, size: 18),
          label: Text(
            'Fond de caisse: ${metrics.todayFunds.toStringAsFixed(2)} DH',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range & User Selector Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              params.startDate != null && params.endDate != null
                                  ? '${DateFormat('MMM dd').format(params.startDate!)} – ${DateFormat('MMM dd, yyyy').format(params.endDate!)}'
                                  : 'Période Actuelle',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down,
                              size: 16, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: params.selectedUserId,
                        hint: Text(
                          'Tous les Utilisateurs',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600),
                        ),
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down,
                            size: 16, color: Colors.grey[600]),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Tous les Utilisateurs',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          ...ref.watch(allUsersProvider).map((user) => DropdownMenuItem<int?>(
                                value: user.id,
                                child: Text(
                                  user.name,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600),
                                ),
                              )),
                        ],
                        onChanged: (userId) {
                          ref.read(dashboardParamsProvider.notifier).state =
                              params.copyWith(selectedUserId: userId);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Metrics Cards
            metricsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Erreur: $err')),
              data: (metrics) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InfoCard(
                          title: "Revenue",
                          value:
                              '${metrics.todayRevenue.toStringAsFixed(2)} DH',
                          icon: Icons.attach_money,
                          color: Colors.teal,
                          trendText:
                              '${metrics.revenueTrend.toStringAsFixed(1)}%',
                          isPositive: metrics.revenueTrendPositive,
                          comparisonLabel: metrics.comparisonLabel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showUnitsSoldPopup,
                          child: InfoCard(
                            title: 'Orders',
                            value: '${metrics.todayOrderCount.toInt()}',
                            icon: Icons.shopping_bag_outlined,
                            color: Colors.deepPurple,
                            trendText:
                                '${metrics.ordersTrend.toStringAsFixed(1)}%',
                            isPositive: metrics.ordersTrendPositive,
                            comparisonLabel: metrics.comparisonLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: InfoCard(
                          title: 'Spend',
                          value: '${metrics.todayExpenses.toInt()} DH',
                          icon: Icons.credit_card_outlined,
                          color: Colors.blue,
                          trendText:
                              '${metrics.expensesTrend.toStringAsFixed(1)}%',
                          isPositive: !metrics.expensesTrendPositive,
                          comparisonLabel: metrics.comparisonLabel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InfoCard(
                          title: 'Profit',
                          value: '${metrics.todayProfit.toStringAsFixed(2)} DH',
                          icon: Icons.trending_up,
                          color: Colors.orange,
                          trendText:
                              '${metrics.profitTrend.toStringAsFixed(1)}%',
                          isPositive: metrics.profitTrendPositive,
                          comparisonLabel: metrics.comparisonLabel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            WeeklyPerformanceChart(
              store: ref.read(objectBoxProvider).store,
              title: 'Weekly Performance',
              maxYValue: 2000.0,
            ),

            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 240,
                      child: AddableListWidget(
                        expenseBox: ref.read(objectBoxProvider).store.box<Expense>(),
                        onListChanged: (newExpenses) {
                          ref.invalidate(dashboardMetricsProvider);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
