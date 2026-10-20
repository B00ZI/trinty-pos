import 'dart:convert';

import 'package:Easify/models/app_user.dart';
import 'package:Easify/models/category.dart';
import 'package:Easify/models/daily_funds.dart';
import 'package:Easify/models/expense.dart';
import 'package:Easify/models/game_post.dart';
import 'package:Easify/models/game_session.dart';
import 'package:Easify/models/order.dart' as order_model;
import 'package:Easify/models/order_counter.dart';
import 'package:Easify/models/order_item.dart';
import 'package:Easify/models/party_counter.dart';
import 'package:Easify/models/party_tier.dart';
import 'package:Easify/models/printer_config.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/models/store_config.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:Easify/service/input_rules.dart';
import 'package:objectbox/objectbox.dart';

/// Which slices of the shop a backup file carries (P26).
///
/// The owner picks these in the export dialog: everything (recommended) or
/// just the parts he wants. Counters (order/party numbers) always travel
/// with the file so order numbers never go backwards after a restore.
class BackupSections {
  final bool catalogue; // products + categories
  final bool orders; // orders + their items
  final bool users; // sellers (name + PIN hash)
  final bool expenses;
  final bool funds; // fond de caisse
  final bool games; // posts, tiers, sessions
  final bool settings; // store config + printer configs

  const BackupSections({
    this.catalogue = true,
    this.orders = true,
    this.users = true,
    this.expenses = true,
    this.funds = true,
    this.games = true,
    this.settings = true,
  });

  bool get isEmpty =>
      !catalogue &&
      !orders &&
      !users &&
      !expenses &&
      !funds &&
      !games &&
      !settings;

  Map<String, bool> asMap() => {
        'catalogue': catalogue,
        'orders': orders,
        'users': users,
        'expenses': expenses,
        'funds': funds,
        'games': games,
        'settings': settings,
      };

  factory BackupSections.fromMap(Map<String, dynamic> map) => BackupSections(
        catalogue: map['catalogue'] == true,
        orders: map['orders'] == true,
        users: map['users'] == true,
        expenses: map['expenses'] == true,
        funds: map['funds'] == true,
        games: map['games'] == true,
        settings: map['settings'] == true,
      );
}

/// Full-data backup (P26).
///
/// Version 2 exports EVERYTHING the shop owns — orders, users (PINs still
/// work after a restore), expenses, cash floats, game sessions with their
/// order link, printer configs and shop settings — section by section, and
/// asks "what will be replaced?" before importing. Old version-1 files
/// (products + categories only) still import exactly as they always did.
///
/// The **Wi-Fi password is never exported or imported**: it lives in the OS
/// secure storage (P07), and a JSON file passed around must not carry it.
class DataBackupService {
  final ObjectBox _objectBox;

  DataBackupService(this._objectBox);

  static const int currentVersion = 2;

  // ── Export ────────────────────────────────────────────────────────────────

  String exportData({BackupSections sections = const BackupSections()}) {
    if (sections.isEmpty) {
      throw Exception('Sélection vide : cochez au moins une catégorie');
    }

    final orderBox = _objectBox.store.box<order_model.Order>();
    final dailyFundsBox = _objectBox.store.box<DailyFunds>();

    final data = <String, dynamic>{
      'version': currentVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'includes': sections.asMap(),
      'counters': {
        'order': _orderCounterValue(),
        'party': _partyCounterValue(),
      },
    };

    if (sections.catalogue) {
      data['categories'] =
          _objectBox.categoryBox.getAll().map(categoryToJson).toList();
      data['products'] =
          _objectBox.productBox.getAll().map(productToJson).toList();
    }
    if (sections.orders) {
      data['orders'] = orderBox.getAll().map(orderToJson).toList();
    }
    if (sections.users) {
      data['users'] = _objectBox.userBox.getAll().map(userToJson).toList();
    }
    if (sections.expenses) {
      data['expenses'] =
          _objectBox.expenseBox.getAll().map(expenseToJson).toList();
    }
    if (sections.funds) {
      data['funds'] = dailyFundsBox.getAll().map(fundsToJson).toList();
    }
    if (sections.games) {
      data['gamePosts'] =
          _objectBox.gamePostBox.getAll().map(gamePostToJson).toList();
      data['partyTiers'] =
          _objectBox.partyTierBox.getAll().map(partyTierToJson).toList();
      data['gameSessions'] =
          _objectBox.gameSessionBox.getAll().map(gameSessionToJson).toList();
    }
    if (sections.settings) {
      // wifiPassword is deliberately absent (see class doc).
      final configs = _objectBox.storeConfigBox.getAll();
      data['storeConfig'] =
          configs.isEmpty ? null : storeConfigToJson(configs.first);
      data['printerConfigs'] = _objectBox.printerConfigBox
          .getAll()
          .map(printerConfigToJson)
          .toList();
    }

    return jsonEncode(data);
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Per-section counts found in the file — used by the confirmation dialog
  /// so the owner sees "what will be replaced" BEFORE anything is written
  /// (P26). `'legacy': 1` marks an old products+categories-only file.
  Map<String, int> previewImport(String jsonString) {
    final Map<String, dynamic> data = _decode(jsonString);
    if (!data.containsKey('version')) {
      throw Exception('Format de sauvegarde inconnu');
    }
    return {
      'legacy': (data['version'] as num?) == 1 ? 1 : 0,
      'categories': _len(data['categories']),
      'products': _len(data['products']),
      'orders': _len(data['orders']),
      'users': _len(data['users']),
      'expenses': _len(data['expenses']),
      'funds': _len(data['funds']),
      'gameSessions': _len(data['gameSessions']),
      'gamePosts': _len(data['gamePosts']),
      'partyTiers': _len(data['partyTiers']),
      'printerConfigs': _len(data['printerConfigs']),
      'settings': data['storeConfig'] is Map ? 1 : 0,
    };
  }

  /// Imports a backup file. Runs as **one transaction** — all-or-nothing,
  /// the same promise as every save in the app (P12).
  ///
  /// Rules (never a surprise wipe — ids are NOT copied blindly: ObjectBox
  /// only accepts explicit ids up to its own sequence, and two shops can
  /// legitimately use the same id. Records are matched by what they ARE and
  /// every link is rebuilt through a backup-id → local-id map):
  /// - products / categories → merged **by name** (same rule as v1);
  /// - users → added unless a user with the same name already exists (the
  ///   local PIN always wins, so an import can never lock staff out);
  /// - orders → skipped when that **order number** is already here (live
  ///   orders are never touched), seller/product links remapped;
  /// - expenses / cash floats / sessions / posts / tiers / printers →
  ///   skipped when the same record already exists;
  /// - shop settings → applied onto the shop's own config row;
  /// - counters → `max(current, backup)` so numbers never go backwards.
  Map<String, int> importData(String jsonString) {
    final Map<String, dynamic> data = _decode(jsonString);
    if (!data.containsKey('version')) {
      throw Exception('Format de sauvegarde inconnu');
    }
    if ((data['version'] as num?) == 1) return _importLegacy(data);

    final result = <String, int>{
      'categories': 0,
      'products': 0,
      'orders': 0,
      'users': 0,
      'expenses': 0,
      'funds': 0,
      'gameSessions': 0,
      'gamePosts': 0,
      'partyTiers': 0,
      'printerConfigs': 0,
      'settings': 0,
    };

    // Backup id → local id. ObjectBox only accepts explicit ids up to its
    // own id sequence, so a restore lets it assign fresh ids and the links
    // (seller, product, extras, game order link) are rebuilt through these
    // maps — they are the whole point of a restore.
    final userIds = <int, int>{};
    final productIds = <int, int>{};
    final orderIds = <int, int>{};
    final postIds = <int, int>{};
    final tierIds = <int, int>{};

    try {
      _objectBox.store.runInTransaction(TxMode.write, () {
        if (data['categories'] is List) {
          result['categories'] = _importCategories(data['categories'] as List);
        }
        if (data['products'] is List) {
          result['products'] =
              _importProducts(data['products'] as List, productIds);
        }
        if (data['users'] is List) {
          result['users'] = _importUsers(data['users'] as List, userIds);
        }
        if (data['orders'] is List) {
          result['orders'] = _importOrders(
              data['orders'] as List, orderIds, userIds, productIds);
        }
        if (data['expenses'] is List) {
          result['expenses'] = _importExpenses(data['expenses'] as List);
        }
        if (data['funds'] is List) {
          result['funds'] = _importFunds(data['funds'] as List);
        }
        if (data['gamePosts'] is List) {
          result['gamePosts'] =
              _importGamePosts(data['gamePosts'] as List, postIds);
        }
        if (data['partyTiers'] is List) {
          result['partyTiers'] =
              _importPartyTiers(data['partyTiers'] as List, tierIds);
        }
        if (data['gameSessions'] is List) {
          result['gameSessions'] = _importGameSessions(data['gameSessions']
              as List, orderIds, postIds, tierIds, userIds);
        }
        if (data['storeConfig'] is Map) {
          result['settings'] =
              _importStoreConfig(data['storeConfig'] as Map);
        }
        if (data['printerConfigs'] is List) {
          result['printerConfigs'] =
              _importPrinterConfigs(data['printerConfigs'] as List);
        }
        if (data['counters'] is Map) {
          _importCounters(data['counters'] as Map);
        }
      });
    } catch (e) {
      throw Exception('Importation annulée, aucune donnée modifiée : $e');
    }

    return result;
  }

  // ── Section importers (called inside the import transaction) ─────────────

  int _importCategories(List items) {
    final box = _objectBox.categoryBox;
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final name = (item['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final existing = _findByNormalized(
          box.getAll(), name, (c) => c.name);
      if (existing != null) {
        // Merge by name (v1 rule) — the local id wins so product links and
        // the category sort stay valid.
        box.put(Category(
          id: existing.id,
          name: name,
          imageUrl: item['imageUrl'] as String?,
          displayOrder: (item['displayOrder'] as num?)?.toInt() ??
              existing.displayOrder,
        ));
      } else {
        // Fresh row: ObjectBox assigns the id (explicit ids are only
        // accepted up to its own id sequence).
        box.put(Category(
          id: 0,
          name: name,
          imageUrl: item['imageUrl'] as String?,
          displayOrder: (item['displayOrder'] as num?)?.toInt() ?? 0,
        ));
      }
      count++;
    }
    return count;
  }

  int _importProducts(List items, Map<int, int> ids) {
    final box = _objectBox.productBox;
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final name = (json['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final oldId = (json['id'] as num?)?.toInt() ?? 0;
      final existing =
          _findByNormalized(box.getAll(), name, (p) => p.name);
      final p = Product.fromJson(json);
      p.name = name;
      if (existing != null) {
        // Merge by name (v1 rule) — the local row wins, its id too, so the
        // shop's own order lines keep pointing where they pointed.
        p.id = existing.id;
      } else {
        p.id = 0;
      }
      final localId = box.put(p);
      if (oldId != 0) ids[oldId] = localId;
      count++;
    }
    return count;
  }

  int _importUsers(List items, Map<int, int> ids) {
    final box = _objectBox.userBox;
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final name = (item['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final oldId = (item['id'] as num?)?.toInt() ?? 0;
      // Never two users with the same name (P30) — and the LOCAL pin wins,
      // so importing can never lock the staff out of their own tablet. The
      // orders of a skipped user still find their seller through the map.
      final existing =
          _findByNormalized(box.getAll(), name, (u) => u.name);
      if (existing != null) {
        if (oldId != 0) ids[oldId] = existing.id;
        continue;
      }
      final createdAt = (item['createdAt'] as num?)?.toInt();
      final localId = box.put(AppUser(
        id: 0,
        name: name,
        pin: item['pin'] as String?,
        pinSalt: item['pinSalt'] as String?,
        isAdmin: item['isAdmin'] == true,
        createdAt: createdAt == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(createdAt),
      ));
      if (oldId != 0) ids[oldId] = localId;
      count++;
    }
    return count;
  }

  int _importOrders(List items, Map<int, int> orderIds, Map<int, int> userIds,
      Map<int, int> productIds) {
    final box = _objectBox.store.box<order_model.Order>();
    final itemBox = _objectBox.orderItemBox;
    final localOrders = box.getAll();
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final oldId = (item['id'] as num?)?.toInt() ?? 0;
      final orderNumber = (item['orderNumber'] as num?)?.toInt() ?? 0;
      // Live orders are never touched: the shop's own order number is the
      // identity of an order — same number = same sale already here.
      final existing = _findByOrderNumber(localOrders, orderNumber);
      if (existing != null) {
        if (oldId != 0) orderIds[oldId] = existing.id;
        continue;
      }

      final dateMs = (item['date'] as num?)?.toInt();
      final order = order_model.Order(
        id: 0,
        orderNumber: orderNumber,
        date: dateMs == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(dateMs),
        isDeleted: item['isDeleted'] == true,
        isEdited: item['isEdited'] == true,
        relatedGameSessionId: (item['relatedGameSessionId'] as num?)?.toInt(),
      );
      final userId = (item['userId'] as num?)?.toInt();
      final localUser = userId == null ? null : userIds[userId];
      if (localUser != null) order.user.targetId = localUser;

      if (item['items'] is List) {
        for (final raw in item['items'] as List) {
          if (raw is! Map) continue;
          final line = OrderItem(
            id: 0,
            quantity: (raw['quantity'] as num?)?.toInt() ?? 1,
            extraQuantitiesJson: raw['extraQuantitiesJson'] as String?,
            price: (raw['price'] as num?)?.toDouble(),
            productName: raw['productName'] as String?,
          );
          final productId = (raw['productId'] as num?)?.toInt();
          final localProduct =
              productId == null ? null : productIds[productId];
          if (localProduct != null) line.product.targetId = localProduct;
          if (raw['extraProductIds'] is List) {
            // Extras are re-linked through the products that were just
            // imported — a missing extra would lose its price/name on
            // old-format lines (P15/P22 read the live product as fallback).
            for (final e in raw['extraProductIds'] as List) {
              final extraId = (e as num?)?.toInt();
              final localExtra =
                  extraId == null ? null : productIds[extraId];
              final extraProduct = localExtra == null
                  ? null
                  : _objectBox.productBox.get(localExtra);
              if (extraProduct != null) line.extras.add(extraProduct);
            }
          }
          itemBox.put(line);
          order.items.add(line);
        }
      }
      final localId = box.put(order);
      if (oldId != 0) orderIds[oldId] = localId;
      count++;
    }
    return count;
  }

  int _importExpenses(List items) {
    final box = _objectBox.expenseBox;
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final dateMs = (item['date'] as num?)?.toInt();
      final title = item['title'] as String? ?? '';
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      // Same day + same amount + same title = the same expense already here.
      final duplicate = box.getAll().any((e) =>
          e.date.millisecondsSinceEpoch == dateMs &&
          e.amount == amount &&
          e.title == title);
      if (duplicate) continue;
      box.put(Expense(
        id: 0,
        title: title,
        amount: amount,
        date: dateMs == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(dateMs),
      ));
      count++;
    }
    return count;
  }

  int _importFunds(List items) {
    final box = _objectBox.store.box<DailyFunds>();
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final dateMs = (item['date'] as num?)?.toInt();
      if (dateMs == null) continue;
      // One float per business day by design — same day = already here.
      final duplicate = box
          .getAll()
          .any((f) => f.date.millisecondsSinceEpoch == dateMs);
      if (duplicate) continue;
      final record = DailyFunds(
        date: DateTime.fromMillisecondsSinceEpoch(dateMs),
        amount: (item['amount'] as num?)?.toDouble() ?? 0,
      );
      box.put(record);
      count++;
    }
    return count;
  }

  int _importGamePosts(List items, Map<int, int> ids) {
    final box = _objectBox.gamePostBox;
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final oldId = (item['id'] as num?)?.toInt() ?? 0;
      final label = item['label'] as String? ?? '';
      final existing = box.getAll().cast<GamePost?>().firstWhere(
            (p) => p!.label == label,
            orElse: () => null,
          );
      if (existing != null) {
        if (oldId != 0) ids[oldId] = existing.id;
        continue;
      }
      final localId = box.put(GamePost(id: 0, label: label));
      if (oldId != 0) ids[oldId] = localId;
      count++;
    }
    return count;
  }

  int _importPartyTiers(List items, Map<int, int> ids) {
    final box = _objectBox.partyTierBox;
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final oldId = (item['id'] as num?)?.toInt() ?? 0;
      final label = item['label'] as String? ?? '';
      final existing = box.getAll().cast<PartyTier?>().firstWhere(
            (t) => t!.label == label,
            orElse: () => null,
          );
      if (existing != null) {
        if (oldId != 0) ids[oldId] = existing.id;
        continue;
      }
      final localId = box.put(PartyTier(
        id: 0,
        label: label,
        ratePerHour: (item['ratePerHour'] as num?)?.toDouble() ?? 0,
      ));
      if (oldId != 0) ids[oldId] = localId;
      count++;
    }
    return count;
  }

  int _importGameSessions(List items, Map<int, int> orderIds,
      Map<int, int> postIds, Map<int, int> tierIds, Map<int, int> userIds) {
    final box = _objectBox.gameSessionBox;
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final startMs = (item['startTime'] as num?)?.toInt();
      if (startMs == null) continue;
      final postLabel = item['postLabel'] as String? ?? '';
      final partyNumber = (item['partyNumber'] as num?)?.toInt() ?? 0;
      // Same start + same post + same party number = the same session is
      // already here (importing a file twice never duplicates a session).
      final duplicate = box.getAll().any((s) =>
          s.startTime.millisecondsSinceEpoch == startMs &&
          s.postLabel == postLabel &&
          s.partyNumber == partyNumber);
      if (duplicate) continue;

      final endMs = (item['endTime'] as num?)?.toInt();
      final postId = (item['postId'] as num?)?.toInt() ?? 0;
      final tierId = (item['tierId'] as num?)?.toInt() ?? 0;
      final localPost = postIds[postId];
      final localTier = tierIds[tierId];
      final session = GameSession(
        id: 0,
        postId: localPost ?? postId,
        tierId: localTier ?? tierId,
        postLabel: postLabel,
        partyNumber: partyNumber,
        tierLabel: item['tierLabel'] as String? ?? '',
        startTime: DateTime.fromMillisecondsSinceEpoch(startMs),
        endTime:
            endMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endMs),
        status: (item['status'] as num?)?.toInt() ?? 0,
        ratePerHour: (item['ratePerHour'] as num?)?.toDouble() ?? 0,
        // Seller attribution is rebuilt through the user map — a raw id
        // from another shop could point at a completely different person.
        attributedUserId: null,
        // P24: the order link travels with the backup, rebuilt through the
        // order map — a restored session without it would count the same
        // game sale twice. No mapped order (orders not in the file) → the
        // session simply carries its own revenue, still counted once.
        relatedOrderId: orderIds[(item['relatedOrderId'] as num?)?.toInt() ?? 0],
        isLimitedDuration: item['isLimitedDuration'] == true,
        limitedDurationMinutes:
            (item['limitedDurationMinutes'] as num?)?.toInt() ?? 0,
      );
      if (localPost != null) session.post.targetId = localPost;
      if (localTier != null) session.tier.targetId = localTier;
      final attributed =
          (item['attributedUserId'] as num?)?.toInt();
      final localUser = attributed == null ? null : userIds[attributed];
      if (localUser != null) session.attributedUserId = localUser;
      box.put(session);
      count++;
    }
    return count;
  }

  int _importStoreConfig(Map item) {
    final box = _objectBox.storeConfigBox;
    final existing = box.getAll();
    final target =
        existing.isNotEmpty ? existing.first : StoreConfig(id: 0);
    target.storeName = item['storeName'] as String?;
    target.storePhone = item['storePhone'] as String?;
    target.storeLogoPath = item['storeLogoPath'] as String?;
    target.dayStartHour = (item['dayStartHour'] as num?)?.toInt() ?? 0;
    target.dayStartMinute = (item['dayStartMinute'] as num?)?.toInt() ?? 0;
    target.dayEndHour = (item['dayEndHour'] as num?)?.toInt() ?? 23;
    target.dayEndMinute = (item['dayEndMinute'] as num?)?.toInt() ?? 59;
    target.isSurgePriceEnabled = item['isSurgePriceEnabled'] == true;
    target.surgePriceAmount =
        (item['surgePriceAmount'] as num?)?.toDouble() ?? 0;
    target.surgeProductIds = [
      for (final e in (item['surgeProductIds'] as List? ?? const []))
        if (e is num) e.toInt()
    ];
    // wifiPassword deliberately untouched — secure storage is the source of
    // truth (P07); a backup file must never carry or restore it.
    if (existing.isEmpty) {
      target.id = 0; // ObjectBox assigns on a fresh shop
    }
    box.put(target);
    return 1;
  }

  int _importPrinterConfigs(List items) {
    final box = _objectBox.printerConfigBox;
    int count = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final ipAddress = item['ipAddress'] as String? ?? '';
      if (ipAddress.isEmpty) continue;
      // One printer per IP — the local config for that printer stays.
      final duplicate = box
          .getAll()
          .any((c) => c.ipAddress == ipAddress && c.port == (item['port'] as num?)?.toInt());
      if (duplicate) continue;
      box.put(PrinterConfig(
        id: 0,
        ipAddress: ipAddress,
        port: (item['port'] as num?)?.toInt() ?? 9100,
        singleTicketMode: item['singleTicketMode'] == true,
        enableChangeWindow: item['enableChangeWindow'] != false,
      ));
      count++;
    }
    return count;
  }

  void _importCounters(Map counters) {
    final orderValue = (counters['order'] as num?)?.toInt();
    if (orderValue != null) {
      final box = _objectBox.store.box<OrderCounter>();
      final current = box.isEmpty() ? 0 : box.getAll().first.value;
      if (orderValue > current) {
        box.put(OrderCounter(id: 1, value: orderValue));
      }
    }
    final partyValue = (counters['party'] as num?)?.toInt();
    if (partyValue != null) {
      final box = _objectBox.store.box<PartyCounter>();
      final current = box.isEmpty() ? 0 : box.getAll().first.value;
      if (partyValue > current) {
        box.put(PartyCounter(id: 1, value: partyValue));
      }
    }
  }

  /// Old version-1 files (products + categories only) keep working exactly
  /// as before: merge by name, no questions asked.
  Map<String, int> _importLegacy(Map<String, dynamic> data) {
    int categories = 0;
    int products = 0;
    try {
      _objectBox.store.runInTransaction(TxMode.write, () {
        if (data['categories'] is List) {
          categories = _importCategories(data['categories'] as List);
        }
        if (data['products'] is List) {
          products = _importProducts(data['products'] as List, {});
        }
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'importation: $e');
    }
    return {'categories': categories, 'products': products};
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  static Map<String, dynamic> _decode(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('contenu inattendu');
      }
      return decoded;
    } catch (e) {
      throw Exception('Fichier de sauvegarde illisible ($e)');
    }
  }

  static int _len(dynamic v) => v is List ? v.length : 0;

  static order_model.Order? _findByOrderNumber(
      List<order_model.Order> all, int orderNumber) {
    if (orderNumber <= 0) return null;
    for (final order in all) {
      if (order.orderNumber == orderNumber) return order;
    }
    return null;
  }

  static T? _findByNormalized<T>(
      List<T> all, String name, String Function(T) nameOf) {
    final key = InputRules.normalizeName(name);
    for (final element in all) {
      if (InputRules.normalizeName(nameOf(element)) == key) return element;
    }
    return null;
  }

  int _orderCounterValue() {
    final box = _objectBox.store.box<OrderCounter>();
    return box.isEmpty() ? 1 : box.getAll().first.value;
  }

  int _partyCounterValue() {
    final box = _objectBox.store.box<PartyCounter>();
    return box.isEmpty() ? 1 : box.getAll().first.value;
  }

  // ── JSON encoders (id included — a restore must keep relations) ───────────

  static Map<String, dynamic> categoryToJson(Category c) => {
        'id': c.id,
        'name': c.name,
        'imageUrl': c.imageUrl,
        'displayOrder': c.displayOrder,
      };

  static Map<String, dynamic> productToJson(Product p) => {
        'id': p.id,
        'name': p.name,
        'price': p.price,
        'category': p.category,
        'description': p.description,
        'imageUrl': p.imageUrl,
        'isAvailable': p.isAvailable,
        'displayOrder': p.displayOrder,
      };

  static Map<String, dynamic> orderToJson(order_model.Order o) => {
        'id': o.id,
        'orderNumber': o.orderNumber,
        'date': o.date.millisecondsSinceEpoch,
        'isDeleted': o.isDeleted,
        'isEdited': o.isEdited,
        'relatedGameSessionId': o.relatedGameSessionId,
        'userId': o.user.targetId == 0 ? null : o.user.targetId,
        'items': o.items.map(itemToJson).toList(),
      };

  static Map<String, dynamic> itemToJson(OrderItem it) => {
        'id': it.id,
        'quantity': it.quantity,
        'price': it.price,
        'productName': it.productName,
        'extraQuantitiesJson': it.extraQuantitiesJson,
        'productId': it.product.targetId == 0 ? null : it.product.targetId,
        'extraProductIds': [for (final e in it.extras) e.id],
      };

  static Map<String, dynamic> userToJson(AppUser u) => {
        'id': u.id,
        'name': u.name,
        'pin': u.pin,
        'pinSalt': u.pinSalt,
        'isAdmin': u.isAdmin,
        'createdAt': u.createdAt.millisecondsSinceEpoch,
      };

  static Map<String, dynamic> expenseToJson(Expense e) => {
        'id': e.id,
        'title': e.title,
        'amount': e.amount,
        'date': e.date.millisecondsSinceEpoch,
      };

  static Map<String, dynamic> fundsToJson(DailyFunds f) => {
        'id': f.id,
        'date': f.date.millisecondsSinceEpoch,
        'amount': f.amount,
      };

  static Map<String, dynamic> gamePostToJson(GamePost p) => {
        'id': p.id,
        'label': p.label,
        'isActive': p.isActive,
      };

  static Map<String, dynamic> partyTierToJson(PartyTier t) => {
        'id': t.id,
        'label': t.label,
        'ratePerHour': t.ratePerHour,
      };

  static Map<String, dynamic> gameSessionToJson(GameSession s) => {
        'id': s.id,
        'postId': s.postId,
        'tierId': s.tierId,
        'postLabel': s.postLabel,
        'partyNumber': s.partyNumber,
        'tierLabel': s.tierLabel,
        'startTime': s.startTime.millisecondsSinceEpoch,
        'endTime': s.endTime?.millisecondsSinceEpoch,
        'status': s.status,
        'ratePerHour': s.ratePerHour,
        'attributedUserId': s.attributedUserId,
        'relatedOrderId': s.relatedOrderId,
        'isLimitedDuration': s.isLimitedDuration,
        'limitedDurationMinutes': s.limitedDurationMinutes,
      };

  /// Wi-Fi password excluded on purpose (secure storage, P07).
  static Map<String, dynamic> storeConfigToJson(StoreConfig c) => {
        'id': c.id,
        'storeName': c.storeName,
        'storePhone': c.storePhone,
        'storeLogoPath': c.storeLogoPath,
        'dayStartHour': c.dayStartHour,
        'dayStartMinute': c.dayStartMinute,
        'dayEndHour': c.dayEndHour,
        'dayEndMinute': c.dayEndMinute,
        'isSurgePriceEnabled': c.isSurgePriceEnabled,
        'surgePriceAmount': c.surgePriceAmount,
        'surgeProductIds': c.surgeProductIds,
      };

  static Map<String, dynamic> printerConfigToJson(PrinterConfig c) => {
        'id': c.id,
        'ipAddress': c.ipAddress,
        'port': c.port,
        'singleTicketMode': c.singleTicketMode,
        'enableChangeWindow': c.enableChangeWindow,
      };
}
