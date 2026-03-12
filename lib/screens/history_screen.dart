import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_item.dart';
import '../objectbox.dart';
import 'package:objectbox/objectbox.dart';
import '../models/order.dart';
import '../models/printer_config.dart';
import '../models/order_counter.dart'; // Import OrderCounter
import '../widgets/dialog.dart' as custom_dialog;
import '../service/printer_helper.dart';
import 'order_screen.dart' as custom_order_screen;

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

  @override
  void initState() {
    super.initState();
    _orderBox = widget.objectbox.store.box<Ruci>();
    _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();
    _orderCounterBox = widget.objectbox.store
        .box<OrderCounter>(); // Initialize OrderCounter box
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
    _orderBox.remove(order.id);
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

  double calculateItemTotal(OrderItem item) {
    double total = item.quantity * (item.product.target?.price ?? 0).toDouble();
    for (final extra in item.extras) {
      total += extra.price * item.getExtraQuantity(extra);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        
        actions: [
          // Add the button to the AppBar
          IconButton(
            onPressed: () => _resetOrderCounter(),
            icon: const Icon(Icons.refresh),
            color: Theme.of(context).colorScheme.secondary,
          ),
          IconButton(
            onPressed: () =>
                custom_dialog.showDailyDataDialog(context, widget.objectbox),
            icon: const Icon(Icons.archive),
            color: Theme.of(context).colorScheme.secondary,
          )
        ],
      ),
      body: StreamBuilder<List<Ruci>>(
        stream: _orderBox
            .query()
            .watch(triggerImmediately: true)
            .map((query) => query.find()),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!;
          final reversedOrders = orders.reversed.toList();

          return ListView.builder(
            itemCount: reversedOrders.length,
            itemBuilder: (context, index) {
              final order = reversedOrders[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Commande N° ${order.orderNumber}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.edit,
                                color: Theme.of(context).colorScheme.secondary),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => custom_order_screen.OrderScreen(
                                    objectbox: widget.objectbox,
                                    orderToEdit: order,
                                  ),
                                ),
                              ).then((_) {
                                // Refresh history when returning (though StreamBuilder should handle it)
                                setState(() {});
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () {
                              _deleteOrder(order);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Date de commande : ${order.date.toLocal().toString().split('.')[0]}'),
                      const SizedBox(height: 4),
                      Text('Total d\'articles : ${order.items.length}'),
                      const SizedBox(height: 4),
                      Text(
                        'Montant Total : ${order.items.fold<double>(0, (sum, item) => sum + calculateItemTotal(item)).toStringAsFixed(2)} DH',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Articles :'),
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '- ${item.product.target != null ? item.product.target!.name : 'Produit Supprimé'} : ${item.product.target != null ? item.product.target!.price : 'N/A'} x ${item.quantity}'),
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
                            onPressed: () {
                              final receiptData =
                                  ReceiptData.convertRuciToReceiptData(order);
                              PrinterHelper.printReceipt(
                                  receiptData, widget.objectbox);
                            },
                            icon: Icon(Icons.print,
                                color: Theme.of(context).colorScheme.onPrimary),
                            label: Text('Imprimer',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
