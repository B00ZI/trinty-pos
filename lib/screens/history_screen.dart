import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_item.dart';
import '../objectbox.dart';
import '../objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import '../models/order.dart';
import '../models/printer_config.dart';
import '../models/order_counter.dart'; // Import OrderCounter
import '../widgets/dialog.dart' as custom_dialog;
import '../service/printer_helper.dart';
import 'order_screen.dart' as custom_order_screen;
import '../service/business_day_helper.dart';
import 'package:intl/intl.dart';
import '../widgets/business_day_filter.dart';
import '../models/store_config.dart';
import '../models/game_session.dart';
import '../models/app_user.dart';

class HistoryScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const HistoryScreen({super.key, required this.objectbox});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Box<Ruci> _orderBox;
  late final Box<PrinterConfig> _printerConfigBox;
  late final Box<OrderCounter> _orderCounterBox; // Declare OrderCounter box
  late final Box<StoreConfig> _storeConfigBox;
  bool _showDeletedOrders = false;
  DateTime _selectedBusinessDay = DateTime.now();
  late StoreConfig _config;

  @override
  void initState() {
    super.initState();
    _orderBox = widget.objectbox.store.box<Ruci>();
    _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();
    _orderCounterBox = widget.objectbox.store
        .box<OrderCounter>(); // Initialize OrderCounter box
    _storeConfigBox = widget.objectbox.store.box<StoreConfig>();
    _loadStoreConfig();
  }

  void _loadStoreConfig() {
    final configs = _storeConfigBox.getAll();
    _config = configs.isNotEmpty ? configs.first : StoreConfig();
    _selectedBusinessDay = BusinessDayHelper.getBusinessDayDate(DateTime.now(), _config);
  }
//printing dayliy summary and reset order counter
//  Future<void> _archiveAndReset() async {
//   final allOrders = _orderBox.getAll();
//   if (allOrders.isEmpty) {
//     print('No orders to archive.');
//     _showSnackBar('No orders to archive.');
//     return;
//   }

//   // 1. Generate summary
//   int totalOrders = allOrders.length;
//   double totalRevenue = allOrders.fold<double>(
//     0,
//     (sum, order) => sum + order.items.fold<double>(
//       0, (itemSum, item) => itemSum + calculateItemTotal(item)
//     )
//   );

//   // Count total units sold per product
//   final Map<String, int> productUnitsSold = {};
//   for (final order in allOrders) {
//     for (final item in order.items) {
//       final productName = item.product.target?.name ?? 'Unknown Product';
//       productUnitsSold[productName] = (productUnitsSold[productName] ?? 0) + item.quantity;
//     }
//   }

//   // 2. Print summary
//   final printerConfig = _printerConfigBox.getAll().first;
//   // ignore: unnecessary_null_comparison
//   if (printerConfig != null) {
//     final profile = await CapabilityProfile.load();
//     final printer = NetworkPrinter(PaperSize.mm80, profile);
//     final res = await printer.connect(printerConfig.ipAddress, port: printerConfig.port);

//     if (res == PosPrintResult.success) {
//       printer.text('--- Order Summary ---', styles: const PosStyles(align: PosAlign.center, bold: true));
//       printer.feed(1);
//       printer.text('Total Orders: $totalOrders');
//       // Print units sold per product
//       printer.text('Units Sold per Product:', styles: const PosStyles(bold: true));
//       productUnitsSold.forEach((product, units) {
//         printer.text('- $product: $units');
//       });

//       printer.text('Total Revenue: ${totalRevenue.toStringAsFixed(2)} DH');
//       printer.feed(1);

//       printer.feed(2);
//       printer.cut();
//       printer.disconnect();

//       print('Order summary printed.');
//       _showSnackBar('Order summary printed.');
//     } else {
//       print('Could not connect to printer for summary: $res');
//       _showSnackBar('Could not connect to printer for summary: $res');
//     }
//   } else {
//     print('Printer configuration not found, cannot print summary.');
//     _showSnackBar('Printer configuration not found, cannot print summary.');
//   }

//   // 3. Clear history
//   _orderBox.removeAll();

//   // 4. Reset OrderCounter
//   _resetOrderCounter();
// }

  Future<void> _deleteOrder(Ruci order) async {
    // Soft delete: mark as deleted instead of removing
    order.isDeleted = true;
    _orderBox.put(order);
  }

  // Future<void> _printOrder(Ruci order) async {
  //   try {
  //     // Retrieve printer configuration from the database
  //     final printerConfig = _printerConfigBox.getAll().first;

  //     // ignore: unnecessary_null_comparison
  //     if (printerConfig == null) {
  //       print('Printer configuration not found');
  //       _showSnackBar('Printer configuration not found');
  //       return;
  //     }

  //     final profile = await CapabilityProfile.load();
  //     final printer = NetworkPrinter(PaperSize.mm80, profile);

  //     final res = await printer.connect(printerConfig.ipAddress,
  //         port: printerConfig.port); // Changed line

  //     if (res != PosPrintResult.success) {
  //       print('Could not connect to printer: $res');
  //       _showSnackBar('Could not connect to printer: $res');
  //       return;
  //     }

  //     // Header - Business Name
  //     printer.row([
  //       PosColumn(
  //         text: '------ Easify ------',
  //         width: 12,
  //         styles: const PosStyles(align: PosAlign.center, bold: true),
  //       )
  //     ]);

  //     // Order ID
  //     printer.row([
  //       PosColumn(
  //         text: 'Order ID: ${order.orderNumber}',
  //         width: 12,
  //         styles: const PosStyles(align: PosAlign.center, bold: true),
  //       )
  //     ]);

  //     printer.feed(1);

  //     // Items List
  //     for (final item in order.items) {
  //       final name = item.product.target?.name ?? 'Unknown';
  //       final quantity = item.quantity;
  //       final price = calculateItemTotal(item).toStringAsFixed(2);

  //       printer.row([
  //         PosColumn(
  //           text: '$quantity x $name',
  //           width: 8,
  //           styles: const PosStyles(align: PosAlign.left),
  //         ),
  //         PosColumn(
  //           text: '$price DH',
  //           width: 4,
  //           styles: const PosStyles(align: PosAlign.right),
  //         ),
  //       ]);
  //     }

  //     // Divider
  //     printer.row([
  //       PosColumn(
  //         text: '----------------------------------------',
  //         width: 12,
  //         styles: const PosStyles(align: PosAlign.center),
  //       )
  //     ]);

  //     // Total Calculation
  //     final total = order.items
  //         .fold<double>(0, (sum, item) => sum + calculateItemTotal(item));

  //     printer.row([
  //       PosColumn(
  //         text: 'TOTAL',
  //         width: 8,
  //         styles: const PosStyles(align: PosAlign.left, bold: true),
  //       ),
  //       PosColumn(
  //         text: '${total.toStringAsFixed(2)} DH',
  //         width: 4,
  //         styles: const PosStyles(align: PosAlign.right, bold: true),
  //       ),
  //     ]);

  //     // Divider
  //     printer.row([
  //       PosColumn(
  //         text: '----------------------------------------',
  //         width: 12,
  //         styles: const PosStyles(align: PosAlign.center),
  //       )
  //     ]);

  //     printer.feed(3);
  //     printer.cut();
  //     printer.disconnect();

  //     print('Receipt sent successfully.');
  //     _showSnackBar('Receipt sent successfully.');
  //   } catch (e) {
  //     print('Error during printing: $e');
  //     _showSnackBar('Error during printing: ${e.toString()}');
  //   }
  // }

  // void _showSnackBar(String message) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(message),
  //       duration: const Duration(seconds: 10),
  //     ),
  //   );
  // }

  void _resetOrderCounter() {
    OrderCounter? orderCounter = _orderCounterBox.get(1);
    if (orderCounter == null) {
      orderCounter = OrderCounter(id: 1, value: 1);
    } else {
      orderCounter.value = 1;
    }
    _orderCounterBox.put(orderCounter);
  }

  Stream<List<GameSession>> _getGameSessionsStream() {
    final startOfDay = BusinessDayHelper.getBusinessDayDate(_selectedBusinessDay, _config);
    final endOfDay = startOfDay.add(const Duration(hours: 24));
    return widget.objectbox.gameSessionBox
        .query(GameSession_.startTime.between(startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch))
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  Stream<List<Ruci>> _getOrdersStream() {
    final startOfDay = BusinessDayHelper.getBusinessDayDate(_selectedBusinessDay, _config);
    final endOfDay = startOfDay.add(const Duration(hours: 24));
    return _orderBox
        .query(Ruci_.date.between(startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch))
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  double calculateItemTotal(OrderItem item) {
    double itemTotal = (item.price ?? item.product.target?.price ?? 0.0) * item.quantity;
    for (final extra in item.extras) {
      itemTotal += extra.price * item.getExtraQuantity(extra);
    }
    return itemTotal;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historique'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Commandes', icon: Icon(Icons.receipt_long)),
              Tab(text: 'Parties Jeux', icon: Icon(Icons.sports_esports)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_showDeletedOrders ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _showDeletedOrders = !_showDeletedOrders),
              tooltip: 'Afficher les commandes supprimées',
            ),
          ],
        ),
        body: Column(
          children: [
            BusinessDayFilter(
              selectedDate: _selectedBusinessDay,
              onDateChanged: (date) => setState(() => _selectedBusinessDay = date),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOrdersTab(),
                  _buildPartiesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
    Widget _buildOrdersTab() {
    return StreamBuilder<List<Ruci>>(
      stream: _getOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final orders = snapshot.data!;
        final filteredOrders = _showDeletedOrders 
            ? orders.reversed.toList() 
            : orders.reversed.where((o) => !o.isDeleted).toList();

        if (filteredOrders.isEmpty) return const Center(child: Text('Aucune commande pour cette journée'));
        
        return ListView.builder(
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) => _buildOrderCard(filteredOrders[index]),
        );
      },
    );
  }

  Widget _buildPartiesTab() {
    return StreamBuilder<List<GameSession>>(
      stream: _getGameSessionsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final sessions = snapshot.data!;
        if (sessions.isEmpty) return const Center(child: Text('Aucune partie pour cette journée'));
        
        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, index) => _buildPartyCard(sessions[index]),
        );
      },
    );
  }

  Widget _buildPartyCard(GameSession session) {
    final user = session.attributedUserId != null 
        ? widget.objectbox.userBox.get(session.attributedUserId!)?.name ?? 'Inconnu'
        : 'Système';

    return Card(
      child: ListTile(
        title: Text('${session.postLabel} - Partie #${session.partyNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Palier: ${session.tierLabel} - Staff: $user'),
            Text('Debut: ${DateFormat('HH:mm').format(session.startTime)} - Fin: ${DateFormat('HH:mm').format(session.endTime)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${session.price.toStringAsFixed(2)} DH', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (session.status == 1)
              const Text('Terminée', style: TextStyle(color: Colors.green, fontSize: 10))
            else if (session.status == 2)
              const Text('Annulée', style: TextStyle(color: Colors.red, fontSize: 10))
            else
              const Text('En cours', style: TextStyle(color: Colors.blue, fontSize: 10)),
          ],
        ),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Options de la partie'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    PrinterHelper.printGameTicket(session, widget.objectbox);
                  },
                  child: const Text('Réimprimer Ticket'),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Ruci order) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: order.isDeleted ? Colors.red.shade50 : Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: order.isDeleted
            ? BoxDecoration(
                border: Border.all(color: Colors.red.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commande N° ${order.orderNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      if (order.isEdited || order.isDeleted)
                        Row(
                          children: [
                            if (order.isEdited)
                              _buildBadge('MODIFIÉE', Colors.orange),
                            if (order.isDeleted)
                              _buildBadge('SUPPRIMÉE', Colors.red),
                          ],
                        ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.edit, color: order.isDeleted ? Colors.grey : Theme.of(context).colorScheme.secondary),
                    onPressed: order.isDeleted ? null : () => _editOrder(order),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: order.isDeleted ? Colors.grey : Colors.red),
                    onPressed: order.isDeleted ? null : () => _deleteOrder(order),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Date : ${order.date.toLocal().toString().split('.')[0]}'),
              Text('Articles : ${order.items.length}'),
              Text(
                'Total : ${order.items.fold<double>(0, (sum, item) => sum + calculateItemTotal(item)).toStringAsFixed(2)} DH',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
              ),
              const SizedBox(height: 8),
              const Text('Articles :'),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('- ${item.productName ?? item.product.target?.name ?? 'Produit Supprimé'} : ${item.price ?? 'N/A'} x ${item.quantity}'),
                      if (item.extras.isNotEmpty)
                        ...item.extras.map((extra) {
                          final qty = item.getExtraQuantity(extra);
                          return Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text(
                              '  + ${extra.name} ${qty > 1 ? "x$qty" : ""}: ${(extra.price * qty).toStringAsFixed(2)} DH',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: order.isDeleted ? null : () => _printOrder(order),
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  void _editOrder(Ruci order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => custom_order_screen.OrderScreen(objectbox: widget.objectbox, orderToEdit: order),
      ),
    ).then((_) => setState(() {}));
  }

  void _printOrder(Ruci order) {
    final receiptData = ReceiptData.convertRuciToReceiptData(order);
    PrinterHelper.printReceipt(receiptData, widget.objectbox);
  }
}
