import 'package:Easify/models/category.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';

class CategoryRepository {
  final ObjectBox _objectbox;
  late final Box<Category> _categoryBox;

  CategoryRepository(this._objectbox) {
    _categoryBox = _objectbox.store.box<Category>();
  }

  List<Category> getAll() {
    final categories = _categoryBox.getAll();
    categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return categories;
  }

  Stream<List<Category>> watchAll() {
    return _categoryBox.query().watch(triggerImmediately: true).map((q) => q.find());
  }

  void put(Category category) {
    _categoryBox.put(category);
  }

  void putMany(List<Category> categories) {
    _categoryBox.putMany(categories);
  }

  void remove(int id) {
    _categoryBox.remove(id);
  }

  Category? findByName(String name) {
    final query = _categoryBox
        .query(Category_.name.equals(name))
        .build();
    final result = query.findFirst();
    query.close();
    return result;
  }
}
