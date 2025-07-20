// Suggested code may be subject to a license. Learn more: ~LicenseLog:3632800846.
// Suggested code may be subject to a license. Learn more: ~LicenseLog:2817509952.
// Suggested code may be subject to a license. Learn more: ~LicenseLog:1286985924.
import 'dart:async';
import '../models/printer_config.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import esc_pos_utils
import 'package:esc_pos_printer/esc_pos_printer.dart'; // Import esc_pos_printer
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import 'package:Drywich/objectbox.dart';
import '../widgets/product_item.dart'; // Import the ProductItem widget
import 'package:objectbox/objectbox.dart';
import '../models/order_counter.dart'; // Import OrderCounter

class OrderScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const OrderScreen({super.key, required this.objectbox});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final List<OrderItem> _cart = [];
  late final Box<Product> _productBox;
  late final Box<PrinterConfig> _printerConfigBox;
  late final Box<OrderCounter> _orderCounterBox;

  @override
  void initState() {
    super.initState();
    _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();
    _productBox = widget.objectbox.store.box<Product>();
    _orderCounterBox = widget.objectbox.store.box<OrderCounter>();
  }

  void _addToCart(Product product) {
    setState(() {
      final existingItem = _cart.firstWhere(
          (item) => item.product.target?.id == product.id, orElse: () {
        final newItem = OrderItem(quantity: 0);
        newItem.product.target = product;
        return newItem;
      });

      if (existingItem.quantity > 0) {
        existingItem.quantity++;
      } else {
        existingItem.quantity = 1;
        _cart.add(existingItem);
      }
    });
  }

  String getProductName(OrderItem item) {
    return item.product.target?.name ?? 'Unknown Product';
  }

  void _removeItem(int index) {
    setState(() {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  double calculateItemTotal(OrderItem item) {
    return item.quantity * (item.product.target?.price ?? 0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Order'),
        ),
        body: OrientationBuilder(builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3, // Product grid takes 3 parts of the space
                    child: _buildProductGrid(),
                  ),
                  const SizedBox(width: 8.0), // Space between grid and summary
                  Expanded(
                    flex: 1, // Order summary takes 1 part of the space
                    child: _buildOrderSummary(),
                  ),
                ],
              ),
            );
          } else {
            // Portrait mode
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildProductGrid(),
                  ),
                  const SizedBox(height: 8.0), // Space between grid and summary
                  const Text('Order Summary',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: _buildOrderSummary(),
                  ),
                ],
              ),
            );
          }
        }));
  }

  Widget _buildProductGrid() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: StreamBuilder<List<Product>>(
        stream: _productBox
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

          final products = snapshot.data!;
          return GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 1.8,
              ),
                      itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return ProductItem(
                              product: product,
                              onAddToCart: _addToCart,
                            );
                          });
        },
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _cart.isEmpty
              ? const Center(child: Text('Your cart is empty'))
              : ListView.builder(
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    return ListTile(
                      leading: Text(item.quantity.toString(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      title: Text(getProductName(item)),
                      trailing: SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('\$${calculateItemTotal(item).toStringAsFixed(2)}'),
                            IconButton(
                                onPressed: () => _removeItem(index),
                                icon: const Icon(Icons.close)),
                          ],
                        ),
                      ),
                    );
                  }),
        ),
        if (_cart.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      _createOrder();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('Create Order'),
                  ),
                ),
              ),
          ],
       
      
    );
  }

  void _createOrder() async {
    // 1. Access the OrderCounter box
    final orderCounter = _orderCounterBox.getAll().first;

    // 1. Create an order object
    final order = Ruci(
      date: DateTime.now(),
      orderNumber: orderCounter.value, // 3. Assign counter value to orderNumber
    );
    // 2. Add the order items to the order
    for (final item in _cart) {
      order.items.add(item);
    }
    // 4. Store the order in the database
    // Assuming you have a Box<Order> called _orderBox
    final orderBox = widget.objectbox.store.box<Ruci>();
    orderBox.put(order);
    // 5. Increment the counter value
    orderCounter.value += 1;
    _orderCounterBox.put(orderCounter);
    // 4. Send the order as a receipt to the printer via TCP/IP
    await _printReceipt(order);

    await Future.delayed(Duration(seconds:1));
    await _printReceipt(order);
    // 5. Clear the cart
    setState(() {
      _cart.clear();
    });
    // 6. Navigate to a confirmation screen (optional)
    // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ConfirmationScreen()));
  }

  Future<void> _printReceipt(Ruci order) async {
    // Retrieve printer configuration from the database
    final printerConfig = _printerConfigBox.get(1);

    if (printerConfig == null) {
      print('Printer configuration not found');
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Printer configuration not found')),
);
      return;
    }

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final res = await printer.connect(printerConfig.ipAddress,
        port: printerConfig.port);

    if (res != PosPrintResult.success) {
      print('Could not connect to printer: $res');
      ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Could not connect to printer: $res')),
);
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
        text: 'Order# ${order.orderNumber}',
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
          text: '${price}DH',
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
        text: '${total.toStringAsFixed(2)} DH',
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
     printer.row([
      PosColumn(
        text: 'thank you for your order!',
        width: 12,
        styles: PosStyles(align: PosAlign.center),
      )
    ]);

    printer.feed(3);
    printer.cut();
    printer.disconnect();

    print('Receipt sent successfully.');
  }
}
