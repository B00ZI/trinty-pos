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
import '../models/daily_funds.dart';
import '../widgets/daily_funds_dialog.dart';
import '../models/app_user.dart';
import 'package:intl/intl.dart';

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
  double _todayFunds = 0.0;
  bool _fundsAlreadySet = false;
  late final Box<order_model.Ruci> _ruciBox;
  late final Box<DailyFunds> _dailyFundsBox;
  late final Box<AppUser> _userBox;
  Box<expence>? _expenceBox; // Change to nullable

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);
  AppUser? _selectedUserFilter;
  List<AppUser> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _ruciBox = widget.objectbox.store.box<order_model.Ruci>();
    _dailyFundsBox = widget.objectbox.store.box<DailyFunds>();
    _userBox = widget.objectbox.store.box<AppUser>();
    _expenceBox = widget.objectbox.store.box<expence>(); // Initialize
    _allUsers = _userBox.getAll();
    _refreshData();
  }

  void _refreshData() {
    _calculateRevenue();
    _calculateOrderCount();
    _calculateExpense(); // Calculate expenses
    _calculateProfit(); // Calculate profit
    _loadTodayFunds(); // Load today's funds
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _refreshData();
    }
  }

  Future<void> _calculateProfit() async {
    try {
      final profit = _todayRevenue - _todayExpenses;
      if (mounted) {
        setState(() {
          _todayProfit = profit;
        });
      }
    } catch (e) {
      debugPrint('Error calculating profit: $e');
    }
  }

  Future<void> _loadTodayFunds() async {
    try {
      final DateTime todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final DateTime todayEnd = todayStart.add(const Duration(days: 1));
      final query = _dailyFundsBox
          .query(DailyFunds_.date.between(
            todayStart.millisecondsSinceEpoch,
            todayEnd.millisecondsSinceEpoch,
          ))
          .build();
      final result = query.find();
      query.close();

      if (mounted) {
        setState(() {
          if (result.isNotEmpty) {
            _todayFunds = result.first.amount;
            _fundsAlreadySet = true;
          } else {
            // Find the latest recorded funds as a fallback
            final latestQuery = _dailyFundsBox
                .query()
                .order(DailyFunds_.date, flags: Order.descending)
                .build();
            final latestResult = latestQuery.findFirst();
            latestQuery.close();

            _todayFunds = latestResult?.amount ?? 0.0;
            _fundsAlreadySet = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading today\'s funds: $e');
    }
  }

  Future<void> _saveFunds(double amount) async {
    try {
      final DateTime todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);

      // Check if funds already exist for today
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

      if (mounted) {
        setState(() {
          _todayFunds = amount;
          _fundsAlreadySet = true;
        });
      }
    } catch (e) {
      debugPrint('Error saving funds: $e');
    }
  }

  void _showFundsDialog() {
    final currentFunds = DailyFunds(date: DateTime.now(), amount: _todayFunds);

    showDialog(
      context: context,
      builder: (ctx) => DailyFundsDialog(
        currentFunds: currentFunds,
        isAlreadySet: _fundsAlreadySet,
        onSave: (amount) {
          _saveFunds(amount);
        },
      ),
    );
  }

  Future<void> _calculateExpense() async {
    try {
      final queryBuilder = _expenceBox!
          .query(expence_.date.between(
            _startDate.millisecondsSinceEpoch,
            _endDate.millisecondsSinceEpoch,
          ));
      
      final query = queryBuilder.build();
      final periodExpenses = query.find();
      query.close();

      double totalExpenses = 0.0;
      for (final exp in periodExpenses) {
        totalExpenses += exp.amount;
      }
      if (mounted) {
        setState(() {
          _todayExpenses = totalExpenses;
        });
      }
    } catch (e) {
      debugPrint('Error calculating expenses: $e');
    }
  }

  Future<void> _calculateOrderCount() async {
    try {
      final queryBuilder = _ruciBox.query(Ruci_.date
              .between(
                _startDate.millisecondsSinceEpoch,
                _endDate.millisecondsSinceEpoch,
              )
              .and(Ruci_.isDeleted.equals(false)));
      
      if (_selectedUserFilter != null) {
        queryBuilder.link(Ruci_.user, AppUser_.id.equals(_selectedUserFilter!.id));
      }

      final query = queryBuilder.build();
      final periodOrders = query.find();
      query.close();
      
      if (mounted) {
        setState(() {
          _todayOrderCount = periodOrders.length.toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error calculating order count: $e');
    }
  }

  double calculateItemTotal(OrderItem item) {
    // Use persisted price if available, otherwise fallback to current product price
    double basePrice = (item.price ?? item.product.target?.price ?? 0.0).toDouble();
    double total = item.quantity * basePrice;
    for (final extra in item.extras) {
      total += extra.price * item.getExtraQuantity(extra);
    }
    return total;
  }

  Future<void> _calculateRevenue() async {
    try {
      final queryBuilder = _ruciBox.query(Ruci_.date
              .between(
                _startDate.millisecondsSinceEpoch,
                _endDate.millisecondsSinceEpoch,
              )
              .and(Ruci_.isDeleted.equals(false)));
      
      if (_selectedUserFilter != null) {
        queryBuilder.link(Ruci_.user, AppUser_.id.equals(_selectedUserFilter!.id));
      }

      final query = queryBuilder.build();
      final periodOrders = query.find();
      query.close();

      double totalRevenue = 0.0;
      for (final ruci in periodOrders) {
        for (final orderItem in ruci.items) {
          totalRevenue += calculateItemTotal(orderItem);
        }
      }
      if (mounted) {
        setState(() {
          _todayRevenue = totalRevenue;
        });
      }
    } catch (e) {
      debugPrint('Error calculating revenue: $e');
    }
  }

  void _showUnitsSoldPopup() {
    final queryBuilder = _ruciBox.query(Ruci_.date
            .between(
              _startDate.millisecondsSinceEpoch,
              _endDate.millisecondsSinceEpoch,
            )
            .and(Ruci_.isDeleted.equals(false)));
    
    if (_selectedUserFilter != null) {
      queryBuilder.link(Ruci_.user, AppUser_.id.equals(_selectedUserFilter!.id));
    }

    final query = queryBuilder.build();
    final periodOrders = query.find();
    query.close();

    final Map<String, int> productCounts = {};
    for (final ruci in periodOrders) {
      for (final item in ruci.items) {
        // Use persisted name if available, otherwise fallback to current product name
        final productName = item.productName ?? item.product.target?.name ?? 'Inconnu';
        productCounts[productName] = (productCounts[productName] ?? 0) + item.quantity;
      }
    }

    final sortedItems = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unités Vendues'),
        content: SizedBox(
          width: 400, // Fixed width
          height: 500, // Fixed height
          child: sortedItems.isEmpty
              ? const Center(child: Text('Aucune vente sur cette période'))
              : ListView.builder(
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
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filters Section
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM').format(_endDate)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AppUser?>(
                        value: _selectedUserFilter,
                        hint: const Text('Tous les Utilisateurs', style: TextStyle(fontSize: 13)),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<AppUser?>(
                            value: null,
                            child: Text('Tous les Utilisateurs', style: TextStyle(fontSize: 13)),
                          ),
                          ..._allUsers.map((user) => DropdownMenuItem<AppUser?>(
                                value: user,
                                child: Text(user.name, style: const TextStyle(fontSize: 13)),
                              )),
                        ],
                        onChanged: (user) {
                          setState(() {
                            _selectedUserFilter = user;
                          });
                          _refreshData();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Stack(
              children: [
                // 2x2 Grid of Cards
                Column(
                  children: [
                    // Top Row: Revenue + Orders
                    Row(
                      children: [
                        Expanded(
                          child: InfoCard(
                            title: "Revenu",
                            value: '${_todayRevenue.toStringAsFixed(2)} DH',
                            icon: Icons.attach_money,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showUnitsSoldPopup,
                            child: InfoCard(
                              title: 'Commandes',
                              value: '${_todayOrderCount.toInt()}',
                              icon: Icons.shopping_cart,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Bottom Row: Expenses + Profit
                    Row(
                      children: [
                        Expanded(
                          child: InfoCard(
                            title: 'Dépenses',
                            value: '${_todayExpenses.toInt()} DH',
                            icon: Icons.money_off,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InfoCard(
                            title: 'Bénéfice',
                            value: '${_todayProfit.toStringAsFixed(2)} DH',
                            icon: Icons.trending_up,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Circular Funds Widget
                Positioned(
                  top: 70,
                  left: 10,
                  right: 20,
                  child: Center(
                    child: GestureDetector(
                      onTap: _showFundsDialog,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primaryContainer,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_todayFunds.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  'DH',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Fond de caisse',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                title: 'Performance Hebdomadaire',
                maxYValue: 2000.0,
              ),
            ),

            const SizedBox(height: 20),

            // Expense Tracking Section
            if (_expenceBox != null)
              SizedBox(
                height: 200,
                child: AddableListWidget(
                  expenceBox: _expenceBox!,
                  onListChanged: (newExpenses) {
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      _refreshData();
                    });
                  },
                ),
              )
            else
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
