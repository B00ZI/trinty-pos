import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../objectbox.dart';
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

class DevPanelScreen extends StatefulWidget {
  final ObjectBox objectbox;

  const DevPanelScreen({super.key, required this.objectbox});

  @override
  State<DevPanelScreen> createState() => _DevPanelScreenState();
}

class _DevPanelScreenState extends State<DevPanelScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  int _totalOrders = 0;
  int _totalOrderItems = 0;
  int _totalGameSessions = 0;
  int _totalUsers = 0;
  int _totalProducts = 0;

  List<Map<String, dynamic>> _userStats = [];
  List<Map<String, dynamic>> _unassignedDetails = [];
  List<int> _missingOrderNumbers = [];

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
    final store = widget.objectbox.store;
    final ruciBox = store.box<order_model.Order>();
    final orderItemBox = store.box<OrderItem>();
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
      for (final extra in item.extras) {
        total += extra.price * item.getExtraQuantity(extra);
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

  Future<void> _exportDb() async {
    try {
      final storePath = widget.objectbox.store.directoryPath;
      final externalDir = await getExternalStorageDirectory();

      if (externalDir != null) {
        final backupDir = Directory(
            '${externalDir.path}/EasifyBackup_${DateTime.now().millisecondsSinceEpoch}');
        await backupDir.create(recursive: true);

        final dbDir = Directory(storePath);
        for (final entity in dbDir.listSync()) {
          if (entity is File) {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            await entity.copy('${backupDir.path}/$fileName');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('DB exported to:\n${backupDir.path}', maxLines: 3)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportSql() async {
    try {
      final store = widget.objectbox.store;
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return;

      final fileName = 'Easify_export_${DateTime.now().toIso8601String()}.sql';
      final outFile = File('${externalDir.path}/$fileName');
      final sb = StringBuffer();

      String esc(Object? v) {
        if (v == null) return 'NULL';
        final s = v.toString();
        return "'" + s.replaceAll("'", "''") + "'";
      }

      // Export Products
      final productBox = store.box<Product>();
      final products = productBox.getAll();
      sb.writeln('-- Products');
      for (final p in products) {
        sb.writeln(
            'INSERT INTO products (id, name, price, category, description, imageUrl, isAvailable, displayOrder) VALUES ('
            '${p.id}, ${esc(p.name)}, ${p.price}, ${esc(p.category)}, ${esc(p.description)}, ${esc(p.imageUrl)}, ${p.isAvailable ? 1 : 0}, ${p.displayOrder});');
      }
      sb.writeln();

      // Export Users
      final userBox = store.box<AppUser>();
      final users = userBox.getAll();
      sb.writeln('-- Users');
      for (final u in users) {
        sb.writeln(
            'INSERT INTO users (id, name, pin, isAdmin, createdAt) VALUES ('
            '${u.id}, ${esc(u.name)}, ${esc(u.pin)}, ${u.isAdmin ? 1 : 0}, ${esc(u.createdAt.toIso8601String())});');
      }
      sb.writeln();

      // Export StoreConfig
      final cfgBox = store.box<StoreConfig>();
      final cfgs = cfgBox.getAll();
      sb.writeln('-- StoreConfig');
      for (final c in cfgs) {
        sb.writeln(
            'INSERT INTO store_config (id, storeName, storePhone, storeLogoPath, wifiPassword, dayStartHour, dayStartMinute, dayEndHour, dayEndMinute, isSurgePriceEnabled, surgePriceAmount, surgeProductIds) VALUES ('
            '${c.id}, ${esc(c.storeName)}, ${esc(c.storePhone)}, ${esc(c.storeLogoPath)}, ${esc(c.wifiPassword)}, ${c.dayStartHour}, ${c.dayStartMinute}, ${c.dayEndHour}, ${c.dayEndMinute}, ${c.isSurgePriceEnabled ? 1 : 0}, ${c.surgePriceAmount}, ${esc(c.surgeProductIds.join(","))});');
      }
      sb.writeln();

      // Export Orders and OrderItems
      final ruciBox = store.box<order_model.Order>();
      final orders = ruciBox.getAll();
      sb.writeln('-- Orders');
      for (final o in orders) {
        final userId =
            o.user.targetId == 0 ? 'NULL' : o.user.targetId.toString();
        sb.writeln(
            'INSERT INTO orders (id, orderNumber, date, isDeleted, isEdited, relatedGameSessionId, userId) VALUES ('
            '${o.id}, ${o.orderNumber}, ${esc(o.date.toIso8601String())}, ${o.isDeleted ? 1 : 0}, ${o.isEdited ? 1 : 0}, ${o.relatedGameSessionId ?? 'NULL'}, ${userId});');

        // items
        for (final item in o.items) {
          final prodId = item.product.target?.id ?? 0;
          final extrasJson = item.extraQuantitiesJson != null
              ? item.extraQuantitiesJson!.replaceAll("'", "''")
              : '';
          sb.writeln(
              'INSERT INTO order_items (id, orderId, productId, quantity, extraQuantitiesJson, price, productName) VALUES ('
              '${item.id}, ${o.id}, ${prodId}, ${item.quantity}, ${esc(extrasJson)}, ${item.price ?? 'NULL'}, ${esc(item.productName)});');
        }
      }
      sb.writeln();

      // Export GameSessions
      final gameBox = store.box<GameSession>();
      final games = gameBox.getAll();
      sb.writeln('-- GameSessions');
      for (final g in games) {
        sb.writeln(
            'INSERT INTO game_sessions (id, postId, tierId, postLabel, partyNumber, tierLabel, startTime, endTime, status, ratePerHour, attributedUserId, relatedOrderId, isLimitedDuration, limitedDurationMinutes) VALUES ('
            '${g.id}, ${g.postId}, ${g.tierId}, ${esc(g.postLabel)}, ${g.partyNumber}, ${esc(g.tierLabel)}, ${esc(g.startTime.toIso8601String())}, ${g.endTime != null ? esc(g.endTime!.toIso8601String()) : 'NULL'}, ${g.status}, ${g.ratePerHour}, ${g.attributedUserId ?? 'NULL'}, ${g.relatedOrderId ?? 'NULL'}, ${g.isLimitedDuration ? 1 : 0}, ${g.limitedDurationMinutes});');
      }
      sb.writeln();

      // Export Expenses
      final expBox = store.box<Expense>();
      final exps = expBox.getAll();
      sb.writeln('-- Expenses');
      for (final ex in exps) {
        sb.writeln('INSERT INTO expenses (id, title, amount, date) VALUES ('
            '${ex.id}, ${esc(ex.title)}, ${ex.amount}, ${esc(ex.date.toIso8601String())});');
      }
      sb.writeln();

      // Export DailyFunds
      final dfBox = store.box<DailyFunds>();
      final dfs = dfBox.getAll();
      sb.writeln('-- DailyFunds');
      for (final d in dfs) {
        sb.writeln('INSERT INTO daily_funds (id, date, amount) VALUES ('
            '${d.id}, ${esc(d.date.toIso8601String())}, ${d.amount});');
      }

      await outFile.writeAsString(sb.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('SQL exported to: ${outFile.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export SQL failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Developer Panel', style: TextStyle(color: Colors.red)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: _selectDateRange,
            tooltip: 'Filtrer par date',
          ),
          IconButton(
            icon: const Icon(Icons.article, color: Colors.white),
            onPressed: _exportSql,
            tooltip: 'Export SQL',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: _exportDb,
            tooltip: 'Export DB',
          ),
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
                          const Icon(Icons.filter_alt, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Filtré du: ${DateFormat('dd/MM/yyyy').format(_startDate!)} au ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange),
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
                            ? Colors.red.shade50
                            : null,
                        child: ListTile(
                          title: Text(stat['name'],
                              style: TextStyle(
                                  color: isUnassigned ? Colors.red : null,
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
                    const Text('Unassigned Details',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
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
                              color: Colors.red,
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
                    const Text('No missing order numbers found.',
                        style: TextStyle(color: Colors.green)),
                  if (_missingOrderNumbers.isNotEmpty)
                    Text(_missingOrderNumbers.join(', '),
                        style: const TextStyle(color: Colors.red)),
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
            Text(title, style: const TextStyle(color: Colors.grey)),
            Text(count.toString(),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
