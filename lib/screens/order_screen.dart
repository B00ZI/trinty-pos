// Suggested code may be subject to a license. Learn more: ~LicenseLog:1286985924.
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import 'package:myApp/objectbox.dart';
import '../widgets/product_item.dart'; // Import the ProductItem widget
import 'package:objectbox/objectbox.dart';

class OrderScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const OrderScreen({super.key, required this.objectbox});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final List<OrderItem> _cart = [];
  late final Box<Product> _productBox;

  @override
  void initState() {
    super.initState();
    _productBox = widget.objectbox.store.box<Product>();
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
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
                    return ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) => ProductItem(
                        product: products[index],
                        onAddToCart: _addToCart,
                      ),
                    );
                  },
                ),
              ),
            ),
            const Text('Order Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                            // Use a SizedBox to hold multiple widgets in the trailing area
                            width: 100, // Adjust width as needed
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment
                                  .spaceBetween, // Distribute space
                              children: [
                                Text(
                                    '\$${calculateItemTotal(item).toStringAsFixed(2)}'), // The price
                                IconButton(
                                    onPressed: () => _removeItem(index),
                                    icon: const Icon(
                                        Icons.close)), // The delete button
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
                      // Handle order creation logic here
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
        ),
      ),
    );
  }

  void _createOrder() async {
    // 1. Create an order object
    final order = Ruci(date: DateTime.now());
    // 2. Add the order items to the order
    for (final item in _cart) {
      order.items.add(item);
    }
    // 3. Store the order in the database (if necessary)
    // Assuming you have a Box<Order> called _orderBox
    final orderBox = widget.objectbox.store.box<Ruci>();
    orderBox.put(order);
    // 4. Send the order as a receipt to the printer via TCP/IP
    await _printReceipt(order);
    // 5. Clear the cart
    setState(() {
      _cart.clear();
    });
    // 6. Navigate to a confirmation screen (optional)
    // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ConfirmationScreen()));
  }

  Future<void> _printReceipt(Ruci order) async {
    const String printerIp =
        '192.168.1.100'; // Replace with your printer's IP address
    const int printerPort = 9100; // Common port for raw TCP printing

    try {
      final socket = await Socket.connect(printerIp, printerPort,
          timeout: const Duration(seconds: 5));
      print('Connected to printer at $printerIp:$printerPort');

      final receipt = StringBuffer();
      receipt.writeln('------ Order Receipt ------');
      receipt.writeln('Order ID: ${order.id}'); // Assuming you have an order ID
      for (final item in order.items) {
        final productName = item.product.target?.name ?? 'Unknown Product';
        final itemTotal = calculateItemTotal(item);
        receipt.writeln(
            '${item.quantity} x $productName: \$${itemTotal.toStringAsFixed(2)}');
      }
      final orderTotal = order.items
          .fold<double>(0, (sum, item) => sum + calculateItemTotal(item));
      receipt.writeln('---------------------------');
      receipt.writeln('Total: \$${orderTotal.toStringAsFixed(2)}');
      receipt.writeln('---------------------------');

      // Add line feed and form feed for ejecting the paper
      receipt.writeln('\n\n\n');

      socket.write(receipt.toString());
      await socket.flush();
      await socket.close();

      print('Receipt sent successfully.');
    } on SocketException catch (e) {
      print('Error connecting to printer: $e');
    } catch (e) {
      print('An error occurred: $e');
    }
  }
}
