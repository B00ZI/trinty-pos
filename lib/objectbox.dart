import 'objectbox.g.dart';
import 'models/product.dart';
import 'models/order_item.dart';
import 'models/printer_config.dart';
import 'models/expense.dart';
import 'models/store_config.dart';
import 'models/category.dart';
import 'models/app_user.dart';
import 'models/game_post.dart';
import 'models/party_tier.dart';
import 'models/game_session.dart';
import 'models/party_counter.dart';

class ObjectBox {
  /// The Store of this app.
  late final Store store;
  late final Box<Product> productBox;
  late final Box<OrderItem> orderItemBox;
  late final Box<PrinterConfig> printerConfigBox;
  late final Box<Expense> expenseBox;
  late final Box<StoreConfig> storeConfigBox;
  late final Box<Category> categoryBox;
  late final Box<AppUser> userBox;
  late final Box<GamePost> gamePostBox;
  late final Box<PartyTier> partyTierBox;
  late final Box<GameSession> gameSessionBox;
  late final Box<PartyCounter> partyCounterBox;

  ObjectBox._create(this.store) {
    productBox = Box<Product>(store);
    orderItemBox = Box<OrderItem>(store);
    printerConfigBox = Box<PrinterConfig>(store);
    expenseBox = Box<Expense>(store);
    storeConfigBox = Box<StoreConfig>(store);
    categoryBox = Box<Category>(store);
    userBox = Box<AppUser>(store);
    gamePostBox = Box<GamePost>(store);
    partyTierBox = Box<PartyTier>(store);
    gameSessionBox = Box<GameSession>(store);
    partyCounterBox = Box<PartyCounter>(store);
  }

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    final store = await openStore();
    return ObjectBox._create(store);
  }
}
