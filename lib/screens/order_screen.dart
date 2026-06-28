import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/order.dart' as order_model;
import '../models/product.dart';
import '../models/app_user.dart';
import '../models/store_config.dart';
import '../service/printer_helper.dart';
import '../service/auth_service.dart';
import '../widgets/product_card.dart';
import '../widgets/category_card.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/user_selection_dialog.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/settings_provider.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────

class _AppColors {
  static const surface = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF64748B);
  static const inkLight = Color(0xFFCBD5E1);
  static const accent = Color(0xFF6366F1); // indigo
  static const accentSoft = Color(0xFFEEF2FF);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const border = Color(0xFFE2E8F0);
  static const cartBg = Color(0xFF1E1B4B); // deep indigo sidebar
  static const cartSurface = Color(0xFF2D2A5E);
  static const cartText = Color(0xFFF1F5F9);
  static const cartMuted = Color(0xFF94A3B8);
}

class OrderScreen extends ConsumerStatefulWidget {
  final order_model.Order? orderToEdit;
  final String? initialCategory;
  final AppUser? assignedUser;

  const OrderScreen({
    super.key,
    this.orderToEdit,
    this.initialCategory,
    this.assignedUser,
  });

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen>
    with SingleTickerProviderStateMixin {
  AppUser? _currentAuthUser;

  late AnimationController _shakeController;
  int? _shakingCartIndex;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _shakingCartIndex = null);
          _shakeController.reset();
        }
      });

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

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addToCart(Product product) {
    ref.read(cartProvider.notifier).addToCart(product);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final isEditing = widget.orderToEdit != null;

    return Scaffold(
      backgroundColor: _AppColors.surface,
      appBar: _buildAppBar(isEditing, cartState),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

            if (isLandscape || isTablet) {
              return _buildLandscapeLayout(cartState);
            }
            return _buildPortraitLayout(cartState);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isEditing, CartState cartState) {
    final itemCount = cartState.lines.fold<int>(0, (s, l) => s + l.quantity);
    return AppBar(
      backgroundColor: _AppColors.card,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: _AppColors.border,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: _AppColors.ink,
        onPressed: () => context.pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing
                ? 'Modifier N°${widget.orderToEdit!.orderNumber}'
                : 'Nouvelle Commande',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          if (isEditing)
            Text(
              'Modifiez les articles puis confirmez',
              style: TextStyle(
                fontSize: 11,
                color: _AppColors.inkMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      actions: [
        if (itemCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _AppColors.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_bag_outlined,
                    size: 14, color: _AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  '$itemCount',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Layouts ──────────────────────────────────────────────────────────────

  Widget _buildLandscapeLayout(CartState cartState) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cart panel — fixed left in landscape
        SizedBox(
          width: 300,
          child: _buildCartPanel(cartState),
        ),
        // Product area — takes remaining space
        Expanded(
          child: _buildProductArea(cartState),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(CartState cartState) {
    final lines = cartState.lines;
    return Column(
      children: [
        // Product area — scrollable top
        Expanded(
          child: _buildProductArea(cartState),
        ),
        // Cart sheet — bottom panel
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          height: lines.isEmpty ? 72 : 300,
          child: _buildCartPanel(cartState),
        ),
      ],
    );
  }

  // ─── Product Area ─────────────────────────────────────────────────────────

  Widget _buildProductArea(CartState cartState) {
    if (cartState.activeParentForExtras != null) {
      return Column(
        children: [
          _buildBreadcrumbBar(
            icon: Icons.add_circle_outline_rounded,
            iconColor: _AppColors.accent,
            label:
                'Suppléments pour ${cartState.activeParentForExtras?.product?.name ?? "Article"}',
            action: TextButton.icon(
              onPressed: () =>
                  ref.read(cartProvider.notifier).exitExtrasMode(),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Terminer'),
              style: TextButton.styleFrom(
                foregroundColor: _AppColors.success,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(child: _buildProductGrid(categoryFilter: 'Extra')),
        ],
      );
    }

    if (cartState.categoryFilter != null) {
      return Column(
        children: [
          _buildBreadcrumbBar(
            icon: Icons.grid_view_rounded,
            iconColor: _AppColors.inkMuted,
            label: cartState.categoryFilter!,
            action: TextButton.icon(
              onPressed: () =>
                  ref.read(cartProvider.notifier).setCategoryFilter(null),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Catégories'),
              style: TextButton.styleFrom(
                foregroundColor: _AppColors.inkMuted,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
              child:
                  _buildProductGrid(categoryFilter: cartState.categoryFilter)),
        ],
      );
    }

    return _buildCategoryGrid();
  }

  Widget _buildBreadcrumbBar({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _AppColors.card,
        border: Border(bottom: BorderSide(color: _AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _AppColors.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          action,
        ],
      ),
    );
  }

  Widget _buildProductGrid({String? categoryFilter}) {
    final productsAsync = ref.watch(productsStreamProvider);

    return productsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _AppColors.accent),
      ),
      error: (err, _) => _buildErrorState('$err'),
      data: (allProducts) {
        final products = allProducts
            .where((p) => p.category == categoryFilter)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        if (products.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inventory_2_outlined,
            message: 'Aucun produit dans cette catégorie',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = (constraints.maxWidth / 140).floor();
            if (crossAxisCount < 1) crossAxisCount = 1;

            return ReorderableGridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.55,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              onReorder: (oldIndex, newIndex) {
                final p = products.removeAt(oldIndex);
                products.insert(newIndex, p);
                for (int i = 0; i < products.length; i++) {
                  products[i].displayOrder = i;
                }
                ref.read(productRepositoryProvider).putMany(products);
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
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return categoriesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _AppColors.accent),
      ),
      error: (err, _) => _buildErrorState('$err'),
      data: (allCategories) {
        final categories = allCategories.toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        if (categories.isEmpty) {
          return _buildEmptyState(
            icon: Icons.category_outlined,
            message:
                'Aucune catégorie trouvée.\nAjoutez-en dans les Produits.',
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
                final cat = categories.removeAt(oldIndex);
                categories.insert(newIndex, cat);
                for (int i = 0; i < categories.length; i++) {
                  categories[i].displayOrder = i;
                }
                ref.read(categoryRepositoryProvider).putMany(categories);
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

  // ─── Cart Panel ───────────────────────────────────────────────────────────

  Widget _buildCartPanel(CartState cartState) {
    final config = ref.watch(storeConfigProvider);
    final printerConfigs =
        ref.watch(printerConfigStreamProvider).valueOrNull ?? [];
    final singleTicketMode =
        printerConfigs.isNotEmpty ? printerConfigs.first.singleTicketMode : false;
    final lines = cartState.lines;
    final grandTotal = cartState.grandTotal(config);

    return Container(
      decoration: const BoxDecoration(
        color: _AppColors.cartBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar (portrait only hint)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _AppColors.cartMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Cart Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _AppColors.cartSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      size: 16, color: _AppColors.accent),
                ),
                const SizedBox(width: 10),
                Text(
                  lines.isEmpty
                      ? 'Panier vide'
                      : '${lines.length} article${lines.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: _AppColors.cartText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (lines.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${grandTotal.toStringAsFixed(2)} DH',
                        style: const TextStyle(
                          color: _AppColors.cartText,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Total',
                        style: TextStyle(
                          color: _AppColors.cartMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          if (lines.isNotEmpty) ...[
            Divider(
              height: 1,
              color: _AppColors.cartMuted.withOpacity(0.15),
            ),

            // Items list
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  return _buildCartItem(lines[index], index, config);
                },
              ),
            ),

            // Action buttons
            _buildCartActions(singleTicketMode),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 32,
                      color: _AppColors.cartMuted.withOpacity(0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ajoutez des articles',
                      style: TextStyle(
                        color: _AppColors.cartMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartLine line, int index, StoreConfig? config) {
    return Dismissible(
      key: Key('cart_${line.product?.id}_$index'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) =>
          ref.read(cartProvider.notifier).removeLineAt(index),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: _AppColors.danger.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.delete_outline_rounded,
            color: _AppColors.danger, size: 18),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: _AppColors.danger.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline_rounded,
            color: _AppColors.danger, size: 18),
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
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: _AppColors.cartSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        // Qty controls
                        _buildQtyControl(index, line),
                        const SizedBox(width: 10),
                        // Product info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.product?.name ?? 'Produit Inconnu',
                                style: const TextStyle(
                                  color: _AppColors.cartText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${line.total(config).toStringAsFixed(2)} DH',
                                style: TextStyle(
                                  color: _AppColors.accent.withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Extras button
                        GestureDetector(
                          onTap: () => ref
                              .read(cartProvider.notifier)
                              .enterExtrasMode(line),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: _AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Extras
                  if (line.orderItem.extras.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.only(
                          left: 52, right: 12, bottom: 10),
                      child: Column(
                        children: line.orderItem.extras.map((extra) {
                          final qty = line.orderItem.getExtraQuantity(extra);
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 3,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: _AppColors.cartMuted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  '${extra.name}${qty > 1 ? " ×$qty" : ""}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _AppColors.cartMuted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(extra.price * qty).toStringAsFixed(2)} DH',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _AppColors.cartMuted,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => ref
                                      .read(cartProvider.notifier)
                                      .decrementExtra(extra),
                                  child: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 14,
                                    color: _AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildQtyControl(int index, CartLine line) {
    return Container(
      decoration: BoxDecoration(
        color: _AppColors.cartBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQtyButton(
            icon: Icons.remove_rounded,
            onPressed: () =>
                ref.read(cartProvider.notifier).removeItem(index),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              line.quantity.toString(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _AppColors.cartText,
              ),
            ),
          ),
          _buildQtyButton(
            icon: Icons.add_rounded,
            onPressed: () =>
                ref.read(cartProvider.notifier).incrementItem(index),
          ),
        ],
      ),
    );
  }

  Widget _buildCartActions(bool singleTicketMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary CTA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _handleCartAction('save-print'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    widget.orderToEdit != null
                        ? 'Mettre à jour'
                        : 'Confirmer la Commande',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Secondary CTA
          if (!singleTicketMode) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: () => _handleCartAction('single-print'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _AppColors.cartMuted,
                  side: BorderSide(
                      color: _AppColors.cartMuted.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.print_outlined, size: 15),
                    SizedBox(width: 8),
                    Text(
                      'Ticket Simple',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildQtyButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _AppColors.cartSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 13, color: _AppColors.cartText),
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: _AppColors.inkLight),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: _AppColors.inkMuted,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 40, color: _AppColors.danger),
          const SizedBox(height: 10),
          Text(
            'Erreur : $message',
            style: const TextStyle(
              color: _AppColors.danger,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Cart Actions (logic untouched) ───────────────────────────────────────

  Future<void> _handleCartAction(String actionType) async {
    final cartState = ref.read(cartProvider);
    final config = ref.read(storeConfigProvider);

    final authMode = await AuthService.getAuthMode();
    if (authMode == AuthMode.perOrder) {
      final selected = await showDialog<AppUser>(
        context: context,
        builder: (context) =>
            UserSelectionDialog(objectbox: ref.read(objectBoxProvider)),
      );
      if (selected == null) return;
      _currentAuthUser = selected;
    }

    final total = cartState.grandTotal(config);

    final printerConfigs =
        ref.read(printerConfigStreamProvider).valueOrNull ?? [];
    final enableChangeWindow = printerConfigs.isNotEmpty
        ? printerConfigs.first.enableChangeWindow
        : true;

    if (enableChangeWindow) {
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
      final orderRepo = ref.read(orderRepositoryProvider);
      order_model.Order order;

      if (widget.orderToEdit != null) {
        order = widget.orderToEdit!;
        final itemsToRemove = order.items.toList();
        order.items.clear();
        orderRepo.putOrder(order);
        for (final id in itemsToRemove.map((i) => i.id)) {
          orderRepo.removeOrderItem(id);
        }

        for (final line in cartState.lines) {
          order.items.add(line.orderItem);
        }
        order.isEdited = true;
        orderRepo.putOrder(order);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Commande mise à jour avec succès !')),
          );
          Navigator.of(context).pop();
        }
      } else {
        final orderNumber = orderRepo.incrementOrderNumber();
        order = order_model.Order(
          date: DateTime.now(),
          orderNumber: orderNumber,
        );
        if (widget.assignedUser != null) {
          order.user.target = widget.assignedUser;
        } else if (_currentAuthUser != null) {
          order.user.target = _currentAuthUser;
        }
        for (final line in cartState.lines) {
          order.items.add(line.orderItem);
        }
        orderRepo.putOrder(order);
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
    final orderRepo = ref.read(orderRepositoryProvider);
    order_model.Order order;

    if (widget.orderToEdit != null) {
      order = widget.orderToEdit!;
      final itemsToRemove = order.items.toList();
      order.items.clear();
      orderRepo.putOrder(order);
      for (final id in itemsToRemove.map((i) => i.id)) {
        orderRepo.removeOrderItem(id);
      }

      for (final line in cartState.lines) {
        order.items.add(line.orderItem);
      }
      orderRepo.putOrder(order);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande mise à jour avec succès !')),
      );
      if (mounted) Navigator.of(context).pop();
    } else {
      final orderNumber = orderRepo.incrementOrderNumber();
      order = order_model.Order(
        date: DateTime.now(),
        orderNumber: orderNumber,
      );
      for (final line in cartState.lines) {
        order.items.add(line.orderItem);
      }
      orderRepo.putOrder(order);
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
    final ob = ref.read(objectBoxProvider);

    if (!singleTicket) {
      PrinterHelper.printReceipt(receiptData, ob);
    }
    Future.delayed(const Duration(milliseconds: 1000), () {
      PrinterHelper.printReceipt(
        receiptData,
        ob,
        comment: cartState.comment.isNotEmpty ? cartState.comment : '',
        isTakeAway: cartState.isTakeAway,
      );
    });
  }
}