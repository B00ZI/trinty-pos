// Suggested code may be subject to a license. Learn more: ~LicenseLog:912966895.
// Suggested code may be subject to a license. Learn more: ~LicenseLog:453303779.

import 'dart:io';
import 'dart:typed_data'; // Add this import for Uint8List
import 'package:flutter/material.dart';
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
    final printerConfig = _printerConfigBox.get(1); // Assuming you have only one config with ID 1

    if (printerConfig == null) {
      print('Printer configuration not found');
      // Consider showing an error message to the user
      return;
    }

    final printerIp = printerConfig.ipAddress;
    final printerPort = printerConfig.port;





      try {
        // Connect to printer
        final socket = await Socket.connect(printerIp, printerPort, timeout: const Duration(seconds: 5));
        
        // Generate print data
        final commands = _generatePrinterData(order); // Call _generatePrinterData here
    
        // Send to printer
        socket.add(commands);
        await socket.flush();
        await socket.close();
        
        print('Print job sent successfully'); // Consider using proper logging
      } catch (e) {
        print('Failed to print: $e'); // Consider showing error to user
      }
  }
  Uint8List _generatePrinterData(Ruci order) {
      final buffer = StringBuffer();
      buffer.writeln("Order ID: ${order.id}");
      buffer.writeln("Order Date: ${order.date.toLocal().toString().split('.')[0]}");
      buffer.writeln("Items:");
      for (final item in order.items) {
        buffer.writeln("- ${item.product.target!.name}: ${item.product.target!.price} x ${item.quantity}");
      }
      buffer.writeln("\n\n\n");
      // Convert string to bytes, adding special characters
      final List<int> bytes = [...buffer.toString().codeUnits];
    
      return Uint8List.fromList(bytes);
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
                              '- ${item.product.target!.name}: ${item.product.target!.price} x ${item.quantity}'),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {_printOrder(order);
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

