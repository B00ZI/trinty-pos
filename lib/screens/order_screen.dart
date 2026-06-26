import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:objectbox/objectbox.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:Easify/objectbox.dart';
import '../models/order.dart' as order_model;
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/order_counter.dart';
import '../models/app_user.dart';
import '../models/printer_config.dart';
import '../models/category.dart';
import '../models/store_config.dart';
import '../service/printer_helper.dart';
import '../service/auth_service.dart';
import '../widgets/product_card.dart';
import '../widgets/category_card.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/user_selection_dialog.dart';
import '../providers/order_provider.dart';
import '../providers/settings_provider.dart';

class OrderScreen extends ConsumerStatefulWidget {
  final ObjectBox objectbox;
  final order_model.Order? orderToEdit;
  final String? initialCategory;
  final AppUser? assignedUser;

  const OrderScreen({
    super.key,
    required this.objectbox,
    this.orderToEdit,
    this.initialCategory,
    this.assignedUser,
  });

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen>
    with SingleTickerProviderStateMixin {
  late final Box<Product> _productBox;
  late final Box<PrinterConfig> _printerConfigBox;
  late final Box<OrderCounter> _orderCounterBox;
  late final Box<OrderItem> _orderItemBox;
  late final Box<Category> _categoryBox;

  bool _singleTicketMode = false;
  bool _enableChangeWindow = true;
  StreamSubscription<Query<PrinterConfig>>? _configSubscription;
  AppUser? _currentAuthUser;

  late AnimationController _shakeController;
  int? _shakingCartIndex;

  @override
  void initState() {
    super.initState();
    _productBox = widget.objectbox.store.box<Product>();
    _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();
    _orderCounterBox = widget.objectbox.store.box<OrderCounter>();
    _orderItemBox = widget.objectbox.store.box<OrderItem>();
    _categoryBox = widget.objectbox.store.box<Category>();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _shakingCartIndex = null);
          _shakeController.reset();
        }
      });

    _loadToggleSettings();
    _subscribeToToggleSettings();

    // Defer provider modifications to after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialCategory != null) {
        ref
            .read(cartProvider.notifier)
            .setCategoryFilter(widget.initialCategory);
      }

      if (widget.orderToEdit != null) {
        ref
            .read(cartProvider.notifier)
            .loadOrderForEditing(widget.orderToEdit!);
      }
    });
  }

  void _loadToggleSettings() {
    try {
      final configs = _printerConfigBox.getAll();
      if (configs.isNotEmpty) {
        _singleTicketMode = configs.first.singleTicketMode;
        _enableChangeWindow = configs.first.enableChangeWindow;
      }
    } catch (e) {
      _singleTicketMode = false;
      _enableChangeWindow = true;
    }
  }

  void _subscribeToToggleSettings() {
    _configSubscription =
        _printerConfigBox.query().watch(triggerImmediately: true).listen((_) {
      if (mounted) setState(() => _loadToggleSettings());
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _configSubscription?.cancel();
    super.dispose();
  }

  // ─── Cart operations (delegated to CartNotifier) ─────────────────────────

  void _addToCart(Product product) {
    ref.read(cartProvider.notifier).addToCart(product);
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    return Scaffold(
      appBar: widget.orderToEdit != null
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Modifier Commande N°${widget.orderToEdit!.orderNumber}',
              ),
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: const Text('Nouvelle Commande'),
            ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left: Product / Category Grid ──
            Expanded(
              flex: 3,
              child: _buildProductArea(cartState),
            ),
            const SizedBox(width: 8),
            // ── Right: Cart Sidebar ──
            Expanded(
              flex: 1,
              child: _buildCartSidebar(cartState),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Product Area (categories or products) ─────────────────────────────────

  Widget _buildProductArea(CartState cartState) {
    // If in extras mode, show extra products
    if (cartState.activeParentForExtras != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text(
                  'Suppléments pour : ${cartState.activeParentForExtras?.product?.name ?? "Article"}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(cartProvider.notifier).exitExtrasMode(),
                  icon: const Icon(Icons.close),
                  label: const Text('Terminer Suppléments'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildProductGrid(categoryFilter: 'Extra')),
        ],
      );
    }

    // If a category is selected, show products in that category with back button
    if (cartState.categoryFilter != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      ref.read(cartProvider.notifier).setCategoryFilter(null),
                ),
                Text(
                  'Catégorie : ${cartState.categoryFilter}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildProductGrid(
              categoryFilter: cartState.categoryFilter,
            ),
          ),
        ],
      );
    }

    // Default: show category grid
    return _buildCategoryGrid();
  }

  Widget _buildProductGrid({String? categoryFilter}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 140).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;

        return StreamBuilder<List<Product>>(
          stream: _productBox
              .query()
              .watch(triggerImmediately: true)
              .map((q) => q.find()),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final products = snapshot.data!
                .where((p) => p.category == categoryFilter)
                .toList()
              ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

            if (products.isEmpty) {
              return const Center(
                child: Text('Aucun produit dans cette catégorie'),
              );
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
    );
  }

  Widget _buildCategoryGrid() {
    return StreamBuilder<List<Category>>(
      stream: _categoryBox
          .query()
          .watch(triggerImmediately: true)
          .map((q) => q.find()),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        if (categories.isEmpty) {
          return const Center(
            child: Text('Aucune catégorie trouvée. Ajoutez-en dans Produits.'),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = (constraints.maxWidth / 200).floor();
            if (crossAxisCount < 2) crossAxisCount = 2;

            return ReorderableGridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final cat = categories.removeAt(oldIndex);
                  categories.insert(newIndex, cat);
                  for (int i = 0; i < categories.length; i++) {
                    categories[i].displayOrder = i;
                  }
                  _categoryBox.putMany(categories);
                });
              },
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return CategoryCard(
                  key: ValueKey(cat.id),
                  title: cat.name,
                  imageUrl: cat.imageUrl ?? '',
                  onTap: () => ref
                      .read(cartProvider.notifier)
                      .setCategoryFilter(cat.name),
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Cart Sidebar ──────────────────────────────────────────────────────────

  Widget _buildCartSidebar(CartState cartState) {
    final config = ref.watch(storeConfigProvider);
    final lines = cartState.lines;
    final grandTotal = cartState.grandTotal(config);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Panier (${lines.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '${grandTotal.toStringAsFixed(2)} DH',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Cart items
          Expanded(
            child: lines.isEmpty
                ? const Center(child: Text('Votre panier est vide'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return _buildCartItemCard(line, index, config);
                    },
                  ),
          ),

          // Action buttons
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _handleCartAction('save-print'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.orderToEdit != null
                          ? 'Mettre à jour Commande'
                          : 'Créer Commande',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_singleTicketMode) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _handleCartAction('single-print'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ticket Simple',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(CartLine line, int index, StoreConfig? config) {
    return Dismissible(
      key: Key('cart_${line.product?.id}_$index'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => ref.read(cartProvider.notifier).removeLineAt(index),
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
            offset = math.sin(_shakeController.value * math.pi * 6) * 8;
          }
          return Transform.translate(
            offset: Offset(offset, 0),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQtyButton(
                          icon: Icons.remove,
                          onPressed: () =>
                              ref.read(cartProvider.notifier).removeItem(index),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            line.quantity.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildQtyButton(
                          icon: Icons.add,
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .incrementItem(index),
                        ),
                      ],
                    ),
                    title: Text(
                      line.product?.name ?? 'Produit Inconnu',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '\$${line.total(config).toStringAsFixed(2)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.blue, size: 20),
                      onPressed: () =>
                          ref.read(cartProvider.notifier).enterExtrasMode(line),
                    ),
                  ),
                  if (line.orderItem.extras.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 56, bottom: 8, right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: line.orderItem.extras.map((extra) {
                          final qty = line.orderItem.getExtraQuantity(extra);
                          return Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${extra.name} ${qty > 1 ? "x$qty" : ""}'
                                    .trim(),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                              const Spacer(),
                              Text(
                                '${(extra.price * qty).toStringAsFixed(2)} DH',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => ref
                                    .read(cartProvider.notifier)
                                    .decrementExtra(extra),
                                child: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 14,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQtyButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 12, color: Colors.black87),
      ),
    );
  }

  // ─── Cart Actions (save / print) ──────────────────────────────────────────

  Future<void> _handleCartAction(String actionType) async {
    final cartState = ref.read(cartProvider);
    final config = ref.read(storeConfigProvider);

    // Auth Flow
    final authMode = await AuthService.getAuthMode();
    if (authMode == AuthMode.perOrder) {
      final selected = await showDialog<AppUser>(
        context: context,
        builder: (context) => UserSelectionDialog(objectbox: widget.objectbox),
      );
      if (selected == null) return;
      _currentAuthUser = selected;
    }

    final total = cartState.grandTotal(config);

    if (_enableChangeWindow) {
      final paymentConfirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => PaymentDialog(totalAmount: total),
          ) ??
          false;

      if (!paymentConfirmed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commande annulée')),
          );
        }
        return;
      }
    }

    // Persist prices before saving
    ref.read(cartProvider.notifier).persistPrices(config);

    if (actionType == 'save-print') {
      await _saveOrder();
    } else if (actionType == 'single-print') {
      await _printSingleTicket();
    }
  }

  Future<void> _saveOrder() async {
    try {
      final cartState = ref.read(cartProvider);
      final orderBox = widget.objectbox.store.box<order_model.Order>();
      order_model.Order order;

      if (widget.orderToEdit != null) {
        order = widget.orderToEdit!;
        final itemsToRemove = order.items.toList();
        order.items.clear();
        orderBox.put(order);
        _orderItemBox.removeMany(itemsToRemove.map((i) => i.id).toList());

        for (final line in cartState.lines) {
          order.items.add(line.orderItem);
        }
        order.isEdited = true;
        orderBox.put(order);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commande mise à jour avec succès !')),
          );
          Navigator.of(context).pop();
        }
      } else {
        final counter = _orderCounterBox.getAll().first;
        order = order_model.Order(
          date: DateTime.now(),
          orderNumber: counter.value,
        );
        if (widget.assignedUser != null) {
          order.user.target = widget.assignedUser;
        } else if (_currentAuthUser != null) {
          order.user.target = _currentAuthUser;
        }
        for (final line in cartState.lines) {
          order.items.add(line.orderItem);
        }
        orderBox.put(order);
        counter.value += 1;
        _orderCounterBox.put(counter);
        ref.read(cartProvider.notifier).clearCart();
      }

      _printReceipt(order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde : $e')),
        );
      }
    }
  }

  Future<void> _printSingleTicket() async {
    final cartState = ref.read(cartProvider);
    final orderBox = widget.objectbox.store.box<order_model.Order>();
    order_model.Order order;

    if (widget.orderToEdit != null) {
      order = widget.orderToEdit!;
      final itemsToRemove = order.items.toList();
      order.items.clear();
      orderBox.put(order);
      _orderItemBox.removeMany(itemsToRemove.map((i) => i.id).toList());

      for (final line in cartState.lines) {
        order.items.add(line.orderItem);
      }
      orderBox.put(order);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande mise à jour avec succès !')),
      );
      if (mounted) Navigator.of(context).pop();
    } else {
      final counter = _orderCounterBox.getAll().first;
      order = order_model.Order(
        date: DateTime.now(),
        orderNumber: counter.value,
      );
      for (final line in cartState.lines) {
        order.items.add(line.orderItem);
      }
      orderBox.put(order);
      counter.value += 1;
      _orderCounterBox.put(counter);
      ref.read(cartProvider.notifier).clearCart();
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    _printReceipt(order, singleTicket: true);
  }

  void _printReceipt(order_model.Order order, {bool singleTicket = false}) {
    final cartState = ref.read(cartProvider);

    final orderPayload = {
      'id': order.id,
      'dailyNumber': order.orderNumber,
      'createdat': order.date.toIso8601String(),
      'total': order.items.fold<double>(
        0,
        (sum, item) {
          double basePrice =
              (item.price ?? item.product.target?.price ?? 0).toDouble();
          double t = item.quantity * basePrice;
          for (final extra in item.extras) {
            t += extra.price * item.getExtraQuantity(extra);
          }
          return sum + t;
        },
      ),
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

    final receiptData = ReceiptData.fromJson(orderPayload);

    if (!singleTicket) {
      PrinterHelper.printReceipt(receiptData, widget.objectbox);
    }
    Future.delayed(const Duration(milliseconds: 1000), () {
      PrinterHelper.printReceipt(
        receiptData,
        widget.objectbox,
        comment: cartState.comment.isNotEmpty ? cartState.comment : '',
        isTakeAway: cartState.isTakeAway,
      );
    });
  }
}
