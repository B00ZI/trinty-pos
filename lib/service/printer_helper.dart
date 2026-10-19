import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/store_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:image/image.dart' as img;
import '../models/printer_config.dart';
import 'package:Easify/objectbox.dart';
import '../objectbox.g.dart' as ob;
import '../models/order.dart' as order_model;
import '../models/game_session.dart';
import 'image_generatore.dart';
import 'package:intl/intl.dart';
import 'business_day_helper.dart';
import 'pricing_service.dart';
import 'wifi_password_store.dart';

// final _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();

class ReceiptData {
  final String id;
  final String dailyNumber;
  final String createdAt;
  final String total;
  final List<ReceiptItem> items;
  final String paymentMethod;
  final String? customerName;
  final String? customerPhone;

  ReceiptData({
    required this.id,
    required this.dailyNumber,
    required this.createdAt,
    required this.total,
    required this.items,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    List<ReceiptItem> items = [];

    try {
      if (json['items'] is String) {
        final itemsList = jsonDecode(json['items']) as List;
        items = itemsList.map((item) => ReceiptItem.fromJson(item)).toList();
      } else if (json['items'] is List) {
        items = (json['items'] as List)
            .map((item) => ReceiptItem.fromJson(item))
            .toList();
      }
    } catch (e) {
      debugPrint('Error parsing items: $e');
    }

    return ReceiptData(
      id: (json['id'] ?? '').toString(),
      dailyNumber:
          (json['dailyNumber'] ?? json['dailynumber'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['createdat'] ?? '').toString(),
      total: (json['total'] ?? '0').toString(),
      items: items,
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'] ?? 'cash')
          .toString(),
    );
  }

  /// Reprint path (P14): builds a receipt from what was ACTUALLY sold —
  /// the price stored on the sale, the name saved at sale time, and the
  /// extras — never today's product data (an edited price or a deleted
  /// product used to show wrong money or 0.00 on reprints).
  static ReceiptData convertRuciToReceiptData(order_model.Order order) {
    final pricing = PricingService();
    return ReceiptData(
      id: order.id.toString(),
      dailyNumber: order.orderNumber.toString(),
      createdAt: order.date.toIso8601String(),
      total: order.items
          .fold<double>(
              0, (sum, item) => sum + pricing.calculateItemTotal(item))
          .toStringAsFixed(2),
      items: order.items.map((item) {
        return ReceiptItem(
          id: item.id.toString(),
          title: item.productName ?? item.product.target?.name ?? 'Article',
          quantity: item.quantity,
          price: (item.price ?? item.product.target?.price ?? 0).toDouble(),
          extras: item.resolveExtras()
              .map((extra) => ReceiptItem(
                    id: extra.productId.toString(),
                    title: extra.name,
                    quantity: extra.quantity *
                        (item.isPerUnitExtras ? item.quantity : 1),
                    price: extra.price,
                  ))
              .toList(),
        );
      }).toList(),
      paymentMethod: 'cash',
    );
  }
}

class ReceiptItem {
  final String id;
  final String title;
  final int quantity;
  final double price;
  final List<ReceiptItem> extras;

  ReceiptItem({
    required this.id,
    required this.title,
    required this.quantity,
    required this.price,
    this.extras = const [],
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      extras: (json['extras'] as List?)
              ?.map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'quantity': quantity,
      'price': price,
      'extras': extras.map((e) => e.toJson()).toList(),
    };
  }

  double get total =>
      (quantity * price) +
      extras.fold(0.0, (sum, e) => sum + (e.price * e.quantity));
}

class PrinterHelper {
  /// Wired once in main.dart (P32/P37): any print failure surfaces as a
  /// snackbar so the owner ALWAYS learns the ticket did not print.
  static void Function(String message)? onError;

  /// French, friendly text for the common failures. Public — the Settings
  /// test button reuses it so no raw socket dump (timeout texts!) ever
  /// reaches the screen.
  static String friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('no_printer_config')) {
      return 'Aucune imprimante configurée (Paramètres → Imprimante)';
    }
    if (s.contains('Failed to connect') ||
        s.contains('printer_conn_failed') ||
        s.contains('timed out') ||
        s.contains('SocketException')) {
      return 'Connexion à l\'imprimante échouée — vérifiez l\'adresse IP';
    }
    return 'Erreur d\'impression : $e';
  }

  static void _notifyPrintFailure(Object e) {
    if (kDebugMode) {
      debugPrint('Print failed: $e');
    }
    onError?.call(friendlyError(e));
  }

  /// Wired once in main.dart too: a SUCCESSFUL print confirms with a short
  /// snackbar ("Ticket imprimé") so the owner knows the paper came out.
  static void Function(String message)? onSuccess;

  static Future<NetworkPrinter> connectToPrinter(ObjectBox objectbox) async {
    final printerConfigBox = objectbox.store.box<PrinterConfig>();
    final configs = printerConfigBox.getAll();
    // P32: no config at all used to throw a cryptic StateError from `.first`
    // that all 8 call sites swallowed — the button "did nothing".
    if (configs.isEmpty) throw StateError('no_printer_config');
    final printerConfig = configs.first;

    if (printerConfig.ipAddress.isEmpty) {
      throw StateError('no_printer_config');
    }

    final profile = await CapabilityProfile.load();
    final printer = SafePrinter(PaperSize.mm80, profile);

    final PosPrintResult result = await printer.connect(printerConfig.ipAddress,
        port: printerConfig.port);

    if (result != PosPrintResult.success) {
      throw Exception('Failed to connect to printer: $result');
    }

    return printer;
  }

  static Future<void> printReceipt(ReceiptData receipt, ObjectBox objectbox,
      {String comment = "", bool isTakeAway = false}) async {
    // P32/P37: the connection is INSIDE the try — an unreachable printer
    // used to throw before the catcher and die silently (no message at all).
    NetworkPrinter? printer;
    try {
      printer = await connectToPrinter(objectbox);
      // Instant feedback (owner request): the printer accepted the job —
      // the paper is coming, the user never wonders if it "went".
      onSuccess?.call('Ticket envoyé — en cours d\'impression…');

      final storeConfigBox = objectbox.store.box<StoreConfig>();
      final storeConfig = storeConfigBox.getAll().isNotEmpty
          ? storeConfigBox.getAll().first
          : null;

      printer.reset();
      await _printHeader(printer, receipt, storeConfig, comment);

      // Debug: Check items before printing
      debugPrint('Items to print: ${receipt.items}');

      _printItems(printer, receipt.items);
      await _printTotals(printer, receipt, isTakeAway, storeConfig);
      _printFooter(printer, receipt);

      printer.cut(mode: PosCutMode.partial);
      onSuccess?.call('Ticket imprimé');
    } catch (e) {
      // P32/P37: a failed ticket is never swallowed silently — the owner
      // gets a snackbar via onError (wired in main.dart).
      _notifyPrintFailure(e);
    } finally {
      printer?.disconnect();
    }
  }

  static Future<void> _printHeader(NetworkPrinter printer, ReceiptData receipt,
      StoreConfig? config, String comment) async {
    await _printLogoImage(printer, config?.storeLogoPath);

    final storeName =
        config?.storeName?.isNotEmpty == true ? config!.storeName! : 'FRITA';

    printer.text(
      storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    if (config?.storePhone?.isNotEmpty == true) {
      printer.text(
        config!.storePhone!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    printer.row([
      PosColumn(
        text: 'EASIFY POS',
        width: 8,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
      PosColumn(
        text: 'Modern Point of Sale',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (comment.isNotEmpty) {
      printer.hr();
      printer.text(
        comment,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );
    }
    printer.hr();

    printer.row([
      PosColumn(
        text: 'Order #${receipt.dailyNumber}',
        width: 8,
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        text: 'ID: ${receipt.id}',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    printer.text(
      _formatDate(receipt.createdAt),
      styles: const PosStyles(align: PosAlign.right),
    );

    // if (receipt.customerName != null && receipt.customerName!.isNotEmpty) {
    //   printer.text('Customer: ${receipt.customerName!}');
    // }
    // if (receipt.customerPhone != null && receipt.customerPhone!.isNotEmpty) {
    //   printer.text('Phone: ${receipt.customerPhone!}');
    // }

    printer.hr();
  }

  static Future<void> _printLogoImage(
      NetworkPrinter printer, String? logoPath) async {
    try {
      Uint8List? imgBytes;

      if (logoPath != null && logoPath.isNotEmpty) {
        final file = File(logoPath);
        if (await file.exists()) {
          imgBytes = await file.readAsBytes();
        }
      }

      // If no custom logo is found, just return (print nothing for logo)
      // The store name will be printed by the caller
      if (imgBytes == null) {
        return;
      }

      // P36: decode + resize off the UI thread — a big logo used to stutter
      // the whole screen while printing.
      final logoBytes = imgBytes;
      final img.Image? resized = await Isolate.run(() {
        final im = img.decodeImage(logoBytes);
        if (im == null) return null;
        // Resize (thermal printers work best at 200–250px width)
        return img.copyResize(im, width: 200);
      });
      if (resized == null) {
        throw Exception('Failed to decode image');
      }

      // Directly print using built-in ESC/POS image handling
      printer.image(resized);

      printer.feed(1);
    } catch (e) {
      debugPrint("Image print failed: $e");
      // _printTextLogo(printer); // fallback
    }
  }

  static void _printTextLogo(NetworkPrinter printer) {
    printer.text(
      '====================',
      styles: const PosStyles(align: PosAlign.center),
    );
    printer.text(
      '   EASIFY POS   ',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    printer.text(
      '====================',
      styles: const PosStyles(align: PosAlign.center),
    );
    printer.feed(1);
  }

  static void _printItems(NetworkPrinter printer, List<ReceiptItem> items) {
    if (items.isEmpty) {
      printer.text(
        'No items to display',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      return;
    }

    printer.text(
      'ITEMS',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    printer.hr();

    for (final item in items) {
      printer.row([
        PosColumn(
          text: '${item.quantity} x ${item.title}',
          width: 8,
          styles: const PosStyles(bold: true, align: PosAlign.left),
        ),
        PosColumn(
          text: '${item.price.toStringAsFixed(2)} DH',
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      for (final extra in item.extras) {
        printer.row([
          PosColumn(
            text:
                '  + ${extra.title} ${extra.quantity > 1 ? "x${extra.quantity}" : ""}'
                    .trimRight(),
            width: 8,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: '${(extra.price * extra.quantity).toStringAsFixed(2)} DH',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
    }

    printer.hr();
  }

  static Future<void> _printTotals(NetworkPrinter printer, ReceiptData receipt,
      bool isTakeAway, StoreConfig? config) async {
    final subtotal = receipt.items.fold(0.0, (sum, item) => sum + item.total);
    final total = double.tryParse(receipt.total) ?? subtotal;

    printer.row([
      PosColumn(
        text: 'TOTAL:',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size1),
      ),
      PosColumn(
        text: '${total.toStringAsFixed(2)} DH',
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size1,
        ),
      ),
    ]);

    printer.hr();

    if (isTakeAway) {
      final takeAwayStrip = ImageGenerator.generateTakeAwayStrip();
      printer.image(takeAwayStrip);
      printer.feed(1);
    }

    // Wi-Fi password comes from secure storage (P07); the legacy DB field
    // is only a fallback so a receipt can never lose it.
    var wifiPassword = await WifiPasswordStore.read();
    if (wifiPassword.isEmpty) wifiPassword = config?.wifiPassword ?? '';
    if (wifiPassword.isNotEmpty) {
      printer.text(
        'WIFI: $wifiPassword',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      );
    }
  }

  static void _printFooter(
    NetworkPrinter printer,
    ReceiptData receipt,
  ) {
    printer.feed(2);

    printer.text(
      "Thank you for your order! Come Again!",
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    printer.feed(2);
  }

  static String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  static String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'CASH';
      case 'card':
        return 'CARD';
      case 'delivery':
        return 'DELIVERY';
      default:
        return method.toUpperCase();
    }
  }

  static Future<void> testPrinter(ObjectBox objectBox) async {
    // Fetch store config
    final storeConfigBox = objectBox.store.box<StoreConfig>();
    final storeConfig = storeConfigBox.getAll().isNotEmpty
        ? storeConfigBox.getAll().first
        : null;
    final storeName = storeConfig?.storeName?.isNotEmpty == true
        ? storeConfig!.storeName!
        : 'Easify POS System';

    // P32/P37: the connection is INSIDE the try — an unreachable printer
    // used to throw before the catcher and die silently.
    NetworkPrinter? printer;
    try {
      printer = await connectToPrinter(objectBox);
      onSuccess?.call('Test envoyé à l\'imprimante…');

      printer.text(
        'PRINTER TEST',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      printer.text(
        storeName,
        styles: const PosStyles(align: PosAlign.center),
      );
      printer.hr();
      printer.text('Test Date: ${DateTime.now()}');
      printer.text('Status: CONNECTED');
      printer.feed(2);
      printer.text('✅ Printer Test Successful');
      printer.feed(2);
      printer.cut(mode: PosCutMode.partial);
      onSuccess?.call('Test imprimé');
    } catch (e) {
      // P31/P32: the test button used to die silently (latin1 crash on ✅,
      // cryptic missing-printer StateError) — report it instead.
      _notifyPrintFailure(e);
    } finally {
      printer?.disconnect();
    }
  }

  static Future<void> printStoreConfig(ObjectBox objectbox) async {
    // P32/P37: the connection is INSIDE the try — an unreachable printer
    // used to throw before the catcher and die silently.
    NetworkPrinter? printer;
    try {
      printer = await connectToPrinter(objectbox);
      onSuccess?.call('Ticket envoyé — en cours d\'impression…');

      final storeConfigBox = objectbox.store.box<StoreConfig>();
      final storeConfig = storeConfigBox.getAll().isNotEmpty
          ? storeConfigBox.getAll().first
          : null;

      printer.reset();

      // Print logo and store name/phone using the header logic (minimal receipt data)
      final dummyReceipt = ReceiptData(
        id: 'CONFIG-TEST',
        dailyNumber: '00',
        createdAt: DateTime.now().toIso8601String(),
        total: '0.00',
        items: [],
        paymentMethod: 'TEST',
      );
      final comment = '';

      await _printHeader(printer, dummyReceipt, storeConfig, comment);

      printer.feed(2);
      printer.text(
        'STORE CONFIGURATION TEST',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      printer.feed(1);
      printer.text(
        '✅ Connection: OK',
        styles: const PosStyles(align: PosAlign.center),
      );

      printer.feed(3);
      printer.cut(mode: PosCutMode.partial);
      onSuccess?.call('Ticket de configuration imprimé');
    } catch (e) {
      // P37: config-test print failures surface too, never vanish.
      _notifyPrintFailure(e);
    } finally {
      printer?.disconnect();
    }
  }

  static String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static Future<void> printGameTicket(
      GameSession session, ObjectBox objectbox) async {
    final printerConfigBox = objectbox.store.box<PrinterConfig>();
    final configs = printerConfigBox.getAll();
    if (configs.isEmpty) {
      // P32: no printer configured → tell the owner instead of nothing.
      _notifyPrintFailure(StateError('no_printer_config'));
      return;
    }
    final config = configs.first;

    final profile = await CapabilityProfile.load();
    final printer = SafePrinter(PaperSize.mm80, profile);
    var connected = false;

    try {
      final PosPrintResult res =
          await printer.connect(config.ipAddress, port: config.port);
      connected = res == PosPrintResult.success;
      // P37: a failed connection used to `return` silently.
      if (!connected) throw StateError('printer_conn_failed');
      onSuccess?.call('Ticket envoyé — en cours d\'impression…');

      printer.reset();
      printer.text('===== TICKET JEUX =====',
          styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      printer.feed(1);

      printer.text('Poste:       ${session.postLabel}',
          styles: const PosStyles(bold: true));
      printer.text('Partie #:    ${session.partyNumber}');
      printer.text('Palier:      ${session.tierLabel}');
      printer
          .text('Tarif:       ${session.ratePerHour.toStringAsFixed(2)} DH/H');
      printer.feed(1);

      printer.text('Debut:       ${_formatTime(session.startTime)}');
      final end = session.endTime ?? DateTime.now();
      final duration = end.difference(session.startTime);
      final minutes = duration.inMinutes;

      printer.text('Fin:         ${_formatTime(end)}');
      printer.text('Temps:       ${minutes} min',
          styles: const PosStyles(bold: true));
      printer.text(
          'Total:       ${session.currentCalculatedPrice.toStringAsFixed(2)} DH',
          styles: const PosStyles(bold: true));

      printer.feed(1);
      printer.text('Merci de votre visite !',
          styles: const PosStyles(align: PosAlign.center));
      printer.feed(2);
      printer.cut();
      onSuccess?.call('Ticket imprimé');
    } catch (e) {
      // P32/P37: surface instead of swallowing.
      _notifyPrintFailure(e);
    } finally {
      // P33: ALWAYS release the socket — a leaked connection made every
      // later print fail silently.
      if (connected) printer.disconnect();
    }
  }

  static Future<void> printSessionStartTicket(
      GameSession session, ObjectBox objectbox) async {
    final configBox = objectbox.store.box<PrinterConfig>();
    if (configBox.isEmpty()) {
      // P32: no printer configured → tell the owner instead of nothing.
      _notifyPrintFailure(StateError('no_printer_config'));
      return;
    }
    final config = configBox.getAll().first;

    final profile = await CapabilityProfile.load();
    final printer = SafePrinter(PaperSize.mm80, profile);
    var connected = false;

    try {
      final PosPrintResult res =
          await printer.connect(config.ipAddress, port: config.port);
      connected = res == PosPrintResult.success;
      // P37: a failed connection used to `return` silently.
      if (!connected) throw StateError('printer_conn_failed');
      onSuccess?.call('Ticket envoyé — en cours d\'impression…');

      printer.reset();
      printer.text('===== DEBUT PARTIE =====',
          styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      printer.feed(1);

      printer.text('Poste:       ${session.postLabel}',
          styles: const PosStyles(bold: true));
      printer.text('Partie #:    ${session.partyNumber}');
      printer
          .text('Tarif:       ${session.ratePerHour.toStringAsFixed(2)} DH/H');
      printer.feed(1);

      printer.text('Debut:       ${_formatTime(session.startTime)}');

      if (session.isLimitedDuration) {
        printer.text('Duree:       ${session.limitedDurationMinutes} min',
            styles: const PosStyles(bold: true));
        printer.text(
            'Fin prevue:  ${_formatTime(session.startTime.add(Duration(minutes: session.limitedDurationMinutes)))}');
        printer.text(
            'Total Paye:  ${session.currentCalculatedPrice.toStringAsFixed(2)} DH',
            styles: const PosStyles(bold: true));
      }

      printer.feed(1);
      printer.text('Bon jeu !',
          styles: const PosStyles(align: PosAlign.center));
      printer.feed(2);
      printer.cut();
      onSuccess?.call('Ticket imprimé');
    } catch (e) {
      // P32/P37: surface instead of swallowing.
      _notifyPrintFailure(e);
    } finally {
      // P33: ALWAYS release the socket — a leaked connection made every
      // later print fail silently.
      if (connected) printer.disconnect();
    }
  }

  static Future<void> printDayBrief(
      DateTime selectedDay, ObjectBox objectbox, StoreConfig config) async {
    // P32/P37: the connection is INSIDE the try — an unreachable printer
    // used to throw before the catcher and die silently.
    NetworkPrinter? printer;
    try {
      printer = await connectToPrinter(objectbox);
      onSuccess?.call('Rapport envoyé — en cours d\'impression…');

      final range = BusinessDayHelper.getBusinessDayRange(selectedDay, config);
      final orderBox = objectbox.store.box<order_model.Order>();
      final gameSessionBox = objectbox.store.box<GameSession>();

      // P28: end-exclusive — the report must match the dashboard exactly
      // (between() is inclusive and double-counted the boundary instant).
      final orders = orderBox
          .query(ob.Order_.date.between(range.$1.millisecondsSinceEpoch,
              range.$2.millisecondsSinceEpoch - 1))
          .build()
          .find();

      final gameSessions = gameSessionBox
          .query(ob.GameSession_.startTime.between(range.$1.millisecondsSinceEpoch,
              range.$2.millisecondsSinceEpoch - 1))
          .build()
          .find();

      final activeOrders = orders.where((o) => !o.isDeleted).toList();
      final deletedOrders = orders.where((o) => o.isDeleted).toList();

      final pricing = PricingService();
      double totalRevenue = 0;
      int totalItems = 0;
      for (final order in activeOrders) {
        for (final item in order.items) {
          totalItems += item.quantity;
          // P14: the same formula as the dashboard — stored price + extras
          // (the report used to miss every extra's price).
          totalRevenue += pricing.calculateItemTotal(item);
        }
      }

      final activeSessions = gameSessions.where((s) => !s.isCancelled).toList();
      double totalGameRevenue = 0;
      for (final session in activeSessions) {
        // P16: a session already saved as an order is counted with the
        // orders — adding it again inflated TOTAL CA (the dashboard skips
        // linked sessions via relatedOrderId).
        if (session.relatedOrderId != null && session.relatedOrderId != 0) {
          continue;
        }
        totalGameRevenue += session.currentCalculatedPrice;
      }

      final storeConfigBox = objectbox.store.box<StoreConfig>();
      final storeConfig = storeConfigBox.getAll().isNotEmpty
          ? storeConfigBox.getAll().first
          : null;

      final storeName =
          storeConfig?.storeName?.isNotEmpty == true ? storeConfig!.storeName! : 'EASIFY POS';

      printer.reset();

      printer.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      printer.text(
        'RAPPORT JOURNALIER',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );

      printer.feed(1);
      printer.text(
        'Date: ${selectedDay.day}/${selectedDay.month}/${selectedDay.year}',
        styles: const PosStyles(align: PosAlign.center),
      );
      printer.feed(1);

      printer.text('--- COMMANDES ---', styles: const PosStyles(bold: true));
      printer.row([
        PosColumn(text: 'Commandes actives:', width: 8, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: '${activeOrders.length}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      printer.row([
        PosColumn(text: 'Commandes supprimees:', width: 8, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: '${deletedOrders.length}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      printer.row([
        PosColumn(text: 'Articles vendus:', width: 8, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: '$totalItems', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      printer.row([
        PosColumn(text: 'CA Commandes:', width: 8, styles: const PosStyles(align: PosAlign.left, bold: true)),
        PosColumn(text: '${totalRevenue.toStringAsFixed(2)} DH', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      printer.feed(1);
      printer.text('--- JEUX ---', styles: const PosStyles(bold: true));
      printer.row([
        PosColumn(text: 'Sessions actives:', width: 8, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: '${activeSessions.length}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      printer.row([
        PosColumn(text: 'CA Jeux:', width: 8, styles: const PosStyles(align: PosAlign.left, bold: true)),
        PosColumn(text: '${totalGameRevenue.toStringAsFixed(2)} DH', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      printer.feed(1);
      printer.text('--- TOTAL ---', styles: const PosStyles(bold: true));
      printer.row([
        PosColumn(text: 'TOTAL CA:', width: 8, styles: const PosStyles(align: PosAlign.left, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
        PosColumn(text: '${(totalRevenue + totalGameRevenue).toStringAsFixed(2)} DH', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
      ]);

      printer.feed(2);
      printer.text(
        'Genere le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        styles: const PosStyles(align: PosAlign.center),
      );

      printer.feed(2);
      printer.cut(mode: PosCutMode.partial);
      onSuccess?.call('Rapport journalier imprimé');
    } catch (e) {
      // P37: daily-report failures surface too, never vanish.
      _notifyPrintFailure(e);
    } finally {
      printer?.disconnect();
    }
  }
}

/// Replaces every character a thermal printer cannot encode (P31).
/// The printer package encodes text as Latin-1, which THROWS on ✅, €, œ
/// and emojis — killing the test button and dying mid-receipt.
String printableText(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune <= 0xFF) {
      out.writeCharCode(rune);
      continue;
    }
    switch (rune) {
      case 0x2705: // ✅
      case 0x2713: // ✓
      case 0x2714: // ✔
        out.write('OK');
        break;
      case 0x20AC: // €
        out.write('EUR');
        break;
      case 0x0152: // Œ
        out.write('OE');
        break;
      case 0x0153: // œ
        out.write('oe');
        break;
      case 0x2018: // ‘
      case 0x2019: // ’
        out.write("'");
        break;
      case 0x201C: // “
      case 0x201D: // ”
        out.write('"');
        break;
      case 0x2026: // …
        out.write('...');
        break;
      case 0x2013: // –
      case 0x2014: // —
        out.write('-');
        break;
      case 0x2764: // ❤
        out.write('<3');
        break;
      default:
        if (rune < 0x1F000) out.write('?'); // unknown symbol
        // emojis (U+1F000 and up) are dropped quietly
    }
  }
  return out.toString();
}

/// A NetworkPrinter that can never crash on modern characters: every text
/// and table column is scrubbed to printable Latin-1 before it reaches the
/// wire (P31). Construction sites just use this instead of NetworkPrinter.
class SafePrinter extends NetworkPrinter {
  SafePrinter(super.paperSize, super.profile);

  @override
  void text(
    String text, {
    PosStyles styles = const PosStyles(),
    int linesAfter = 0,
    bool containsChinese = false,
    int? maxCharsPerLine,
  }) {
    super.text(
      printableText(text),
      styles: styles,
      linesAfter: linesAfter,
      containsChinese: containsChinese,
      maxCharsPerLine: maxCharsPerLine,
    );
  }

  @override
  void row(List<PosColumn> cols) {
    // PosColumn.text is mutable and each column is built fresh per print —
    // scrub in place, then hand the same list to the printer.
    for (final col in cols) {
      col.text = printableText(col.text);
    }
    super.row(cols);
  }
}
