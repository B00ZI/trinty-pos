// P51: dart:io + path_provider removed with the export buttons — they
// only served the Android-only folder the dead exports wrote to.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../objectbox.g.dart';
import '../models/order.dart' as order_model;
import '../models/order_item.dart';
import '../models/game_session.dart';
import '../models/app_user.dart';
import '../models/product.dart';
import '../models/expense.dart';
import '../models/daily_funds.dart';
import '../models/store_config.dart';
import 'package:objectbox/objectbox.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_colors.dart';

class DevPanelScreen extends ConsumerStatefulWidget {
  const DevPanelScreen({super.key});

  @override
  ConsumerState<DevPanelScreen> createState() => _DevPanelScreenState();
}

class _DevPanelScreenState extends ConsumerState<DevPanelScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  int _totalOrders = 0;
  int _totalOrderItems = 0;
  int _totalGameSessions = 0;
  int _totalUsers = 0;
  int _totalProducts = 0;

  List<Map<String, dynamic>> _userStats = [];
  final List<Map<String, dynamic>> _unassignedDetails = [];
  final List<int> _missingOrderNumbers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(
            picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _isLoading = true;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final store = ref.read(objectBoxProvider).store;
    final ruciBox = store.box<order_model.Order>();
    final gameSessionBox = store.box<GameSession>();
    final userBox = store.box<AppUser>();
    final productBox = store.box<Product>();

    _totalUsers = userBox.count();
    _totalProducts = productBox.count();

    // Query active orders (not deleted)
    QueryBuilder<order_model.Order> orderQb =
        ruciBox.query(Order_.isDeleted.equals(false));
    if (_startDate != null && _endDate != null) {
      orderQb = ruciBox.query(Order_.isDeleted.equals(false).and(Order_.date
          .between(_startDate!.millisecondsSinceEpoch,
              _endDate!.millisecondsSinceEpoch)));
    }
    final orderQuery = orderQb.build();
    final allOrders = orderQuery.find();
    orderQuery.close();

    // Query game sessions
    QueryBuilder<GameSession> gameQb =
        gameSessionBox.query(GameSession_.status.equals(1));
    if (_startDate != null && _endDate != null) {
      gameQb = gameSessionBox.query(GameSession_.status.equals(1).and(
          GameSession_.startTime.between(_startDate!.millisecondsSinceEpoch,
              _endDate!.millisecondsSinceEpoch)));
    }
    final gameQuery = gameQb.build();
    final allGames = gameQuery.find();
    gameQuery.close();

    _totalOrders = allOrders.length;
    _totalGameSessions = allGames.length;
    _totalOrderItems =
        allOrders.fold<int>(0, (sum, order) => sum + order.items.length);

    // Fetch config for calculateItemTotal
    final configs = store.box<StoreConfig>().getAll();
    final config = configs.isNotEmpty ? configs.first : StoreConfig();

    double calculateItemTotal(OrderItem item) {
      double basePrice =
          (item.price ?? item.product.target?.price ?? 0.0).toDouble();
      if (item.price == null && config.isSurgePriceEnabled) {
        if (config.surgeProductIds.contains(item.product.target?.id)) {
          basePrice += config.surgePriceAmount;
        }
      }
      double total = item.quantity * basePrice;
      final extrasMultiplier = item.isPerUnitExtras ? item.quantity : 1;
      for (final extra in item.resolveExtras()) {
        total += extra.price * extra.quantity * extrasMultiplier;
      }
      return total;
    }

    Map<int?, double> userRevenues = {};
    Map<int?, int> userOrderCounts = {};
    Map<int?, String> userNames = {};

    for (final u in userBox.getAll()) {
      userRevenues[u.id] = 0.0;
      userOrderCounts[u.id] = 0;
      userNames[u.id] = u.name;
    }
    userRevenues[null] = 0.0;
    userOrderCounts[null] = 0;
    userNames[null] = "UNASSIGNED / MISSING USER";

    _unassignedDetails.clear();

    for (final order in allOrders) {
      final uid = order.user.targetId == 0 ? null : order.user.targetId;
      userOrderCounts[uid] = (userOrderCounts[uid] ?? 0) + 1;

      double orderTotal = 0;
      for (final item in order.items) {
        orderTotal += calculateItemTotal(item);
      }
      userRevenues[uid] = (userRevenues[uid] ?? 0.0) + orderTotal;

      if (uid == null) {
        _unassignedDetails.add({
          'type': 'Order',
          'id': order.id,
          'number': order.orderNumber,
          'revenue': orderTotal,
        });
      }
    }

    for (final session in allGames) {
      if (session.relatedOrderId == null || session.relatedOrderId == 0) {
        final uid =
            session.attributedUserId == 0 ? null : session.attributedUserId;
        userRevenues[uid] =
            (userRevenues[uid] ?? 0.0) + session.currentCalculatedPrice;

        if (uid == null) {
          _unassignedDetails.add({
            'type': 'Game',
            'id': session.id,
            'number': 'N/A',
            'revenue': session.currentCalculatedPrice,
          });
        }
      }
    }

    _userStats = userRevenues.keys.map((uid) {
      return {
        'id': uid,
        'name': userNames[uid] ?? "UNKNOWN ($uid)",
        'orders': userOrderCounts[uid] ?? 0,
        'revenue': userRevenues[uid] ?? 0.0,
      };
    }).toList();

    // Missing Orders Check
    QueryBuilder<order_model.Order> allOrdersQb = ruciBox.query();
    if (_startDate != null && _endDate != null) {
      allOrdersQb = ruciBox.query(Order_.date.between(
          _startDate!.millisecondsSinceEpoch,
          _endDate!.millisecondsSinceEpoch));
    }
    final allOrdersQ = allOrdersQb.build();
    final allOrdersIncludingDeleted = allOrdersQ.find();
    allOrdersQ.close();

    allOrdersIncludingDeleted
        .sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    _missingOrderNumbers.clear();
    if (allOrdersIncludingDeleted.isNotEmpty) {
      int expected = allOrdersIncludingDeleted.first.orderNumber;
      for (final order in allOrdersIncludingDeleted) {
        while (expected < order.orderNumber) {
          _missingOrderNumbers.add(expected);
          expected++;
        }
        expected = order.orderNumber + 1;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _deleteAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ SUPPRIMER TOUT L\'HISTORIQUE',
            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
        content: const Text(
            'Cette action supprimera TOUTES les commandes, sessions de jeux, dépenses et fonds.\n\nCette action est IRRÉVERSIBLE.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text('SUPPRIMER TOUT',
                style: TextStyle(color: AppColors.surface0)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final store = ref.read(objectBoxProvider).store;
      store.box<order_model.Order>().removeAll();
      store.box<OrderItem>().removeAll();
      store.box<GameSession>().removeAll();
      store.box<Expense>().removeAll();
      store.box<DailyFunds>().removeAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tout l\'historique a été supprimé.')),
        );
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Developer Panel', style: TextStyle(color: AppColors.danger)),
        backgroundColor: AppColors.ink0,
        actions: [
          IconButton(
            icon: Icon(Icons.date_range, color: AppColors.surface0),
            onPressed: _selectDateRange,
            tooltip: 'Filtrer par date',
          ),
          // P51: the two former export buttons (Export SQL / Export DB)
          // are gone — they wrote to an Android-only folder, so on
          // Windows they did nothing at all. The real Sauvegarde button
          // (Paramètres) does exports on both platforms.
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_startDate != null && _endDate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Filtré du: ${DateFormat('dd/MM/yyyy').format(_startDate!)} au ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                                _isLoading = true;
                              });
                              _loadData();
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  const Text('Database Stats',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatCard('Orders', _totalOrders),
                      _buildStatCard('Items', _totalOrderItems),
                      _buildStatCard('Games', _totalGameSessions),
                      _buildStatCard('Users', _totalUsers),
                      _buildStatCard('Products', _totalProducts),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('Revenue & Orders by User',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userStats.length,
                    itemBuilder: (context, index) {
                      final stat = _userStats[index];
                      final isUnassigned = stat['id'] == null;
                      return Card(
                        color: isUnassigned && stat['revenue'] > 0
                            ? AppColors.dangerLight
                            : null,
                        child: ListTile(
                          title: Text(stat['name'],
                              style: TextStyle(
                                  color: isUnassigned ? AppColors.danger : null,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text('Orders: ${stat['orders']}'),
                          trailing: Text(
                              '${stat['revenue'].toStringAsFixed(2)} DH',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      );
                    },
                  ),
                  if (_unassignedDetails.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Unassigned Details',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger)),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _unassignedDetails.length,
                      itemBuilder: (context, index) {
                        final d = _unassignedDetails[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                              d['type'] == 'Order'
                                  ? Icons.receipt
                                  : Icons.sports_esports,
                              color: AppColors.danger,
                              size: 20),
                          title: Text('${d['type']} ID: ${d['id']}'),
                          subtitle: Text('Number: ${d['number']}'),
                          trailing:
                              Text('${d['revenue'].toStringAsFixed(2)} DH'),
                        );
                      },
                    ),
                  ],
                  const Divider(height: 32),
                  const Text('Missing Order Numbers (Gaps)',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_missingOrderNumbers.isEmpty)
                    Text('No missing order numbers found.',
                        style: TextStyle(color: AppColors.success)),
                  if (_missingOrderNumbers.isNotEmpty)
                    Text(_missingOrderNumbers.join(', '),
                        style: TextStyle(color: AppColors.danger),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: AppColors.surface0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('SUPPRIMER TOUT L\'HISTORIQUE',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _deleteAllHistory,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, int count) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: AppColors.ink3)),
            Text(count.toString(),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
