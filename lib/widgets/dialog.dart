import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';
import '../models/order.dart' as order_model;
import '../models/expence.dart' as expence_model;
import '../objectbox.dart';
import '../models/product.dart' as product_model;

// Show daily data dialog
void showDailyDataDialog(BuildContext context, ObjectBox objectbox) async {
  try {
    final dailyData = await _getAllDailyData(objectbox);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Financial Summary',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6, // Constrain height for scrolling
          child: dailyData.isEmpty
              ? const Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Revenue',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Expenses',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'profit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Data rows
                      ...dailyData.map((data) => Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatDateForDisplay(data.rawDate),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${data.revenue.toStringAsFixed(2)} DH',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: data.revenue > 0
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${data.expenses.toStringAsFixed(2)} DH',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: data.expenses > 0
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${data.profite.toStringAsFixed(2)} DH',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                    const SizedBox(height: 12),
                    // Summary (Sticky at bottom)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'General Total:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${(_calculateTotalRevenue(dailyData) - _calculateTotalExpenses(dailyData)).toStringAsFixed(2)} DH',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading data: $e')),
    );
  }
}

// Data model for daily summary
class DailySummary {
  final DateTime rawDate;

  final double revenue;
  final double expenses;
  final double profite;
  final int orders;

  DailySummary({
    required this.rawDate,
    required this.revenue,
    required this.expenses,
    required this.profite,
    required this.orders,
  });
}

// Get all daily data
Future<List<DailySummary>> _getAllDailyData(ObjectBox objectbox) async {
  final dailyData = <DailySummary>[];

  final ordersBox = objectbox.store.box<order_model.Ruci>();
  final expensesBox = objectbox.store.box<expence_model.expence>();

  final allDates = await _getAllUniqueDates(ordersBox, expensesBox);

  for (final date in allDates) {
    final revenue = await _getDayRevenue(ordersBox, date);
    final expenses = await _getDayExpenses(expensesBox, date);
    final profit = await _calculateProfit(ordersBox, expensesBox, date);
    final orders = await _getDayOrders(ordersBox, date);

    dailyData.add(DailySummary(
      rawDate: date,
      revenue: revenue,
      expenses: expenses,
      orders: orders,
      profite: profit,
    ));
  }

  dailyData.sort((a, b) =>
      b.rawDate.compareTo(a.rawDate));

  return dailyData;
}

// Extract all unique days
Future<List<DateTime>> _getAllUniqueDates(
    Box<order_model.Ruci> ordersBox,
    Box<expence_model.expence> expensesBox) async {
  final Set<DateTime> unique = {};

  for (final o in ordersBox.getAll()) {
    final d = DateTime(o.date.year, o.date.month, o.date.day);
    unique.add(d);
  }

  for (final e in expensesBox.getAll()) {
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    unique.add(d);
  }

  return unique.toList();
}

// Revenue for specific day
Future<double> _getDayRevenue(
    Box<order_model.Ruci> ordersBox, DateTime day) async {
  final all = ordersBox.getAll();

  final sameDayOrders = all.where((order) =>
      order.date.year == day.year &&
      order.date.month == day.month &&
      order.date.day == day.day);

  double total = 0;

  for (final order in sameDayOrders) {
    for (final item in order.items) {
      final product = item.product.target;
      if (product == null) continue;

      total += product.price * item.quantity;
      // Include EXTRAS in revenue
      for (final extra in item.extras) {
        total += extra.price;
      }
    }
  }

  return total;
}

// Expenses for specific day
Future<double> _getDayExpenses(
    Box<expence_model.expence> expensesBox, DateTime day) async {
  final all = expensesBox.getAll();

  final sameDayExpenses = all.where((e) =>
      e.date.year == day.year &&
      e.date.month == day.month &&
      e.date.day == day.day);

  double total = 0.0;
  for (final e in sameDayExpenses) {
    total += e.amount;
  }

  return total;
}

Future<double> _calculateProfit(
    Box<order_model.Ruci> ordersBox,
    Box<expence_model.expence> expensesBox,
    DateTime day) async {
  final revenue = await _getDayRevenue(ordersBox, day);
  final expenses = await _getDayExpenses(expensesBox, day);
  final profite= revenue - expenses;
  return profite; 
}




// Number of orders for day
Future<int> _getDayOrders(
    Box<order_model.Ruci> ordersBox, DateTime day) async {
  final all = ordersBox.getAll();

  return all.where((o) =>
      o.date.year == day.year &&
      o.date.month == day.month &&
      o.date.day == day.day).length;
}

// Format date
String _formatDateForDisplay(DateTime d) {
  return '${d.day}/${d.month}/${d.year}';
}

double _calculateTotalRevenue(List<DailySummary> data) {
  return data.fold(0.0, (sum, d) => sum + d.revenue);
}
double _calculateTotalExpenses(List<DailySummary> data) {
  return data.fold(0.0, (sum, d) => sum + d.expenses);
}
