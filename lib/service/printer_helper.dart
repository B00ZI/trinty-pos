import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/store_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../models/printer_config.dart';
import 'package:Easify/objectbox.dart';
import '../models/order.dart' show Ruci;
import '../models/game_session.dart';
import 'image_generatore.dart';
import 'package:intl/intl.dart';

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

  static ReceiptData convertRuciToReceiptData(Ruci order) {
    return ReceiptData(
      id: order.id.toString(),
      dailyNumber: order.orderNumber.toString(),
      createdAt: order.date.toIso8601String(),
      total: order.items
          .fold<double>(
            0,
            (sum, item) =>
                sum + (item.quantity * (item.product.target?.price ?? 0)),
          )
          .toStringAsFixed(2),
      items: order.items.map((item) {
        return ReceiptItem(
          id: item.id.toString(),
          title: item.product.target?.name ?? 'Unknown Product',
          quantity: item.quantity,
          price: item.product.target?.price ?? 0.0,
        );
      }).toList(),
      paymentMethod: 'cash', // Add a default payment method if needed
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
  static Future<NetworkPrinter> connectToPrinter(ObjectBox objectbox) async {
    final printerConfigBox = objectbox.store.box<PrinterConfig>();
    final printerConfig = printerConfigBox.getAll().first;
    // final ipAddress = prefs.getString('printer_ip') ?? '';
    // final port = prefs.getInt('printer_port') ?? 9100;

    if (printerConfig.ipAddress.isEmpty) {
      throw Exception('Printer IP address not configured');
    }

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final PosPrintResult result = await printer.connect(printerConfig.ipAddress,
        port: printerConfig.port);

    if (result != PosPrintResult.success) {
      throw Exception('Failed to connect to printer: $result');
    }

    return printer;
  }

  static Future<void> printReceipt(ReceiptData receipt, ObjectBox objectbox,
      {String comment = "", bool isTakeAway = false}) async {
    final printer = await connectToPrinter(objectbox);

    try {
      final storeConfigBox = objectbox.store.box<StoreConfig>();
      final storeConfig = storeConfigBox.getAll().isNotEmpty
          ? storeConfigBox.getAll().first
          : null;

      printer.reset();
      await _printHeader(printer, receipt, storeConfig, comment);

      // Debug: Check items before printing
      debugPrint('Items to print: ${receipt.items}');

      _printItems(printer, receipt.items);
      _printTotals(printer, receipt, isTakeAway, storeConfig);
      _printFooter(printer, receipt);

      printer.cut(mode: PosCutMode.partial);
    } finally {
      printer.disconnect();
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

      if (imgBytes == null) return;

      // Decode the image
      final img.Image? image = img.decodeImage(imgBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize (thermal printers work best at 200–250px width)
      final img.Image resized = img.copyResize(image, width: 200);

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

  static void _printTotals(
      NetworkPrinter printer, ReceiptData receipt, bool isTakeAway, StoreConfig? config) {

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

    if (config?.wifiPassword?.isNotEmpty == true) {
      printer.text(
        'WIFI: ${config!.wifiPassword!}',
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
    final printer = await connectToPrinter(objectBox);

    // Fetch store config
    final storeConfigBox = objectBox.store.box<StoreConfig>();
    final storeConfig = storeConfigBox.getAll().isNotEmpty
        ? storeConfigBox.getAll().first
        : null;
    final storeName = storeConfig?.storeName?.isNotEmpty == true
        ? storeConfig!.storeName!
        : 'Easify POS System';

    try {
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
    } finally {
      printer.disconnect();
    }
  }

  static Future<void> printStoreConfig(ObjectBox objectbox) async {
    final printer = await connectToPrinter(objectbox);

    try {
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
    } finally {
      printer.disconnect();
    }
  }

  static String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static Future<void> printGameTicket(
      GameSession session, ObjectBox objectbox) async {
    final printerConfigBox = objectbox.store.box<PrinterConfig>();
    final configs = printerConfigBox.getAll();
    if (configs.isEmpty) return;
    final config = configs.first;

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    try {
      final PosPrintResult res =
          await printer.connect(config.ipAddress, port: config.port);
      if (res != PosPrintResult.success) return;

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
      printer.text('Tarif:       ${session.ratePerHour.toStringAsFixed(2)} DH/H');
      printer.feed(1);

      printer.text('Debut:       ${_formatTime(session.startTime)}');
      final end = session.endTime ?? DateTime.now();
      final duration = end.difference(session.startTime);
      final minutes = duration.inMinutes;
      
      printer.text('Fin:         ${_formatTime(end)}');
      printer.text('Temps:       ${minutes} min', styles: const PosStyles(bold: true));
      printer.text('Total:       ${session.currentCalculatedPrice.toStringAsFixed(2)} DH', styles: const PosStyles(bold: true));

      printer.feed(1);
      printer.text('Merci de votre visite !',
          styles: const PosStyles(align: PosAlign.center));
      printer.feed(2);
      printer.cut();
      printer.disconnect();
    } catch (e) {
      debugPrint('Printing error: $e');
    }
  }

  static Future<void> printSessionStartTicket(GameSession session, ObjectBox objectbox) async {
    final configBox = objectbox.store.box<PrinterConfig>();
    if (configBox.isEmpty()) return;
    final config = configBox.getAll().first;

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    try {
      final PosPrintResult res =
          await printer.connect(config.ipAddress, port: config.port);
      if (res != PosPrintResult.success) return;

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
      printer.text('Tarif:       ${session.ratePerHour.toStringAsFixed(2)} DH/H');
      printer.feed(1);

      printer.text('Debut:       ${_formatTime(session.startTime)}');
      
      if (session.isLimitedDuration) {
        printer.text('Duree:       ${session.limitedDurationMinutes} min', styles: const PosStyles(bold: true));
        printer.text('Fin prevue:  ${_formatTime(session.startTime.add(Duration(minutes: session.limitedDurationMinutes)))}');
        printer.text('Total Paye:  ${session.currentCalculatedPrice.toStringAsFixed(2)} DH', styles: const PosStyles(bold: true));
      }

      printer.feed(1);
      printer.text('Bon jeu !',
          styles: const PosStyles(align: PosAlign.center));
      printer.feed(2);
      printer.cut();
      printer.disconnect();
    } catch (e) {
      debugPrint('Printing error: $e');
    }
  }
}
