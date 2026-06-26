import 'dart:convert';
import 'package:Easify/models/product.dart';
import 'package:Easify/models/category.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
// import 'package:objectbox/objectbox.dart';

class DataBackupService {
  final ObjectBox _objectBox;

  DataBackupService(this._objectBox);

  String exportData() {
    final categories = _objectBox.categoryBox.getAll();
    final products = _objectBox.productBox.getAll();

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'products': products.map((p) => p.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  Map<String, int> importData(String jsonString) {
    int importedCategories = 0;
    int importedProducts = 0;

    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (!data.containsKey('version')) {
        throw Exception('Invalid backup format');
      }

      // Import categories
      if (data.containsKey('categories')) {
        final categoryList = data['categories'] as List;
        for (final item in categoryList) {
          if (item is Map<String, dynamic>) {
            final categoryName = item['name'] as String?;
            if (categoryName != null && categoryName.isNotEmpty) {
              final existingQuery = _objectBox.categoryBox
                  .query(Category_.name.equals(categoryName))
                  .build();
              final existing = existingQuery.findFirst();
              existingQuery.close();

              final newCategory = Category.fromJson(item);
              if (existing != null) {
                newCategory.id = existing.id; // Update existing
              }
              _objectBox.categoryBox.put(newCategory);
              importedCategories++;
            }
          }
        }
      }

      // Import products
      if (data.containsKey('products')) {
        final productList = data['products'] as List;
        for (final item in productList) {
          if (item is Map<String, dynamic>) {
            final productName = item['name'] as String?;
            if (productName != null && productName.isNotEmpty) {
              final existingQuery = _objectBox.productBox
                  .query(Product_.name.equals(productName))
                  .build();
              final existing = existingQuery.findFirst();
              existingQuery.close();

              final newProduct = Product.fromJson(item);
              if (existing != null) {
                newProduct.id = existing.id; // Update existing
              }
              _objectBox.productBox.put(newProduct);
              importedProducts++;
            }
          }
        }
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'importation: $e');
    }

    return {
      'categories': importedCategories,
      'products': importedProducts,
    };
  }
}
