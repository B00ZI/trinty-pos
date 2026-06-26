import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/models/category.dart';
import 'package:Easify/repositories/product_repository.dart';
import 'package:Easify/repositories/category_repository.dart';
import 'dashboard_provider.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final ob = ref.watch(objectBoxProvider);
  return ProductRepository(ob);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final ob = ref.watch(objectBoxProvider);
  return CategoryRepository(ob);
});

// Stream providers for reactive updates
final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.watchAll();
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchAll();
});

// Selected category filter
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Filtered products based on selected category
final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);

  return productsAsync.whenData((products) {
    if (selectedCategory == null) {
      return products.where((p) => p.category != 'Extra').toList();
    }
    return products.where((p) => p.category == selectedCategory).toList();
  });
});

// Extra products
final extraProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productsStreamProvider);

  return productsAsync.whenData((products) {
    return products.where((p) => p.category == 'Extra').toList();
  });
});
