// Suggested code may be subject to a license. Learn more: ~LicenseLog:3632800846.
// Suggested code may be subject to a license. Learn more: ~LicenseLog:2817509952.
// Suggested code may be subject to a license. Learn more: ~LicenseLog:1286985924.
import 'dart:async';
import 'dart:math' as math;
import '../models/printer_config.dart';
// Import esc_pos_utils
// Import esc_pos_printer
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import 'package:Easify/objectbox.dart';
import '../widgets/product_card.dart'; // Import the ProductCard widget
import 'package:objectbox/objectbox.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart'; // Import ReorderableGridView
import '../models/order_counter.dart'; // Import OrderCounter
import '../service/printer_helper.dart'; // Import PrinterHelper
import '../widgets/order_details.dart'; // Import OrderDetails
import '../widgets/comment_dialog.dart'; // Import CommentDialog
import '../models/catigory.dart'; // Import Catigory
import '../widgets/catigory_card.dart'; // Import CatigoryCard
import '../widgets/payment_dialog.dart'; // Import PaymentDialog
import '../models/app_user.dart';

class OrderScreen extends StatefulWidget {
  final ObjectBox objectbox;
  final Ruci? orderToEdit;
  final String? initialCategory;
  final AppUser? assignedUser;
  const OrderScreen(
      {super.key,
      required this.objectbox,
      this.orderToEdit,
      this.initialCategory,
      this.assignedUser});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen>
    with SingleTickerProviderStateMixin {
  final List<OrderItem> _cart = [];
  late final Box<Product> _productBox;
  late final Box<PrinterConfig> _printerConfigBox;
  late final Box<OrderCounter> _orderCounterBox;
  late final Box<OrderItem> _orderItemBox; // To manage item deletion
  late final Box<Catigory> _catigoryBox;
  List<Catigory> _categories = [];
  bool _isTakeAway = false;
  String _comment = "";
  late AnimationController _shakeController;
  int? _shakingCartIndex;

  String? _categoryFilter; // null means show all NON-'Extra' products
  String? _previousCategoryFilter; // to restore after adding extras
  OrderItem? _activeParentForExtras; // item getting the extras
  bool _singleTicketMode = false;
  bool _enableChangeWindow = true;

  @override
  void initState() {
    super.initState();
    _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();
    _productBox = widget.objectbox.store.box<Product>();
    _orderCounterBox = widget.objectbox.store.box<OrderCounter>();
    _orderItemBox = widget.objectbox.store.box<OrderItem>();
    _catigoryBox = widget.objectbox.store.box<Catigory>();
    _categoryFilter = widget.initialCategory;
    _categories = _catigoryBox.getAll();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _shakingCartIndex = null);
          _shakeController.reset();
        }
      });

    // Load toggle settings from PrinterConfig
    _loadToggleSettings();

    if (widget.orderToEdit != null) {
      _loadOrderForEditing();
    }
  }

  void _loadToggleSettings() {
    try {
      final existingConfig = _printerConfigBox.getAll();
      if (existingConfig.isNotEmpty) {
        final config = existingConfig.first;
        _singleTicketMode = config.singleTicketMode;
        _enableChangeWindow = config.enableChangeWindow;
      }
    } catch (e) {
      // Use defaults if there's an error
      _singleTicketMode = false;
      _enableChangeWindow = true;
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _loadOrderForEditing() {
    for (final item in widget.orderToEdit!.items) {
      // Create a *copy* of the item for the cart so we don't modify the DB entity directly yet
      // OR reuse the entity? Reusing might be tricky if we don't save.
      // Better to create new transient objects or copies.
      // Simple approach: Create new OrderItem with same properties.
      final cartItem = OrderItem(quantity: item.quantity);
      cartItem.product.target = item.product.target;
      for (final extra in item.extras) {
        cartItem.extras.add(extra);
      }
      _cart.add(cartItem);
    }
  }

  void _addToCart(Product product) {
    setState(() {
      if (_activeParentForExtras != null) {
        final currentQty = _activeParentForExtras!.getExtraQuantity(product);
        if (_activeParentForExtras!.extras.any((e) => e.id == product.id)) {
          _activeParentForExtras!.setExtraQuantity(product, currentQty + 1);
        } else {
          _activeParentForExtras!.setExtraQuantity(product, 1);
        }
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
    return item.product.target?.name ?? 'Produit Inconnu';
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
    // Use persisted price if available, otherwise fallback to current product price
    double basePrice = (item.price ?? item.product.target?.price ?? 0).toDouble();
    double total = item.quantity * basePrice;
    for (final extra in item.extras) {
      total += extra.price * item.getExtraQuantity(extra);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: (widget.orderToEdit != null)
            ? AppBar(
                title: Text(widget.orderToEdit != null
                    ? 'Modifier Commande N°${widget.orderToEdit!.orderNumber}'
                    : 'Commande'))
            : null,
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
                  const Text('Résumé de la Commande',
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
    if (_activeParentForExtras == null && _categoryFilter == null) {
      return _buildCategoryGrid();
    }

    return Column(
      children: [
        if (_activeParentForExtras == null && _categoryFilter != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _categoryFilter = null;
                    });
                  },
                ),
                Text('Catégorie : $_categoryFilter',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        if (_activeParentForExtras != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text(
                    'Modifier les suppléments pour : ${_activeParentForExtras?.product.target?.name ?? "Article"}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue)),
                const Spacer(),
                TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _categoryFilter = _previousCategoryFilter;
                        _activeParentForExtras = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Terminer Suppléments'))
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = (constraints.maxWidth / 140).floor();
              if (crossAxisCount < 1) crossAxisCount = 1;
              return StreamBuilder<List<Product>>(
                stream: _productBox
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

                  final allProducts = snapshot.data!;
                  final products = allProducts.where((p) {
                    if (_activeParentForExtras != null) {
                      return p.category == 'Extra';
                    }
                    if (_categoryFilter != null) {
                      return p.category == _categoryFilter;
                    }
                    return p.category != 'Extra'; // Default: hide extras
                  }).toList();

                  // Sort products by displayOrder
                  products
                      .sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

                  if (products.isEmpty) {
                    return const Center(
                        child: Text('Aucun produit dans cette catégorie'));
                  }
                  return ReorderableGridView.builder(
                    itemCount: products.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final p = products.removeAt(oldIndex);
                        products.insert(newIndex, p);
                        for (int i = 0; i < products.length; i++) {
                          products[i].displayOrder = i;
                        }
                        _productBox.putMany(products);
                      });
                    },
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        key: ValueKey(product.id),
                        title: product.name,
                        price: product.price,
                        imageUrl: product.imageUrl ?? '',
                        onAdd: () => _addToCart(product),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    if (_categories.isEmpty) {
      return const Center(
          child: Text('Aucune catégorie trouvée. Ajoutez-en dans Produits.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 200).floor();
        if (crossAxisCount < 2) crossAxisCount = 2;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return CatigoryCard(
              title: cat.name,
              imageUrl: cat.imageUrl ?? '',
              onTap: () {
                setState(() {
                  _categoryFilter = cat.name;
                });
              },
            );
          },
        );
      },
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
              ? const Center(child: Text('Votre panier est vide'))
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
                      child: AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          double offset = 0;
                          if (_shakingCartIndex == index) {
                            // Sine wave oscillation: amplitude 8, 3 shakes (3 * 2pi)
                            offset =
                                math.sin(_shakeController.value * math.pi * 6) *
                                    8;
                          }
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildQuantityButton(
                                          icon: Icons.remove,
                                          onPressed: () => _removeItem(index),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6.0),
                                          child: Text(
                                            item.quantity.toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        _buildQuantityButton(
                                          icon: Icons.add,
                                          onPressed: () {
                                            setState(() {
                                              item.quantity++;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    title: Text(getProductName(item),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        '\$${calculateItemTotal(item).toStringAsFixed(2)}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.add_circle_outline,
                                          color: Colors.blue),
                                      onPressed: () {
                                        setState(() {
                                          _previousCategoryFilter =
                                              _categoryFilter;
                                          _categoryFilter = 'Extra';
                                          _activeParentForExtras = item;
                                        });
                                      },
                                    ),
                                  ),
                                  if (item.extras.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 56.0, bottom: 8.0, right: 16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: item.extras.map((extra) {
                                          final qty =
                                              item.getExtraQuantity(extra);
                                          return Row(
                                            children: [
                                              const Icon(
                                                  Icons
                                                      .subdirectory_arrow_right,
                                                  size: 16,
                                                  color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(
                                                  '${extra.name} ${qty > 1 ? "x$qty" : ""}'
                                                      .trim(),
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey)),
                                              const Spacer(),
                                              Text(
                                                  '${(extra.price * qty).toStringAsFixed(2)} DH',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey)),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    item.setExtraQuantity(
                                                        extra, qty - 1);
                                                  });
                                                },
                                                child: const Icon(
                                                    Icons.remove_circle_outline,
                                                    size: 14,
                                                    color: Colors.red),
                                              )
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
        ),
        if (_cart.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleCartAction('save-print'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: Text(
                      widget.orderToEdit != null
                          ? 'Mettre à jour Commande'
                          : 'Créer Commande',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (!_singleTicketMode) const SizedBox(width: 12),
                if (!_singleTicketMode)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleCartAction('single-print'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0, // Less prominent than primary action
                      ),
                      child: const Text(
                        'Ticket Simple',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleCartAction(String actionType) async {
    // Calculate total
    final total =
        _cart.fold<double>(0, (sum, item) => sum + calculateItemTotal(item));

    // If Change Window is enabled, show payment dialog
    if (_enableChangeWindow) {
      final paymentConfirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => PaymentDialog(totalAmount: total),
          ) ??
          false;

      // If user cancelled, cancel the entire order
      if (!paymentConfirmed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commande annulée')),
          );
        }
        return;
      }
    }

    // Proceed with the action (save or print)
    if (actionType == 'save-print') {
      await _saveOrder();
    } else if (actionType == 'single-print') {
      await _printSingleTicket();
    }
  }

  Future<void> _saveOrder() async {
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
        // Set persisted price and name from product target
        item.price = item.product.target?.price;
        item.productName = item.product.target?.name;
        // These are new OrderItem instances (id=0) or reused ones.
        // Since we created new objects in _loadOrderForEditing or _addToCart with id=0 (implied),
        // they will be inserted as new records.
        order.items.add(item);
      }

      // 3. Mark as edited and update Order
      order.isEdited = true;
      // Date can remain original or update. Let's keep original date for history accuracy.
      orderBox.put(order);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande mise à jour avec succès !')),
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
      if (widget.assignedUser != null) {
        order.user.target = widget.assignedUser;
      }
      for (final item in _cart) {
        item.price = item.product.target?.price;
        item.productName = item.product.target?.name;
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
      'total': order.items
          .fold<double>(0, (sum, item) => sum + calculateItemTotal(item)),
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
                          'quantity': item.getExtraQuantity(extra),
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
        comment: _comment.isNotEmpty ? _comment : "", isTakeAway: _isTakeAway);

    // Reset comment and takeaway after saving? Usually good practice if it's a new order.
    setState(() {
      _comment = "";
      _isTakeAway = false;
    });
  }

  Future<void> _printSingleTicket() async {
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
        // Set persisted price and name from product target
        item.price = item.product.target?.price;
        item.productName = item.product.target?.name;
        // These are new OrderItem instances (id=0) or reused ones.
        // Since we created new objects in _loadOrderForEditing or _addToCart with id=0 (implied),
        // they will be inserted as new records.
        order.items.add(item);
      }

      // 3. Update Order
      // Date can remain original or update. Let's keep original date for history accuracy.
      orderBox.put(order);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande mise à jour avec succès !')),
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
        item.price = item.product.target?.price;
        item.productName = item.product.target?.name;
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
      'total': order.items
          .fold<double>(0, (sum, item) => sum + calculateItemTotal(item)),
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
                          'quantity': item.getExtraQuantity(extra),
                          'price': extra.price,
                        })
                    .toList(),
              })
          .toList(),
      'paymentMethod': 'cash',
    };
    final Rdata = ReceiptData.fromJson(orderPayload);

    // PrinterHelper.printReceipt(Rdata, widget.objectbox);
    await Future.delayed(const Duration(milliseconds: 1000));
    PrinterHelper.printReceipt(Rdata, widget.objectbox,
        comment: _comment.isNotEmpty ? _comment : "", isTakeAway: _isTakeAway);

    // Reset comment and takeaway after saving? Usually good practice if it's a new order.
    setState(() {
      _comment = "";
      _isTakeAway = false;
    });
  }

  Widget _buildQuantityButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 12,
          color: Colors.black87,
        ),
      ),
    );
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

