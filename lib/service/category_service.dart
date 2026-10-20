import 'package:Easify/models/category.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/objectbox.g.dart';

/// P21 — a category is linked to its products BY NAME (kept that way on
/// purpose: switching to ids would need an ObjectBox schema change + code
/// regeneration, which this project avoids).
///
/// The name is therefore a live reference, and this service owns the rules
/// that keep it true:
///  * a rename carries every product along — otherwise the products stay
///    tagged with the old name and become unreachable on the order screen
///    (no category card matches them anymore);
///  * a category that still holds products must not be deletable (the
///    caller refuses first, this service reports the usage);
///  * a save never loses the category's place in the reorderable grid.
class CategoryService {
  CategoryService._();

  /// Puts [cat] and, when the name changed, retags every product that
  /// pointed at [oldName] — everything inside ONE write transaction, so a
  /// crash can never leave a half-renamed catalogue.
  ///
  /// Returns how many products followed the rename.
  static int putKeepingProducts(Store store, Category cat, {String? oldName}) {
    return store.runInTransaction(TxMode.write, () {
      store.box<Category>().put(cat);
      final previous = oldName;
      if (previous == null || previous.isEmpty || previous == cat.name) {
        return 0;
      }
      final query = store
          .box<Product>()
          .query(Product_.category.equals(previous))
          .build();
      try {
        final products = query.find();
        if (products.isEmpty) return 0;
        for (final product in products) {
          product.category = cat.name;
        }
        store.box<Product>().putMany(products);
        return products.length;
      } finally {
        query.close();
      }
    });
  }

  /// How many products still point at this category (P21 delete guard).
  static int usageCount(Store store, String categoryName) {
    if (categoryName.isEmpty) return 0;
    final query = store
        .box<Product>()
        .query(Product_.category.equals(categoryName))
        .build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }

  /// Position for a NEW category: right after the last one (0 = first).
  /// Editing keeps `cat.displayOrder` — the old dialog rebuilt the entity
  /// from scratch without its displayOrder, so every edited category was
  /// silently reset to 0 and jumped to the front of the grid.
  static int nextDisplayOrder(Store store) {
    final all = store.box<Category>().getAll();
    var max = -1;
    for (final c in all) {
      if (c.displayOrder > max) max = c.displayOrder;
    }
    return max + 1;
  }
}
