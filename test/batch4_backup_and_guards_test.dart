import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/models/app_user.dart';
import 'package:Easify/models/category.dart';
import 'package:Easify/models/daily_funds.dart';
import 'package:Easify/models/expense.dart';
import 'package:Easify/models/game_post.dart';
import 'package:Easify/models/game_session.dart';
import 'package:Easify/models/order.dart' as order_model;
import 'package:Easify/models/order_counter.dart';
import 'package:Easify/models/order_item.dart';
import 'package:Easify/models/party_tier.dart';
import 'package:Easify/models/printer_config.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/models/store_config.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:Easify/providers/order_provider.dart';
import 'package:Easify/service/data_backup_service.dart';
import 'package:Easify/service/game_session_service.dart';
import 'package:Easify/service/input_rules.dart';
import 'package:objectbox/objectbox.dart' as obx;

/// Batch 4 — P23 (old order's lines in the cart), P24 (game order ↔ session
/// link = one sealed save), P26 (real full backup: sections, "what will be
/// replaced?" question, one button → Exporter/Importer), P30 (price/name
/// checks: 0 allowed, negative never, same name never).
///
/// The real-store groups need `objectbox.dll` discoverable (it ships with
/// the debug build): run `flutter build windows --debug` once and add
/// `build\windows\x64\runner\Debug` to PATH before `flutter test`.
/// Without it those groups skip instead of failing.
void main() {
  final storeAvailable = Platform.environment['PATH']?.split(';').any(
          (d) => File('$d/objectbox.dll').existsSync()) ??
      false;
  final storeSkip = storeAvailable
      ? null
      : 'objectbox.dll not on PATH — build windows debug and add '
          'build\\windows\\x64\\runner\\Debug to PATH';

  // ── P30 ──────────────────────────────────────────────────────────────────
  group('P30 — price and name checks', () {
    test('0 is a valid price (free products are real)', () {
      expect(InputRules.nonNegativePrice('0'), isNull);
      expect(InputRules.nonNegativePrice('0,00'), isNull);
    });

    test('a negative price is refused with a message', () {
      expect(InputRules.nonNegativePrice('-5'), 'Le prix ne peut pas être négatif');
      expect(InputRules.nonNegativePrice('-0,01'), 'Le prix ne peut pas être négatif');
    });

    test('French comma and normal prices pass', () {
      expect(InputRules.nonNegativePrice('12,5'), isNull);
      expect(InputRules.nonNegativePrice('120'), isNull);
    });

    test('garbage is refused (never a silent 0.00)', () {
      expect(InputRules.nonNegativePrice('abc'), 'Prix valide requis');
      expect(InputRules.nonNegativePrice(''), 'Prix valide requis');
      expect(InputRules.nonNegativePrice('12e5'), 'Prix valide requis');
    });

    test('the same name never twice — case, spaces and accents ignored', () {
      expect(InputRules.uniqueName('Youssef', ['youssef']), 'Ce nom existe déjà');
      expect(InputRules.uniqueName('  The ', ['THÉ']), 'Ce nom existe déjà');
      expect(InputRules.uniqueName('Cafe noir', ['café  noir']), 'Ce nom existe déjà');
      expect(InputRules.uniqueName('Karim', ['Youssef']), isNull);
    });

    test('editing a record does not collide with itself', () {
      expect(InputRules.uniqueName('Thé', ['Thé', 'Lait'], excluding: 'Thé'),
          isNull);
      expect(InputRules.uniqueName('Lait', ['Thé', 'Lait'], excluding: 'Thé'),
          'Ce nom existe déjà');
    });
  });

  // ── P23 ──────────────────────────────────────────────────────────────────
  group('P23 — an old order never leaks into a new sale', () {
    Product tea() => Product(name: 'Thé', price: 8);

    test('cart loaded from an order is dropped when a new sale starts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);

      final order = order_model.Order(
          orderNumber: 12, date: DateTime(2026, 10, 19));
      final item = OrderItem(quantity: 3, price: 8, productName: 'Thé');
      item.product.target = tea();
      order.items.add(item);

      cart.loadOrderForEditing(order);
      expect(container.read(cartProvider).lines, hasLength(1));

      final dropped = cart.prepareNewOrder();
      expect(dropped, isTrue);
      expect(container.read(cartProvider).lines, isEmpty);
      expect(container.read(cartProvider).orderToEdit, isNull,
          reason: 'the edit flag must go too, or the cart looks like it is '
              'still editing that order');
    });

    test('a normal new-order draft is kept (nothing is lost)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);

      cart.addToCart(tea());
      cart.addToCart(tea()); // ×2
      expect(cart.prepareNewOrder(), isFalse);
      expect(container.read(cartProvider).lines, hasLength(1));
      expect(container.read(cartProvider).lines.first.quantity, 2);
    });

    test('a draft typed after an edit is also kept', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);

      cart.loadOrderForEditing(order_model.Order(
          orderNumber: 4, date: DateTime(2026, 10, 19)));
      expect(cart.prepareNewOrder(), isTrue); // old lines dropped

      cart.addToCart(tea()); // fresh draft
      expect(cart.prepareNewOrder(), isFalse);
      expect(container.read(cartProvider).lines, hasLength(1));
    });
  });

  // ── P24 ──────────────────────────────────────────────────────────────────
  group('P24 — game order + session link = ONE sealed save', () {
    late Directory tmpDir;
    late obx.Store store;
    late ObjectBox objectbox;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('easify_b4_p24');
      store = obx.Store(getObjectBoxModel(), directory: tmpDir.path);
      objectbox = ObjectBox.attach(store);
    });

    tearDown(() {
      store.close();
      tmpDir.deleteSync(recursive: true);
    });

    test('happy path: order, counter, session and link land together',
        () async {
      final post = GamePost(label: 'Post 1');
      objectbox.gamePostBox.put(post);
      final tier = PartyTier(label: 'PS5', ratePerHour: 40);
      objectbox.partyTierBox.put(tier);
      final counterBox = store.box<OrderCounter>();
      counterBox.put(OrderCounter(id: 1, value: 1));

      // Exactly the games_screen flow: build in memory, write in ONE tx.
      final session = await GameSessionService.prepareSession(
        post: post,
        tier: tier,
        userId: null,
        objectbox: objectbox,
        durationMinutes: 30,
      );
      final orderBox = store.box<order_model.Order>();
      final counter = counterBox.get(1)!;
      final order = order_model.Order(
          date: DateTime.now(), orderNumber: counter.value);
      final item = OrderItem(quantity: 1, price: 20, productName: 'Jeu (30min): Post 1');
      order.items.add(item);

      store.runInTransaction(obx.TxMode.write, () {
        orderBox.put(order);
        counter.value += 1;
        counterBox.put(counter);
        session.relatedOrderId = order.id;
        post.isActive = true;
        objectbox.gamePostBox.put(post);
        objectbox.gameSessionBox.put(session);
      });

      expect(order.id, greaterThan(0));
      expect(objectbox.gameSessionBox.get(session.id)!.relatedOrderId, order.id,
          reason: 'the link is what stops the sale being counted twice');
      expect(counterBox.get(1)!.value, 2);
      expect(objectbox.gamePostBox.get(post.id)!.isActive, isTrue);
      expect(objectbox.gameSessionBox.count(), 1);
    });

    test('a crash inside the sealed save leaves NOTHING behind', () async {
      final post = GamePost(label: 'Post 1');
      objectbox.gamePostBox.put(post);
      final tier = PartyTier(label: 'PS5', ratePerHour: 40);
      objectbox.partyTierBox.put(tier);
      final counterBox = store.box<OrderCounter>();
      counterBox.put(OrderCounter(id: 1, value: 1));

      final session = await GameSessionService.prepareSession(
        post: post,
        tier: tier,
        userId: null,
        objectbox: objectbox,
        durationMinutes: 30,
      );
      final orderBox = store.box<order_model.Order>();
      final counter = counterBox.get(1)!;

      // ObjectBox rethrows a failing transaction callback as
      // UnsupportedError — what matters is the save was rejected as a whole.
      expect(
        () => store.runInTransaction(obx.TxMode.write, () {
          final order = order_model.Order(
              date: DateTime.now(), orderNumber: counter.value);
          orderBox.put(order);
          counter.value += 1;
          counterBox.put(counter);
          session.relatedOrderId = order.id;
          objectbox.gameSessionBox.put(session);
          throw StateError('tablet battery died');
        }),
        throwsA(isA<UnsupportedError>()),
      );

      expect(orderBox.count(), 0, reason: 'no half-written order');
      expect(objectbox.gameSessionBox.count(), 0,
          reason: 'no session without its order');
      expect(counterBox.get(1)!.value, 1, reason: 'order number rolled back');
    });

    test('prepareSession writes nothing by itself', () async {
      final post = GamePost(label: 'Post 1');
      objectbox.gamePostBox.put(post);
      final tier = PartyTier(label: 'PS5', ratePerHour: 40);
      objectbox.partyTierBox.put(tier);

      final session = await GameSessionService.prepareSession(
          post: post, tier: tier, userId: null, objectbox: objectbox);

      expect(objectbox.gameSessionBox.count(), 0);
      expect(session.postLabel, 'Post 1');
      expect(session.isLimitedDuration, isFalse);
    });
  }, skip: storeSkip);

  // ── P26 ──────────────────────────────────────────────────────────────────
  group('P26 — real full backup', () {
    late Directory dirA;
    late obx.Store storeA;
    late ObjectBox boxA;

    setUp(() {
      dirA = Directory.systemTemp.createTempSync('easify_b4_bak');
      storeA = obx.Store(getObjectBoxModel(), directory: dirA.path);
      boxA = ObjectBox.attach(storeA);
    });

    tearDown(() {
      storeA.close();
      dirA.deleteSync(recursive: true);
    });

    /// A whole little shop: menu, staff, a sold order with an extra, an
    /// expense, the cash float, a paid game session and the settings.
    void fillShop(ObjectBox box) {
      final cat = Category(name: 'Boissons');
      box.categoryBox.put(cat);
      final tea = Product(name: 'Thé', price: 8, category: 'Boissons');
      box.productBox.put(tea);
      final milk = Product(name: 'Lait', price: 3, category: 'Extra');
      box.productBox.put(milk);

      final (hash, salt) = AppUser.hashPin('1234');
      final user = AppUser(name: 'Youssef', pin: hash, pinSalt: salt);
      box.userBox.put(user);

      final orderBox = box.store.box<order_model.Order>();
      box.store.box<OrderCounter>().put(OrderCounter(id: 1, value: 17));
      final order = order_model.Order(
          date: DateTime(2026, 10, 19, 12), orderNumber: 17);
      order.user.target = user;
      final item = OrderItem(quantity: 2, price: 8, productName: 'Thé');
      item.product.target = tea;
      item.setExtraQuantity(milk, 1);
      order.items.add(item);
      orderBox.put(order);

      box.expenseBox.put(Expense(
          title: 'Lait fournisseur', amount: 120, date: DateTime(2026, 10, 19)));
      final funds = DailyFunds(date: DateTime(2026, 10, 19), amount: 300);
      box.store.box<DailyFunds>().put(funds);

      final post = GamePost(label: 'Post 1');
      box.gamePostBox.put(post);
      final tier = PartyTier(label: 'PS5', ratePerHour: 40);
      box.partyTierBox.put(tier);
      final session = GameSession(
        postLabel: 'Post 1',
        partyNumber: 1,
        tierLabel: 'PS5',
        startTime: DateTime(2026, 10, 19, 20),
        endTime: DateTime(2026, 10, 19, 21),
        status: 1,
        ratePerHour: 40,
        // P24: the link rides along in the backup — without it a restore
        // would count the same game sale twice.
        relatedOrderId: order.id,
      );
      session.post.targetId = post.id;
      session.tier.targetId = tier.id;
      box.gameSessionBox.put(session);

      box.storeConfigBox.put(StoreConfig(
          storeName: 'Café Test', wifiPassword: 'SECRET-WIFI'));
      box.printerConfigBox
          .put(PrinterConfig(ipAddress: '192.168.1.50', port: 9100));
    }

    test('a full backup restores everything on an empty shop', () {
      fillShop(boxA);
      final json = DataBackupService(boxA).exportData();
      expect(json.contains('SECRET-WIFI'), isFalse,
          reason: 'the Wi-Fi password lives in secure storage, never in a file');

      final dirC = Directory.systemTemp.createTempSync('easify_b4_dst');
      final storeC = obx.Store(getObjectBoxModel(), directory: dirC.path);
      final boxC = ObjectBox.attach(storeC);
      addTearDown(() {
        storeC.close();
        dirC.deleteSync(recursive: true);
      });

      final result = DataBackupService(boxC).importData(json);
      expect(result['categories'], 1);
      expect(result['products'], 2);
      expect(result['users'], 1);
      expect(result['orders'], 1);
      expect(result['expenses'], 1);
      expect(result['funds'], 1);
      expect(result['gamePosts'], 1);
      expect(result['partyTiers'], 1);
      expect(result['gameSessions'], 1);
      expect(result['settings'], 1);
      expect(result['printerConfigs'], 1);

      final restoredOrder =
          boxC.store.box<order_model.Order>().getAll().single;
      expect(restoredOrder.orderNumber, 17);
      expect(restoredOrder.user.target?.name, 'Youssef',
          reason: 'the seller link survived');
      final restoredItem = restoredOrder.items.single;
      expect(restoredItem.productName, 'Thé');
      expect(restoredItem.price, 8);
      expect(restoredItem.quantity, 2);
      expect(restoredItem.resolveExtras().single.name, 'Lait',
          reason: 'extras and their snapshot survive');

      expect(boxC.userBox.getAll().single.verifyPin('1234'), isTrue,
          reason: 'staff PINs still work after a restore');

      expect(boxC.gameSessionBox.getAll().single.relatedOrderId,
          restoredOrder.id,
          reason: 'P24: the game order link survives — no double count');

      expect(boxC.expenseBox.getAll().single.amount, 120);
      expect(boxC.store.box<DailyFunds>().getAll().single.amount, 300);
      expect(boxC.store.box<OrderCounter>().get(1)!.value, 17);
      expect(boxC.storeConfigBox.getAll().single.storeName, 'Café Test');
      expect(boxC.storeConfigBox.getAll().single.wifiPassword, isNull);
      expect(boxC.printerConfigBox.getAll().single.ipAddress, '192.168.1.50');
    });

    test('importing twice never duplicates or overwrites live data', () {
      fillShop(boxA);
      final json = DataBackupService(boxA).exportData();
      final result = DataBackupService(boxA).importData(json);

      expect(result['orders'], 0, reason: 'live orders are never replaced');
      expect(result['users'], 0, reason: 'a user with that name exists');
      expect(result['expenses'], 0);
      expect(result['gameSessions'], 0);
      expect(boxA.store.box<order_model.Order>().count(), 1);
      expect(boxA.userBox.count(), 1);
      expect(boxA.productBox.count(), 2,
          reason: 'products merge by name — no duplicates');
      expect(boxA.categoryBox.count(), 1);
    });

    test('the owner chooses what to export (sections)', () {
      fillShop(boxA);
      final json = DataBackupService(boxA).exportData(
        sections: const BackupSections(
          catalogue: true,
          orders: false,
          users: false,
          expenses: false,
          funds: false,
          games: false,
          settings: false,
        ),
      );
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['products'], isA<List>());
      expect(data['categories'], isA<List>());
      expect(data.containsKey('orders'), isFalse);
      expect(data.containsKey('users'), isFalse);
      expect(data.containsKey('gameSessions'), isFalse);

      expect(
        () => DataBackupService(boxA).exportData(
          sections: const BackupSections(
            catalogue: false,
            orders: false,
            users: false,
            expenses: false,
            funds: false,
            games: false,
            settings: false,
          ),
        ),
        throwsException,
      );
    });

    test('preview lists what the file contains BEFORE importing', () {
      fillShop(boxA);
      final json = DataBackupService(boxA).exportData();
      final preview = DataBackupService(boxA).previewImport(json);
      expect(preview['legacy'], 0);
      expect(preview['orders'], 1);
      expect(preview['products'], 2);
      expect(preview['categories'], 1);
      expect(preview['users'], 1);
      expect(preview['gameSessions'], 1);
      expect(preview['settings'], 1);
      expect(preview['printerConfigs'], 1);
      // …and preview wrote nothing.
      expect(boxA.store.box<order_model.Order>().count(), 1);
    });

    test('old version-1 files (menu only) still import', () {
      final legacy = jsonEncode({
        'version': 1,
        'categories': [
          {'name': 'Boissons'}
        ],
        'products': [
          {'name': 'Thé', 'price': 8.0, 'category': 'Boissons'}
        ],
      });
      final preview = DataBackupService(boxA).previewImport(legacy);
      expect(preview['legacy'], 1);

      final result = DataBackupService(boxA).importData(legacy);
      expect(result['products'], 1);
      expect(result['categories'], 1);
      expect(boxA.productBox.getAll().single.name, 'Thé');
    });

    test('order numbers never go backwards after a restore', () {
      fillShop(boxA);
      final json = DataBackupService(boxA).exportData();
      // This shop is already ahead of the backup (#40 sold after the file
      // was made).
      boxA.store.box<OrderCounter>().put(OrderCounter(id: 1, value: 40));
      DataBackupService(boxA).importData(json);
      expect(boxA.store.box<OrderCounter>().get(1)!.value, 40);
    });

    test('a file that is not a backup is refused, nothing written', () {
      expect(() => DataBackupService(boxA).importData('not json at all'),
          throwsException);
      expect(() => DataBackupService(boxA).previewImport('{"hello":1}'),
          throwsException);
      expect(boxA.productBox.count(), 0);
    });
  }, skip: storeSkip);
}
