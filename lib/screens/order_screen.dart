// Suggested code may be subject to a license. Learn more: ~LicenseLog:3632800846.
// Suggested code may be subject to a license. Learn more: ~LicenseLog:2817509952.
// Suggested code may be subject to a license. Learn more: ~LicenseLog:1286985924.
import 'dart:async';
import '../models/printer_config.dart';
// Import esc_pos_utils
// Import esc_pos_printer
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import 'package:Easify/objectbox.dart';
import '../widgets/product_item.dart'; // Import the ProductItem widget
import 'package:objectbox/objectbox.dart';
import '../models/order_counter.dart'; // Import OrderCounter
import '../service/printer_helper.dart'; // Import PrinterHelper
import '../widgets/order_details.dart'; // Import OrderDetails
import '../widgets/comment_dialog.dart'; // Import CommentDialog

class OrderScreen extends StatefulWidget {
  final ObjectBox objectbox;
  final Ruci? orderToEdit;
  const OrderScreen({super.key, required this.objectbox, this.orderToEdit});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final List<OrderItem> _cart = [];
  late final Box<Product> _productBox;
  late final Box<PrinterConfig> _printerConfigBox;
  late final Box<OrderCounter> _orderCounterBox;
  late final Box<OrderItem> _orderItemBox; // To manage item deletion
  bool _isTakeAway = false;
  String _comment = "";
  
  String? _categoryFilter; // null means show all NON-'Extra' products
  OrderItem? _activeParentForExtras; // item getting the extras

  @override
  void initState() {
    super.initState();
    _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();
    _productBox = widget.objectbox.store.box<Product>();
    _orderCounterBox = widget.objectbox.store.box<OrderCounter>();
    _orderItemBox = widget.objectbox.store.box<OrderItem>();

    if (widget.orderToEdit != null) {
      _loadOrderForEditing();
    }
  }

  void _loadOrderForEditing() {
    for (final item in widget.orderToEdit!.items) {
      // Create a *copy* of the item for the cart so we don't modify the DB entity directly yet
      // OR reuse the entity? Reusing might be tricky if we don't save.
      // Better to create new transient objects or copies.
      // Simple approach: Create new OrderItem with same properties.
      final cartItem = OrderItem(quantity: item.quantity);
      cartItem.product.target = item.product.target;
      _cart.add(cartItem);
    }
  }

  void _addToCart(Product product) {
    setState(() {
      if (_activeParentForExtras != null) {
        // Adding an EXTRA to a specific item
        _activeParentForExtras!.extras.add(product);
        // Automatically clear filter after adding an extra? 
        // User might want to add more than one. Let's keep it for now.
        return;
      }

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
    double total = item.quantity * (item.product.target?.price ?? 0).toDouble();
    for (final extra in item.extras) {
      total += extra.price;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: widget.orderToEdit != null ? AppBar(title: Text('Edit Order #${widget.orderToEdit!.orderNumber}')) : null,
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
    return Column(
      children: [
        if (_categoryFilter != null)
           Padding(
             padding: const EdgeInsets.all(8.0),
             child: Row(
               children: [
                 Text('Editing Extras for: ${_activeParentForExtras?.product.target?.name ?? "Item"}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                 const Spacer(),
                 TextButton.icon(
                   onPressed: () {
                     setState(() {
                       _categoryFilter = null;
                       _activeParentForExtras = null;
                     });
                   }, 
                   icon: const Icon(Icons.close), 
                   label: const Text('Finish Extras')
                 )
               ],
             ),
           ),
        Expanded(
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
          
              final allProducts = snapshot.data!;
              final products = allProducts.where((p) {
                if (_categoryFilter != null) {
                  return p.category == _categoryFilter;
                } else {
                  return p.category != 'Extra'; // Default: hide extras
                }
              }).toList();

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
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderDetails(
          isTakeAway: _isTakeAway,
          onTakeAwayChanged: (value) {
            setState(() {
              _isTakeAway = value ?? false;
            });
          },
          onCommentPressed: () async {
            final result = await showDialog<String>(
              context: context,
              builder: (context) => CommentDialog(initialComment: _comment),
            );
            if (result != null) {
              setState(() {
                _comment = result;
              });
            }
          },
        ),
        Expanded(
          child: _cart.isEmpty
              ? const Center(child: Text('Your cart is empty'))
              : ListView.builder(
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    return Dismissible(
                      key: Key('cart_item_${item.product.target?.id}_$index'),
                      direction: DismissDirection.horizontal,
                      onDismissed: (direction) {
                        setState(() {
                          _cart.removeAt(index);
                        });
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(item.quantity.toString(),
                                    style: TextStyle(
                                        fontSize: 16, 
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer)),
                              ),
                              title: Text(getProductName(item), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('\$${calculateItemTotal(item).toStringAsFixed(2)}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                onPressed: () {
                                  setState(() {
                                    _categoryFilter = 'Extra';
                                    _activeParentForExtras = item;
                                  });
                                },
                              ),
                            ),
                            if (item.extras.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 56.0, bottom: 8.0, right: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: item.extras.map((extra) => Row(
                                    children: [
                                      const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(extra.name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      const Spacer(),
                                      Text('\$${extra.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            item.extras.remove(extra);
                                          });
                                        },
                                        child: const Icon(Icons.remove_circle_outline, size: 14, color: Colors.red),
                                      )
                                    ],
                                  )).toList(),
                                ),
                              )
                          ],
                        ),
                      ),
                    );
                  }),
        ),
        if (_cart.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                onPressed: () {
                  _saveOrder();
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18), 
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(
                  widget.orderToEdit != null ? 'Update Order' : 'Create Order',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _saveOrder();
                },
                style: ElevatedButton.styleFrom( 
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18), 
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(
                  widget.orderToEdit != null ? 'Update Order' : 'singel Ticket',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
            ],),
          ),
      ],
    );
  }

  void _saveOrder() async {
    final orderBox = widget.objectbox.store.box<Ruci>();
    Ruci order;

    if (widget.orderToEdit != null) {
      // EDIT MODE
      order = widget.orderToEdit!;
      
      // 1. Identify items to remove (orphans)
      // We can't just clear relation, we should remove the actual OrderItem entities
      // to avoid filling DB with unused items.
      final itemsToRemove = order.items.toList(); 
      order.items.clear();
      // Apply to DB to unlink
      orderBox.put(order); 
      
      // Now delete the old items from OrderItem box
      _orderItemBox.removeMany(itemsToRemove.map((i) => i.id).toList());

      // 2. Add new items from cart
      for (final item in _cart) {
        // These are new OrderItem instances (id=0) or reused ones. 
        // Since we created new objects in _loadOrderForEditing or _addToCart with id=0 (implied),
        // they will be inserted as new records.
        order.items.add(item);
      }
      
      // 3. Update Order
      // Date can remain original or update. Let's keep original date for history accuracy.
      orderBox.put(order);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated successfully!')),
      );
      
       // Pop back to history screen
      if (mounted) {
         Navigator.of(context).pop();
      }

    } else {
      // CREATE MODE
      final orderCounter = _orderCounterBox.getAll().first;
      order = Ruci(
        date: DateTime.now(),
        orderNumber: orderCounter.value,
      );
      for (final item in _cart) {
        order.items.add(item);
      }
      orderBox.put(order);
      
      orderCounter.value += 1;
      _orderCounterBox.put(orderCounter);

      setState(() {
        _cart.clear();
      });
    }

    // PRINT RECEIPT (For both Create and Edit)
    final orderPayload = {
      'id': order.id,
      'dailyNumber': order.orderNumber,
      'createdat': order.date.toIso8601String(),
      'total':
          order.items.fold<double>(0, (sum, item) => sum + calculateItemTotal(item)),
      'items': order.items
          .map((item) => {
                'id': item.product.target?.id,
                'title': item.product.target?.name,
                'quantity': item.quantity,
                'price': item.product.target?.price,
                'extras': item.extras
                    .map((extra) => {
                          'id': extra.id,
                          'title': extra.name,
                          'quantity': 1,
                          'price': extra.price,
                        })
                    .toList(),
              })
          .toList(),
      'paymentMethod': 'cash',
    };
    final Rdata = ReceiptData.fromJson(orderPayload);
     
    PrinterHelper.printReceipt(Rdata, widget.objectbox);
    await Future.delayed(const Duration(milliseconds: 1000));
    PrinterHelper.printReceipt(Rdata, widget.objectbox, 
      comment: _comment.isNotEmpty ? _comment : " Thank you for your order! Come Again!",
      isTakeAway: _isTakeAway);

    // Reset comment and takeaway after saving? Usually good practice if it's a new order.
    setState(() {
      _comment = "";
      _isTakeAway = false;
    });
  }
}

  

  // Future<void> _printReceipt(Ruci order) async {
  //   // Retrieve printer configuration from the database
  //   final printerConfig = _printerConfigBox.getAll().first;

  //   // ignore: unnecessary_null_comparison
  //   if (printerConfig == null) {
  //     print('Printer configuration not found');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Printer configuration not found')),
  //     );
  //     return;
  //   }

  //   final profile = await CapabilityProfile.load();
  //   final printer = NetworkPrinter(PaperSize.mm80, profile);

  //   final res = await printer.connect(printerConfig.ipAddress,
  //       port: printerConfig.port);

  //   if (res != PosPrintResult.success) {
  //     print('Could not connect to printer: $res');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Could not connect to printer: $res')),
  //     );
  //     return;
  //   }

  //   // Header - Business Name
  //   printer.row([
  //     PosColumn(
  //       text: '------ Easify ------',
  //       width: 12,
  //       styles: const PosStyles(align: PosAlign.center, bold: true),
  //     )
  //   ]);

  //   // Order ID
  //   printer.row([
  //     PosColumn(
  //       text: 'Order# ${order.orderNumber}',
  //       width: 12,
  //       styles: const PosStyles(align: PosAlign.center),
  //     )
  //   ]);

  //   printer.feed(1);

  //   // Items List
  //   for (final item in order.items) {
  //     final name = item.product.target?.name ?? 'Unknown';
  //     final quantity = item.quantity;
  //     final price = calculateItemTotal(item).toStringAsFixed(2);

  //     printer.row([
  //       PosColumn(
  //         text: '$quantity x $name',
  //         width: 8,
  //         styles: const PosStyles(align: PosAlign.left),
  //       ),
  //       PosColumn(
  //         text: '${price}DH',
  //         width: 4,
  //         styles: const PosStyles(align: PosAlign.right),
  //       ),
  //     ]);
  //   }

  //   // Divider
  //   printer.row([
  //     PosColumn(
  //       text: '----------------------------------------',
  //       width: 12,
  //       styles: const PosStyles(align: PosAlign.center),
  //     )
  //   ]);

  //   // Total Calculation
  //   final total = order.items
  //       .fold<double>(0, (sum, item) => sum + calculateItemTotal(item));

  //   printer.row([
  //     PosColumn(
  //       text: 'TOTAL',
  //       width: 8,
  //       styles: const PosStyles(align: PosAlign.left, bold: true),
  //     ),
  //     PosColumn(
  //       text: '${total.toStringAsFixed(2)} DH',
  //       width: 4,
  //       styles: const PosStyles(align: PosAlign.right, bold: true),
  //     ),
  //   ]);

  //   // Divider
  //   printer.row([
  //     PosColumn(
  //       text: '----------------------------------------',
  //       width: 12,
  //       styles: const PosStyles(align: PosAlign.center),
  //     )
  //   ]);
  //   printer.row([
  //     PosColumn(
  //       text: 'thank you for your order!',
  //       width: 12,
  //       styles: const PosStyles(align: PosAlign.center),
  //     )
  //   ]);

  //   printer.feed(3);
  //   printer.cut();
  //   printer.disconnect();

  //   print('Receipt sent successfully.');
  // }

