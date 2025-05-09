// Suggested code may be subject to a license. Learn more: ~LicenseLog:912966895.
// Suggested code may be subject to a license. Learn more: ~LicenseLog:453303779.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import '../models/order_item.dart';
import '../objectbox.dart';
import 'package:objectbox/objectbox.dart';
import '../models/order.dart';
import '../models/printer_config.dart';


class HistoryScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const HistoryScreen({super.key, required this.objectbox});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Box<Ruci> _orderBox;
  late final Box<PrinterConfig> _printerConfigBox;

  @override
  void initState() {
    super.initState();
    _orderBox = widget.objectbox.store.box<Ruci>();
    _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();
  }

  Future<void> _printOrder(Ruci order) async {
    // Retrieve printer configuration from the database
    final printerConfig = _printerConfigBox.get(1);

    if (printerConfig == null) {
      print('Printer configuration not found');
      return;
    }

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final res = await printer.connect(printerConfig.ipAddress, port: printerConfig.port); // Changed line

    if (res != PosPrintResult.success) {
      print('Could not connect to printer: $res');
      return;
    }

    // Header - Business Name
    printer.row([
      PosColumn(
        text: '------ Drywich ------',
        width: 12,
        styles: PosStyles(align: PosAlign.center, bold: true),
      )
    ]);

    // Order ID
    printer.row([
      PosColumn(
        text: 'Order ID: ${order.id}',
        width: 12,
        styles: PosStyles(align: PosAlign.center),
      )
    ]);

    printer.feed(1);

    // Items List
    for (final item in order.items) {
      final name = item.product.target?.name ?? 'Unknown';
      final quantity = item.quantity;
      final price = calculateItemTotal(item).toStringAsFixed(2);

      printer.row([
        PosColumn(
          text: '$quantity x $name',
          width: 8,
          styles: PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: '\$$price',
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // Divider
    printer.row([
      PosColumn(
        text: '----------------------------------------',
        width: 12,
        styles: PosStyles(align: PosAlign.center),
      )
    ]);

    // Total Calculation
    final total = order.items
        .fold<double>(0, (sum, item) => sum + calculateItemTotal(item));

    printer.row([
      PosColumn(
        text: 'TOTAL',
        width: 8,
        styles: PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        text: '\$${total.toStringAsFixed(2)}',
        width: 4,
        styles: PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    // Divider
    printer.row([
      PosColumn(
        text: '----------------------------------------',
        width: 12,
        styles: PosStyles(align: PosAlign.center),
      )
    ]);

    printer.feed(3);
    printer.cut();
    printer.disconnect();

    print('Receipt sent successfully.');
  }

  double calculateItemTotal(OrderItem item) {
    return item.quantity * (item.product.target?.price ?? 0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: StreamBuilder<List<Ruci>>(
        stream: _orderBox
            .query()
            .watch(triggerImmediately: true)
            .map((query) => query.find()),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ID: ${order.id}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                    'Order Date: ${order.date.toLocal().toString().split('.')[0]}'),
                      const SizedBox(height: 4),
                      Text('Total Items: ${order.items.length}'),
                      const SizedBox(height: 4),
                      Text('Items:'),
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Text(
                              '- ${item.product.target != null ? item.product.target!.name : 'Deleted Product'}: ${item.product.target != null ? item.product.target!.price : 'N/A'} x ${item.quantity}'),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(                                                        
                            onPressed: () {
                              _printOrder(order);

                            },
                            icon: const Icon(Icons.print),
                            label: const Text('Print'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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

