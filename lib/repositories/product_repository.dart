import 'package:Easify/models/product.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';

class ProductRepository {
  final ObjectBox _objectbox;
  late final Box<Product> _productBox;

  ProductRepository(this._objectbox) {
    _productBox = _objectbox.store.box<Product>();
  }

  List<Product> getAll() {
    return _productBox.getAll();
  }

  Product? getById(int id) {
    return _productBox.get(id);
  }

  Stream<List<Product>> watchAll() {
    return _productBox.query().watch().map((q) => q.find());
  }

  Stream<List<Product>> watchAvailable() {
    return _productBox
        .query(Product_.isAvailable.equals(true))
        .watch()
        .map((q) => q.find());
  }

  List<Product> getByCategory(String? category) {
    if (category == null) {
      return _productBox.getAll();
    }
    final query = _productBox
        .query(Product_.category.equals(category))
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  void put(Product product) {
    _productBox.put(product);
  }

  void putMany(List<Product> products) {
    _productBox.putMany(products);
  }

  void remove(int id) {
    _productBox.remove(id);
  }

  Product? findByName(String name) {
    final query = _productBox
        .query(Product_.name.equals(name))
        .build();
    final result = query.findFirst();
    query.close();
    return result;
  }
}
