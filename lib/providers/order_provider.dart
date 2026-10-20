import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/models/order.dart' as order_model;
import 'package:Easify/models/order_item.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/models/store_config.dart';

// ─── Cart Item (UI-layer representation) ─────────────────────────────────────
/// A mutable cart-line used by the order screen.
/// Wraps an [OrderItem] plus optional extra-tracking state.
class CartLine {
  final OrderItem orderItem;

  CartLine(this.orderItem);

  Product? get product => orderItem.product.target;
  int get quantity => orderItem.quantity;
  set quantity(int v) => orderItem.quantity = v;

  /// Product price × qty (surge included) — without extras.
  double baseTotal(StoreConfig? config) {
    double basePrice = (orderItem.price ?? product?.price ?? 0).toDouble();
    // Apply surge pricing if the item has no persisted price yet
    if (orderItem.price == null &&
        config != null &&
        config.isSurgePriceEnabled &&
        config.surgeProductIds.contains(product?.id)) {
      basePrice += config.surgePriceAmount;
    }
    return orderItem.quantity * basePrice;
  }

  /// Total price for this line (base × qty + extras).
  double total(StoreConfig? config) {
    double t = baseTotal(config);
    final multiplier = orderItem.isPerUnitExtras ? orderItem.quantity : 1;
    for (final extra in orderItem.resolveExtras()) {
      t += extra.price * extra.quantity * multiplier;
    }
    return t;
  }
}

// ─── Cart State ──────────────────────────────────────────────────────────────
class CartState {
  final List<CartLine> lines;
  final bool isTakeAway;
  final String comment;
  final String? categoryFilter;
  final String? previousCategoryFilter;
  final CartLine? activeParentForExtras;
  final order_model.Order? orderToEdit;

  const CartState({
    this.lines = const [],
    this.isTakeAway = false,
    this.comment = '',
    this.categoryFilter,
    this.previousCategoryFilter,
    this.activeParentForExtras,
    this.orderToEdit,
  });

  CartState copyWith({
    List<CartLine>? lines,
    bool? isTakeAway,
    String? comment,
    String? categoryFilter,
    String? previousCategoryFilter,
    bool clearCategoryFilter = false,
    CartLine? activeParentForExtras,
    bool clearActiveParent = false,
    order_model.Order? orderToEdit,
    bool clearOrderToEdit = false,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      isTakeAway: isTakeAway ?? this.isTakeAway,
      comment: comment ?? this.comment,
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      previousCategoryFilter:
          previousCategoryFilter ?? this.previousCategoryFilter,
      activeParentForExtras: clearActiveParent
          ? null
          : (activeParentForExtras ?? this.activeParentForExtras),
      orderToEdit: clearOrderToEdit ? null : (orderToEdit ?? this.orderToEdit),
    );
  }

  double grandTotal(StoreConfig? config) {
    return lines.fold<double>(0, (sum, line) => sum + line.total(config));
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  // ── Cart operations ──────────────────────────────────────────────────────

  /// Add a product to the cart (or increment quantity if already present).
  /// If [activeParentForExtras] is set, the product is added as an extra.
  void addToCart(Product product) {
    if (state.activeParentForExtras != null) {
      final parent = state.activeParentForExtras!;
      final currentQty = parent.orderItem.getExtraQuantity(product);
      if (parent.orderItem.extras.any((e) => e.id == product.id)) {
        parent.orderItem.setExtraQuantity(product, currentQty + 1);
      } else {
        parent.orderItem.setExtraQuantity(product, 1);
      }
      // Trigger rebuild
      state = state.copyWith(lines: List.of(state.lines));
      return;
    }

    // Option B: only lines WITHOUT extras merge on tap. A configured line
    // (one with extras) is closed — tapping its product starts a separate
    // line, so "1 thé lait + 1 thé sans" is expressible.
    final existingLine = state.lines.cast<CartLine?>().firstWhere(
          (l) =>
              l!.product?.id == product.id &&
              l.orderItem.resolveExtras().isEmpty,
          orElse: () => null,
        );

    if (existingLine != null && existingLine.quantity > 0) {
      existingLine.quantity++;
      state = state.copyWith(lines: List.of(state.lines));
    } else {
      final item = OrderItem(quantity: 1);
      item.product.target = product;
      state = state.copyWith(lines: [...state.lines, CartLine(item)]);
    }
  }

  /// Decrement quantity or remove the line at [index].
  void removeItem(int index) {
    final lines = List<CartLine>.from(state.lines);
    if (lines[index].quantity > 1) {
      lines[index].quantity--;
    } else {
      lines.removeAt(index);
    }
    state = state.copyWith(lines: lines);
  }

  /// Increment quantity of the line at [index].
  void incrementItem(int index) {
    final lines = List<CartLine>.from(state.lines);
    lines[index].quantity++;
    state = state.copyWith(lines: lines);
  }

  /// Remove the line at [index] entirely.
  void removeLineAt(int index) {
    final lines = List<CartLine>.from(state.lines)..removeAt(index);
    state = state.copyWith(lines: lines);
  }

  /// Clear all items from the cart.
  void clearCart() {
    state = state.copyWith(
      lines: [],
      isTakeAway: false,
      comment: '',
      clearCategoryFilter: true,
      clearActiveParent: true,
      clearOrderToEdit: true,
    );
  }

  /// P23: starting a NEW sale must never inherit an old order's lines.
  ///
  /// A normal draft is kept (you added 3 teas, checked the printer, came
  /// back — nothing should be lost). Only a cart loaded from an EXISTING
  /// order (`orderToEdit != null`, via Historique → Modifier → ←) is
  /// dropped: keeping it would charge those items a second time as a
  /// brand-new order (double-charge risk).
  ///
  /// Returns `true` when old-order lines were dropped, so the screen can
  /// tell the owner what happened.
  bool prepareNewOrder() {
    if (state.orderToEdit == null) return false;
    clearCart();
    return true;
  }

  // ── Extras ───────────────────────────────────────────────────────────────

  /// Enter "extras mode" for the given cart line.
  void enterExtrasMode(CartLine line) {
    state = CartState(
      lines: state.lines,
      isTakeAway: state.isTakeAway,
      comment: state.comment,
      previousCategoryFilter: state.categoryFilter,
      categoryFilter: 'Extra',
      activeParentForExtras: line,
      orderToEdit: state.orderToEdit,
    );
  }

  /// Exit extras mode, restoring the previous category filter.
  void exitExtrasMode() {
    state = CartState(
      lines: state.lines,
      isTakeAway: state.isTakeAway,
      comment: state.comment,
      categoryFilter: state.previousCategoryFilter,
      orderToEdit: state.orderToEdit,
    );
  }

  /// Decrement an extra's quantity on the given line (or remove it).
  /// Targets the line the button belongs to — works in and out of extras
  /// mode (bug: it only looked at the "active" extras line, so the −
  /// button was dead as soon as you left extras mode, and with two
  /// lines it could decrement the wrong line's extra).
  void decrementExtra(CartLine line, Product extra) {
    final qty = line.orderItem.getExtraQuantity(extra);
    line.orderItem.setExtraQuantity(extra, qty - 1);
    state = state.copyWith(lines: List.of(state.lines));
  }

  // ── Category filter ──────────────────────────────────────────────────────

  void setCategoryFilter(String? category) {
    if (category == null) {
      state = state.copyWith(clearCategoryFilter: true);
    } else {
      state = state.copyWith(categoryFilter: category);
    }
  }

  // ── Take-away / comment ──────────────────────────────────────────────────

  void setTakeAway(bool value) {
    state = state.copyWith(isTakeAway: value);
  }

  void setComment(String value) {
    state = state.copyWith(comment: value);
  }

  // ── Edit mode ────────────────────────────────────────────────────────────

  /// Load an existing order into the cart for editing.
  void loadOrderForEditing(order_model.Order order) {
    final lines = <CartLine>[];
    for (final item in order.items) {
      final cartItem = OrderItem(quantity: item.quantity);
      cartItem.product.target = item.product.target;
      cartItem.price = item.price;
      cartItem.productName = item.productName;
      for (final extra in item.extras) {
        cartItem.extras.add(extra);
      }
      if (item.extraQuantitiesJson != null) {
        cartItem.extraQuantitiesJson = item.extraQuantitiesJson;
      }
      lines.add(CartLine(cartItem));
    }
    state = CartState(lines: lines, orderToEdit: order);
  }

  /// Apply surge pricing to all cart lines that don't have a persisted price.
  void applySurgePricing(StoreConfig config) {
    if (!config.isSurgePriceEnabled) return;
    for (final line in state.lines) {
      if (line.orderItem.price == null) {
        final product = line.product;
        if (product != null && config.surgeProductIds.contains(product.id)) {
          line.orderItem.price = product.price + config.surgePriceAmount;
        }
      }
    }
  }

  /// Persist prices and product names on all cart lines before saving.
  void persistPrices(StoreConfig? config) {
    for (final line in state.lines) {
      if (line.orderItem.price == null) {
        double price = line.product?.price ?? 0;
        if (config != null &&
            config.isSurgePriceEnabled &&
            config.surgeProductIds.contains(line.product?.id)) {
          price += config.surgePriceAmount;
        }
        line.orderItem.price = price;
      }
      line.orderItem.productName = line.product?.name;
    }
  }
}
