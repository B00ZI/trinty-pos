import 'dart:io';

import 'objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  ///
  /// Desktop (P07): the database lives in %LOCALAPPDATA%\Easify\objectbox —
  /// out of the OneDrive-synced, casually-browsable Documents folder — and a
  /// legacy Documents\objectbox store is migrated on first launch.
  /// Android/iOS keep the platform default (app-private sandbox).
  static Future<ObjectBox> create() async {
    final store = await _openStore();
    return ObjectBox._create(store);
  }

  static Future<Store> _openStore() async {
    if (Platform.isAndroid || Platform.isIOS) return openStore();

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) return openStore();

    final dir = Directory(p.join(localAppData, 'Easify', 'objectbox'));
    await dir.create(recursive: true);

    // One-time migration: copy the legacy Documents\objectbox store.
    if (!File(p.join(dir.path, 'data.mdb')).existsSync()) {
      try {
        final legacyDir = Directory(p.join(
            (await getApplicationDocumentsDirectory()).path, 'objectbox'));
        if (legacyDir.existsSync()) {
          for (final entry in legacyDir.listSync()) {
            if (entry is File) {
              entry.copySync(p.join(dir.path, p.basename(entry.path)));
            }
          }
        }
      } catch (_) {
        // No legacy store or unreadable — start fresh at the new location.
      }
    }

    return openStore(directory: dir.path);
  }
}
