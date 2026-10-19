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
import '../objectbox.g.dart';
import '../service/printer_helper.dart';
import '../service/auth_service.dart';
import '../service/pricing_service.dart';
import '../widgets/product_card.dart';
import '../widgets/category_card.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/user_selection_dialog.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/settings_provider.dart';
import '../router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

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
  // P35: while a confirm/print action runs, both action buttons are dead —
  // a double-tap used to create an empty order and parallel printer links.
  bool _isHandlingAction = false;

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

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final isEditing = widget.orderToEdit != null;
    final itemCount = cartState.lines.fold<int>(0, (s, l) => s + l.quantity);

    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Column(
          children: [
            // Slim header bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
              decoration: const BoxDecoration(
                color: AppColors.surface0,
                border: Border(bottom: BorderSide(color: AppColors.surface3, width: 1)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: AppColors.ink0,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? 'Modifier N°${widget.orderToEdit!.orderNumber}'
                              : 'Nouvelle Commande',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink0,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (isEditing)
                          const Text(
                            'Modifiez les articles puis confirmez',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.ink3,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.receipt_long_rounded, size: 20),
                    color: AppColors.ink3,
                    onPressed: () => context.push(AppRoutes.history),
                    tooltip: 'Historique',
                  ),
                  if (itemCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: AppRadius.rFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shopping_bag_outlined,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '$itemCount',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Main content
            Expanded(
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
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(CartState cartState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cartWidth = constraints.maxWidth < 500
            ? (constraints.maxWidth * 0.45).clamp(200.0, 340.0)
            : 340.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: cartWidth,
              child: _buildCartPanel(cartState),
            ),
            Expanded(
              child: _buildProductArea(cartState),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPortraitLayout(CartState cartState) {
    final lines = cartState.lines;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCartHeight = (constraints.maxHeight * 0.45).clamp(120.0, 320.0);
        final cartHeight = lines.isEmpty ? 72.0 : maxCartHeight;
        return Column(
          children: [
            Expanded(
              child: _buildProductArea(cartState),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              height: cartHeight,
              child: _buildCartPanel(cartState),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductArea(CartState cartState) {
    if (cartState.activeParentForExtras != null) {
      return Column(
        children: [
          _buildBreadcrumbBar(
            icon: Icons.add_circle_outline_rounded,
            iconColor: AppColors.primary,
            label:
                'Suppléments pour ${cartState.activeParentForExtras?.product?.name ?? "Article"}',
            action: TextButton.icon(
              onPressed: () =>
                  ref.read(cartProvider.notifier).exitExtrasMode(),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Terminer'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
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
            iconColor: AppColors.ink3,
            label: cartState.categoryFilter!,
            action: TextButton.icon(
              onPressed: () =>
                  ref.read(cartProvider.notifier).setCategoryFilter(null),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Catégories'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink3,
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
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      decoration: const BoxDecoration(
        color: AppColors.surface0,
        border: Border(bottom: BorderSide(color: AppColors.surface3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.ink0,
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
        child: CircularProgressIndicator(color: AppColors.primary),
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
              padding: const EdgeInsets.all(AppSpacing.space3),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.65,
                crossAxisSpacing: AppSpacing.space4,
                mainAxisSpacing: AppSpacing.space4,
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
        child: CircularProgressIndicator(color: AppColors.primary),
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
              padding: const EdgeInsets.all(AppSpacing.space3),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.85,
                crossAxisSpacing: AppSpacing.space4,
                mainAxisSpacing: AppSpacing.space4,
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
        color: AppColors.cartBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cartMuted.withAlpha(102),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Cart Header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4, vertical: AppSpacing.space3),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cartSurface,
                    borderRadius: AppRadius.rMd,
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      size: 20, color: AppColors.cartAccent),
                ),
                const SizedBox(width: AppSpacing.space3),
                Text(
                  lines.isEmpty
                      ? 'Panier vide'
                      : '${lines.length} article${lines.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppColors.cartText,
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
                          color: AppColors.cartText,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Text(
                        'Total',
                        style: TextStyle(
                          color: AppColors.cartMuted,
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
              color: AppColors.cartMuted.withAlpha(38),
            ),

            // Items list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space3, vertical: AppSpacing.space2),
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
                      color: AppColors.cartMuted.withAlpha(102),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    const Text(
                      'Ajoutez des articles',
                      style: TextStyle(
                        color: AppColors.cartMuted,
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
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: AppRadius.rMd,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.space4),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 18),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: AppRadius.rMd,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.space4),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 18),
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
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
              decoration: BoxDecoration(
                color: AppColors.cartSurface,
                borderRadius: AppRadius.rMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space3, vertical: AppSpacing.space3),
                    child: Row(
                      children: [
                        _buildQtyControl(index, line),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.product?.name ?? 'Produit Inconnu',
                                style: const TextStyle(
                                  color: AppColors.cartText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${line.total(config).toStringAsFixed(2)} DH',
                                style: const TextStyle(
                                  color: AppColors.cartAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => ref
                              .read(cartProvider.notifier)
                              .enterExtrasMode(line),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.cartAccent.withAlpha(38),
                              borderRadius: AppRadius.rMd,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.cartAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (line.orderItem.resolveExtras().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.only(
                          left: 52, right: AppSpacing.space3, bottom: AppSpacing.space3),
                      child: Column(
                        children: line.orderItem.resolveExtras().map((entry) {
                          final qty = entry.quantity;
                          final linked = line.orderItem.extras
                              .cast<Product?>()
                              .firstWhere((e) => e!.id == entry.productId,
                                  orElse: () => null);
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.space1),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 3,
                                  margin: const EdgeInsets.only(right: AppSpacing.space2),
                                  decoration: const BoxDecoration(
                                    color: AppColors.cartMuted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  '${entry.name}${qty > 1 ? " ×$qty" : ""}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.cartMuted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(entry.price * qty).toStringAsFixed(2)} DH',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.cartMuted,
                                  ),
                                ),
                                if (linked != null) ...[
                                  const SizedBox(width: AppSpacing.space2),
                                  GestureDetector(
                                    onTap: () => ref
                                        .read(cartProvider.notifier)
                                        .decrementExtra(linked),
                                    child: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 14,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
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
        color: AppColors.cartBg,
        borderRadius: AppRadius.rMd,
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
            child: Text(
              line.quantity.toString(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.cartText,
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.space3, AppSpacing.space2, AppSpacing.space3, AppSpacing.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isHandlingAction
                  ? null
                  : () => _handleCartAction('save-print'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                foregroundColor: AppColors.payNowText,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 18),
                  const SizedBox(width: AppSpacing.space2),
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
          if (!singleTicketMode) ...[
            const SizedBox(height: AppSpacing.space2),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _isHandlingAction
                    ? null
                    : () => _handleCartAction('single-print'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.cartMuted,
                  side: BorderSide(
                      color: AppColors.cartMuted.withAlpha(77)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.print_outlined, size: 15),
                    SizedBox(width: AppSpacing.space2),
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

  Widget _buildQtyButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.cartSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: AppColors.cartText),
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.ink4),
          const SizedBox(height: AppSpacing.space3),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.ink3,
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
              size: 40, color: AppColors.danger),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Erreur : $message',
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handleCartAction(String actionType) async {
    // P35: ignore double-taps while an action is already running — a second
    // tap used to spawn a second dialog/order/printer connection.
    if (_isHandlingAction) return;
    setState(() => _isHandlingAction = true);
    try {
      await _handleCartActionInner(actionType);
    } finally {
      if (mounted) setState(() => _isHandlingAction = false);
    }
  }

  Future<void> _handleCartActionInner(String actionType) async {
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
        // P12: clear → delete old → re-add must commit as ONE sealed save —
        // a crash in between used to leave the order with zero items.
        ref.read(objectBoxProvider).store.runInTransaction(TxMode.write, () {
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
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Commande mise à jour avec succès !')),
          );
          Navigator.of(context).pop();
        }
      } else {
        final orderNumber = orderRepo.getNextOrderNumber();
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
        // P12: number bump + order save commit together — all or nothing.
        ref.read(objectBoxProvider).store.runInTransaction(TxMode.write, () {
          orderRepo.incrementOrderNumber();
          orderRepo.putOrder(order);
        });
      }

      // P13: print while the cart still holds the takeaway flag and the
      // kitchen comment — clear it only after the receipt is built.
      _printReceipt(order);
      if (widget.orderToEdit == null) {
        ref.read(cartProvider.notifier).clearCart();
      }
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
      // P12: same sealed save as _saveOrder — crash-safe rewrite.
      ref.read(objectBoxProvider).store.runInTransaction(TxMode.write, () {
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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande mise à jour avec succès !')),
      );
      if (mounted) Navigator.of(context).pop();
    } else {
      final orderNumber = orderRepo.getNextOrderNumber();
      order = order_model.Order(
        date: DateTime.now(),
        orderNumber: orderNumber,
      );
      // P13: "Ticket Simple" orders were saved WITHOUT a seller — attach
      // the same user the normal confirm flow uses.
      if (widget.assignedUser != null) {
        order.user.target = widget.assignedUser;
      } else if (_currentAuthUser != null) {
        order.user.target = _currentAuthUser;
      }
      for (final line in cartState.lines) {
        order.items.add(line.orderItem);
      }
      // P12: number bump + order save commit together — all or nothing.
      ref.read(objectBoxProvider).store.runInTransaction(TxMode.write, () {
        orderRepo.incrementOrderNumber();
        orderRepo.putOrder(order);
      });
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    _printReceipt(order, singleTicket: true);
    if (widget.orderToEdit == null) {
      // P13: clear only after the receipt read the cart's takeaway/comment.
      ref.read(cartProvider.notifier).clearCart();
    }
  }

  void _printReceipt(order_model.Order order, {bool singleTicket = false}) {
    final cartState = ref.read(cartProvider);
    final pricing = PricingService();

    final orderPayload = {
      'id': order.id,
      'dailyNumber': order.orderNumber,
      'createdat': order.date.toIso8601String(),
      // P14: one money formula everywhere — stored price + extras.
      'total': order.items
          .fold<double>(0, (sum, item) => sum + pricing.calculateItemTotal(item)),
      'items': order.items
          .map((item) => {
                'id': item.product.target?.id,
                // P14: name/price as sold — survive deleted & edited products.
                'title': item.productName ??
                    item.product.target?.name ??
                    'Article',
                'quantity': item.quantity,
                'price': item.price ?? item.product.target?.price ?? 0,
                'extras': item.resolveExtras()
                    .map((extra) => {
                          'id': extra.productId,
                          'title': extra.name,
                          'quantity': extra.quantity,
                          'price': extra.price,
                        })
                    .toList(),
              })
          .toList(),
      'paymentMethod': 'cash',
    };

    final receiptData = ReceiptData.fromJson(orderPayload);
    final ob = ref.read(objectBoxProvider);

    // P13: the two copies are BY DESIGN (owner confirmed) — first for the
    // client, second for the kitchen/saving. The old bug: the cart was
    // already cleared when this ran, so takeaway & comment never printed.
    // Both copies now carry the real options, captured before clearing.
    final comment = cartState.comment.isNotEmpty ? cartState.comment : '';
    final takeAway = cartState.isTakeAway;

    PrinterHelper.printReceipt(
      receiptData,
      ob,
      comment: comment,
      isTakeAway: takeAway,
    );
    if (!singleTicket) {
      // Kitchen/saving copy, one second later (single ticket = one copy).
      Future.delayed(const Duration(milliseconds: 1000), () {
        PrinterHelper.printReceipt(
          receiptData,
          ob,
          comment: comment,
          isTakeAway: takeAway,
        );
      });
    }
  }
}
