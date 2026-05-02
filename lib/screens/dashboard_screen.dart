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
import '../models/game_session.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../service/business_day_helper.dart';
import '../models/store_config.dart';

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
  late final Box<GameSession> _gameSessionBox;
  late final Box<AppUser> _userBox;
  late final Box<StoreConfig> _storeConfigBox;
  Box<expence>? _expenceBox; 

  late DateTime _startDate;
  late DateTime _endDate;
  late StoreConfig _config;
  int? _selectedUserId;
  List<AppUser> _allUsers = [];
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _ruciBox = widget.objectbox.store.box<order_model.Ruci>();
    _dailyFundsBox = widget.objectbox.store.box<DailyFunds>();
    _gameSessionBox = widget.objectbox.store.box<GameSession>();
    _userBox = widget.objectbox.store.box<AppUser>();
    _expenceBox = widget.objectbox.store.box<expence>(); // Initialize
    _storeConfigBox = widget.objectbox.store.box<StoreConfig>();
    _loadConfig();
    
    // Initial load
    _allUsers = _userBox.getAll();
    _refreshData();

    // Setup real-time listeners
    _subscriptions.add(_userBox.query().watch(triggerImmediately: true).listen((_) {
      if (mounted) {
        setState(() {
          _allUsers = _userBox.getAll();
        });
      }
    }));

    _subscriptions.add(_ruciBox.query().watch().listen((_) => _refreshData()));
    _subscriptions.add(_gameSessionBox.query().watch().listen((_) => _refreshData()));
    _subscriptions.add(_expenceBox!.query().watch().listen((_) => _refreshData()));
  }

  void _loadConfig() {
    final configs = _storeConfigBox.getAll();
    _config = configs.isNotEmpty ? configs.first : StoreConfig();
    final businessDate = BusinessDayHelper.getBusinessDayDate(DateTime.now(), _config);
    final range = BusinessDayHelper.getBusinessDayRange(businessDate, _config);
    _startDate = range.$1;
    _endDate = range.$2.subtract(const Duration(seconds: 1)); // End at 1 sec before next day start
  }

  void _refreshData() async {
    // Collect all data synchronously where possible or in parallel
    final results = await Future.wait([
      _getRevenue(),
      _getOrderCount(),
      _getExpense(),
      _getTodayFunds(),
    ]);

    if (mounted) {
      setState(() {
        _todayRevenue = results[0];
        _todayOrderCount = results[1];
        _todayExpenses = results[2];
        _todayFunds = results[3];
        _todayProfit = _todayRevenue - _todayExpenses;
        _fundsAlreadySet = _todayFunds > 0 || _checkIfFundsExist();
      });
    }
  }

  bool _checkIfFundsExist() {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final query = _dailyFundsBox.query(DailyFunds_.date.equals(todayStart.millisecondsSinceEpoch)).build();
    final count = query.count();
    query.close();
    return count > 0;
  }

  Future<double> _getRevenue() async {
    // Implementation moved from _calculateRevenue but returning value
    try {
      final orderQueryBuilder = _ruciBox.query(Ruci_.date
              .between(_startDate.millisecondsSinceEpoch, _endDate.millisecondsSinceEpoch)
              .and(Ruci_.isDeleted.equals(false)));
      if (_selectedUserId != null) {
        orderQueryBuilder.link(Ruci_.user, AppUser_.id.equals(_selectedUserId!));
      }
      final orderQuery = orderQueryBuilder.build();
      final periodOrders = orderQuery.find();
      orderQuery.close();

      double totalRevenue = 0.0;
      for (final ruci in periodOrders) {
        for (final orderItem in ruci.items) {
          totalRevenue += calculateItemTotal(orderItem);
        }
      }

      Condition<GameSession> gameCondition = GameSession_.startTime
          .between(_startDate.millisecondsSinceEpoch, _endDate.millisecondsSinceEpoch)
          .and(GameSession_.status.equals(1));
      if (_selectedUserId != null) {
        gameCondition = gameCondition.and(GameSession_.attributedUserId.equals(_selectedUserId!));
      }
      final gameQuery = _gameSessionBox.query(gameCondition).build();
      final periodGames = gameQuery.find();
      gameQuery.close();

      for (final session in periodGames) {
        if (session.relatedOrderId == null || session.relatedOrderId == 0) {
          totalRevenue += session.currentCalculatedPrice;
        }
      }
      return totalRevenue;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getOrderCount() async {
    try {
      final orderQueryBuilder = _ruciBox.query(Ruci_.date
              .between(_startDate.millisecondsSinceEpoch, _endDate.millisecondsSinceEpoch)
              .and(Ruci_.isDeleted.equals(false)));
      if (_selectedUserId != null) {
        orderQueryBuilder.link(Ruci_.user, AppUser_.id.equals(_selectedUserId!));
      }
      final orderQuery = orderQueryBuilder.build();
      final orderCount = orderQuery.count();
      orderQuery.close();

      Condition<GameSession> gameCondition = GameSession_.startTime
          .between(_startDate.millisecondsSinceEpoch, _endDate.millisecondsSinceEpoch)
          .and(GameSession_.status.equals(1));
      if (_selectedUserId != null) {
        gameCondition = gameCondition.and(GameSession_.attributedUserId.equals(_selectedUserId!));
      }
      final gameQuery = _gameSessionBox.query(gameCondition).build();
      int unlinkedGames = 0;
      for (final session in gameQuery.find()) {
        if (session.relatedOrderId == null || session.relatedOrderId == 0) {
          unlinkedGames++;
        }
      }
      gameQuery.close();

      return (orderCount + unlinkedGames).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getExpense() async {
    try {
      final query = _expenceBox!.query(expence_.date.between(_startDate.millisecondsSinceEpoch, _endDate.millisecondsSinceEpoch)).build();
      final periodExpenses = query.find();
      query.close();
      double total = 0.0;
      for (final exp in periodExpenses) total += exp.amount;
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _getTodayFunds() async {
    try {
      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      // Try to get today's funds first
      final todayQuery = _dailyFundsBox.query(DailyFunds_.date.between(todayStart.millisecondsSinceEpoch, todayEnd.millisecondsSinceEpoch)).build();
      final todayResult = todayQuery.find();
      todayQuery.close();
      
      if (todayResult.isNotEmpty) {
        return todayResult.first.amount;
      }

      // If not found, get the most recent funds from the past
      final latestQuery = _dailyFundsBox.query().order(DailyFunds_.date, flags: Order.descending).build();
      final latestResult = latestQuery.findFirst();
      latestQuery.close();

      return latestResult?.amount ?? 0.0;
    } catch (e) {
      return 0.0;
    }
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
        _refreshData();
      }
    } catch (e) {
      debugPrint('Error saving funds: $e');
    }
  }

  void _showFundsDialog() {
    final currentFunds = _fundsAlreadySet
        ? DailyFunds(date: DateTime.now(), amount: _todayFunds)
        : null;

    showDialog(
      context: context,
      builder: (ctx) => DailyFundsDialog(
        currentFunds: currentFunds,
        onSave: (amount) {
          _saveFunds(amount);
        },
      ),
    );
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

  void _showUnitsSoldPopup() {
    final queryBuilder = _ruciBox.query(Ruci_.date
            .between(
              _startDate.millisecondsSinceEpoch,
              _endDate.millisecondsSinceEpoch,
            )
            .and(Ruci_.isDeleted.equals(false)));
    
    if (_selectedUserId != null) {
      queryBuilder.link(Ruci_.user, AppUser_.id.equals(_selectedUserId!));
    }

    final query = queryBuilder.build();
    final periodOrders = query.find();
    query.close();

    final Map<String, int> productCounts = {};
    for (final ruci in periodOrders) {
      for (final item in ruci.items) {
        final productName = item.productName ?? item.product.target?.name ?? 'Inconnu';
        productCounts[productName] = (productCounts[productName] ?? 0) + item.quantity;
      }
    }

    // 2. Add Game Sessions
    Condition<GameSession> gameCondition = GameSession_.startTime
        .between(_startDate.millisecondsSinceEpoch, _endDate.millisecondsSinceEpoch)
        .and(GameSession_.status.equals(1)); // Completed only
    
    if (_selectedUserId != null) {
      gameCondition = gameCondition.and(GameSession_.attributedUserId.equals(_selectedUserId!));
    }

    final gameQuery = _gameSessionBox.query(gameCondition).build();
    final periodGames = gameQuery.find();
    gameQuery.close();

    for (final session in periodGames) {
      if (session.relatedOrderId == null || session.relatedOrderId == 0) {
        final gameLabel = 'Jeux: ${session.tierLabel}';
        productCounts[gameLabel] = (productCounts[gameLabel] ?? 0) + 1;
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
                      child: DropdownButton<int?>(
                        value: _selectedUserId,
                        hint: const Text('Tous les Utilisateurs', style: TextStyle(fontSize: 13)),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Tous les Utilisateurs', style: TextStyle(fontSize: 13)),
                          ),
                          ..._allUsers.map((user) => DropdownMenuItem<int?>(
                                value: user.id,
                                child: Text(user.name, style: const TextStyle(fontSize: 13)),
                              )),
                        ],
                        onChanged: (userId) {
                          setState(() {
                            _selectedUserId = userId;
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
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
