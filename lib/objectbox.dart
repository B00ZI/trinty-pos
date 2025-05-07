import 'objectbox.g.dart';
import 'models/product.dart';
import 'models/order_item.dart';
import 'models/printer_config.dart';

class ObjectBox {
  /// The Store of this app.
  late final Store store;
  late final Box<Product> productBox;
  late final Box<OrderItem> orderItemBox;
  late final Box<PrinterConfig> printerConfigBox;

  ObjectBox._create(this.store) {
    productBox = Box<Product>(store);
    orderItemBox = Box<OrderItem>(store);
    printerConfigBox = Box<PrinterConfig>(store);
  }

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    final store = await openStore();
    return ObjectBox._create(store);
  }
}