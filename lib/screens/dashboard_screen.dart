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
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

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
        currentFunds: null,
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
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.6,
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
      backgroundColor: AppColors.surface1,
      floatingActionButton: metricsAsync.when(
        data: (metrics) => FloatingActionButton.extended(
          onPressed: () =>
              _showFundsDialog(metrics.todayFunds, metrics.fundsAlreadySet),
          backgroundColor: AppColors.sidebarBg,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.rFull,
          ),
          icon: const Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.surface0, size: 18),
          label: Text(
            'Fond de caisse: ${metrics.todayFunds.toStringAsFixed(2)} DH',
            style: const TextStyle(
              color: AppColors.surface0,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
              decoration: const BoxDecoration(
                color: AppColors.surface0,
                border: Border(bottom: BorderSide(color: AppColors.surface3, width: 1)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: AppColors.ink0,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  const Expanded(
                    child: Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink0,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDateRange,
                            borderRadius: AppRadius.rLg,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.space4, vertical: AppSpacing.space3),
                              decoration: BoxDecoration(
                                color: AppColors.surface0,
                                borderRadius: AppRadius.rLg,
                                border: Border.all(color: AppColors.surface3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink5.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: AppColors.ink3),
                          const SizedBox(width: AppSpacing.space2 + AppSpacing.space1),
                          Expanded(
                            child: Text(
                              params.startDate != null && params.endDate != null
                                  ? '${DateFormat('MMM dd').format(params.startDate!)} – ${DateFormat('MMM dd, yyyy').format(params.endDate!)}'
                                  : 'Période Actuelle',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down,
                              size: 16, color: AppColors.ink3),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.space4, vertical: AppSpacing.space1),
                    decoration: BoxDecoration(
                      color: AppColors.surface0,
                      borderRadius: AppRadius.rLg,
                      border: Border.all(color: AppColors.surface3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink5.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: params.selectedUserId,
                        hint: const Text(
                          'Tous les Utilisateurs',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.ink3,
                              fontWeight: FontWeight.w600),
                        ),
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            size: 16, color: AppColors.ink3),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: const Text(
                              'Tous les Utilisateurs',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.ink2,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          ...ref.watch(allUsersProvider).map((user) => DropdownMenuItem<int?>(
                                value: user.id,
                                child: Text(
                                  user.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.ink2,
                                      fontWeight: FontWeight.w600),
                                ),
                              )),
                        ],
                        onChanged: (userId) {
                          ref.read(dashboardParamsProvider.notifier).state =
                              userId == null
                                  ? params.copyWith(clearUserId: true)
                                  : params.copyWith(selectedUserId: userId);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space6),

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
                          color: AppColors.primary,
                          trendText:
                              '${metrics.revenueTrend.toStringAsFixed(1)}%',
                          isPositive: metrics.revenueTrendPositive,
                          comparisonLabel: metrics.comparisonLabel,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showUnitsSoldPopup,
                          child: InfoCard(
                            title: 'Orders',
                            value: '${metrics.todayOrderCount.toInt()}',
                            icon: Icons.shopping_bag_outlined,
                            color: AppColors.completed,
                            trendText:
                                '${metrics.ordersTrend.toStringAsFixed(1)}%',
                            isPositive: metrics.ordersTrendPositive,
                            comparisonLabel: metrics.comparisonLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Row(
                    children: [
                      Expanded(
                        child: InfoCard(
                          title: 'Spend',
                          value: '${metrics.todayExpenses.toInt()} DH',
                          icon: Icons.credit_card_outlined,
                          color: AppColors.info,
                          trendText:
                              '${metrics.expensesTrend.toStringAsFixed(1)}%',
                          isPositive: !metrics.expensesTrendPositive,
                          comparisonLabel: metrics.comparisonLabel,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: InfoCard(
                          title: 'Profit',
                          value: '${metrics.todayProfit.toStringAsFixed(2)} DH',
                          icon: Icons.trending_up,
                          color: AppColors.warning,
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

            const SizedBox(height: AppSpacing.space6),

            WeeklyPerformanceChart(
              store: ref.read(objectBoxProvider).store,
              title: 'Weekly Performance',
              maxYValue: 2000.0,
            ),

            const SizedBox(height: AppSpacing.space6),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: AppRadius.rXl,
                border: Border.all(color: AppColors.surface3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink5.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: AppRadius.rXl,
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
            const SizedBox(height: AppSpacing.space10),
          ],
        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
