import 'package:Easify/widgets/expenceTracking.dart';
import 'package:flutter/material.dart';
import 'package:Easify/widgets/insight_item.dart';
import '../widgets/charts.dart';
import '../widgets/bestSellr.dart' as best_seller;
import '../models/product.dart' as product_model;
import '../models/order.dart' as order_model;
import '../models/order_item.dart';
import '../objectbox.g.dart';
import '../objectbox.dart';
import 'package:objectbox/objectbox.dart';
import '../models/expence.dart';
import 'package:flutter/scheduler.dart';

class DashboardScreen extends StatefulWidget {
  final ObjectBox objectbox;
  final List<product_model.Product> myProducts;

  DashboardScreen({super.key, required this.objectbox})
      : myProducts = [
          product_model.Product(
            name: 'Wireless Headphones',
            price: 79.99,
            isAvailable: true,
          ),
          product_model.Product(
            name: 'Smart Watch Series 5',
            price: 199.99,
            isAvailable: true,
          ),
          product_model.Product(
            name: 'Bluetooth Speaker',
            price: 49.99,
            isAvailable: true,
          ),
          product_model.Product(
            name: 'Phone Case',
            price: 24.99,
            isAvailable: true,
          ),
        ];

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _todayRevenue = 0.0;
  double _todayOrderCount = 0.0;
  double _todayExpenses = 0.0;
  double _todayProfit = 0.0;
  late final Box<order_model.Ruci> _ruciBox;
  Box<expence>? _expenceBox; // Change to nullable

  @override
  void initState() {
    super.initState();
    _ruciBox = widget.objectbox.store.box<order_model.Ruci>();
    _expenceBox = widget.objectbox.store.box<expence>(); // Initialize
    _calculateRevenue();
    _calculateOrderCount();
    _calculateExpense(); // Calculate expenses
    _calculateProfit(); // Calculate profit
  }

  Future<void> _calculateProfit() async {
    try {
      final profit = _todayRevenue - _todayExpenses;
      debugPrint('Today\'s total profit: \$${profit.toStringAsFixed(2)}');
      if (mounted) {
        setState(() {
          // Assuming you want to store profit somewhere
          _todayProfit = profit; // Uncomment and define _todayProfit if needed
        });
      }
    } catch (e) {
      debugPrint('Error calculating profit: $e');
    }
  }

  Future<void> _calculateExpense() async {
    try {
      final DateTime todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final DateTime todayEnd = todayStart.add(const Duration(days: 1));
      final query = _expenceBox!
          .query(expence_.date.between(
            todayStart.millisecondsSinceEpoch,
            todayEnd.millisecondsSinceEpoch,
          ))
          .build();
      final todayExpenses = query.find();
      query.close();
      double totalExpenses = 0.0;
      for (final exp in todayExpenses) {
        totalExpenses += exp.amount;
      }
      debugPrint(
          'Today\'s total expenses: \$${totalExpenses.toStringAsFixed(2)}');
      if (mounted) {
        setState(() {
          // Assuming you want to store expenses in _todayRevenue for now
          _todayExpenses = totalExpenses; // Subtract expenses from revenue
        });
      }
    } catch (e) {
      debugPrint('Error calculating expenses: $e');
    }
  }

  Future<void> _calculateOrderCount() async {
    try {
      final DateTime todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final DateTime todayEnd = todayStart.add(const Duration(days: 1));
      final query = _ruciBox
          .query(Ruci_.date.between(
            todayStart.millisecondsSinceEpoch,
            todayEnd.millisecondsSinceEpoch,
          ))
          .build();
      final todayOrders = query.find();
      query.close();
      int orderCount = todayOrders.length;
      debugPrint('Today\'s total orders: $orderCount');
      if (mounted) {
        setState(() {
          _todayOrderCount = orderCount.toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error calculating order count: $e');
    }
  }

  double calculateItemTotal(OrderItem item) {
    double total = item.quantity * (item.product.target?.price ?? 0.0);
    for (final extra in item.extras) {
      total += extra.price * item.getExtraQuantity(extra);
    }
    return total;
  }

  Future<void> _calculateRevenue() async {
    try {
      final DateTime todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final DateTime todayEnd = todayStart.add(const Duration(days: 1));
      final query = _ruciBox
          .query(Ruci_.date.between(
            todayStart.millisecondsSinceEpoch,
            todayEnd.millisecondsSinceEpoch,
          ))
          .build();
      final todayOrders = query.find();
      query.close();
      double totalRevenue = 0.0;
      for (final ruci in todayOrders) {
        for (final orderItem in ruci.items) {
          totalRevenue += calculateItemTotal(orderItem);
        }
      }
      debugPrint(
          'Today\'s total revenue: \$${totalRevenue.toStringAsFixed(2)}');
      if (mounted) {
        setState(() {
          _todayRevenue = totalRevenue;
        });
      }
    } catch (e) {
      debugPrint('Error calculating revenue: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Info Cards in a row
            Row(
              children: [
                Expanded(
                  child: InfoCard(
                    title: "Today's Revenue",
                    value: '${_todayRevenue.toStringAsFixed(2)} DH',
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InfoCard(
                    title: 'Orders',
                    value: '${_todayOrderCount.toInt()}',
                    icon: Icons.shopping_cart,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: InfoCard(
                    title: 'Expenses',
                    value: '${_todayExpenses.toInt()} DH',
                    icon: Icons.money_off,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InfoCard(
                    title: 'Profit',
                    value: '${_todayProfit.toStringAsFixed(2)} DH',
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Chart
            SizedBox(
              height: 300,
              child: WeeklyPerformanceChart(
                store: widget.objectbox.store,
                title: 'Weekly Sales & Orders',
                maxYValue: 2000.0,
              ),
            ),

            const SizedBox(height: 20),

            // Best Sellers Section
            // Container(
            //   height: 200,
            //   child: best_seller.ProductCardsRow(
            //     products: widget.myProducts
            //         .map((p) => best_seller.Product(
            //               title: p.name,
            //               price: '\$${p.price.toStringAsFixed(2)}',
            //               rank: '#${widget.myProducts.indexOf(p) + 1}',
            //               rankColor:
            //                   _getRankColor(widget.myProducts.indexOf(p)),
            //             ))
            //         .toList(),
            //     sectionTitle: 'Best Sellers',
            //     scrollable: true,
            //   ),
            // ),

            const SizedBox(height: 20),

            // Expense Tracking Section - Only show if _expenceBox is initialized
            if (_expenceBox != null)
              SizedBox(
                height: 200,
                child: AddableListWidget(
                  expenceBox: _expenceBox!,
                  onListChanged: (newExpenses) {
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      _calculateExpense();
                      _calculateProfit();
                    });
                  },
                ),
              )
            else
              SizedBox(
                height: 200,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int index) {
    final colors = [Colors.amber, Colors.blue, Colors.green, Colors.purple];
    return colors[index % colors.length];
  }

  @override
  void dispose() {
    super.dispose();
  }
}
