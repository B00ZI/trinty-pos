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
import 'image_generatore.dart'; // Import ImageGenerator

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
      total: order.items.fold<double>(
        0,
        (sum, item) => sum + (item.quantity * (item.product.target?.price ?? 0)),
      ).toStringAsFixed(2),
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

  ReceiptItem({
    required this.id,
    required this.title,
    required this.quantity,
    required this.price,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
    );
  }

  double get total => quantity * price;
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

  static Future<void> printReceipt( ReceiptData receipt, ObjectBox objectbox, {String comment=" Thank you for your order! Come Again!", bool isTakeAway = false}) async {

    final printer = await connectToPrinter(objectbox);

    try {
      final storeConfigBox = objectbox.store.box<StoreConfig>();
      final storeConfig = storeConfigBox.getAll().isNotEmpty 
          ? storeConfigBox.getAll().first 
          : null;

      printer.reset();
      await _printHeader(printer, receipt, storeConfig);

      // Debug: Check items before printing
      debugPrint('Items to print: ${receipt.items}');

      _printItems(printer, receipt.items);
      _printTotals(printer, receipt , isTakeAway);
      _printFooter(printer, receipt, comment);
      printer.cut(mode: PosCutMode.partial);
    } finally {
      printer.disconnect();
    }
  }

  static Future<void> _printHeader(
    NetworkPrinter printer,
    ReceiptData receipt,
    StoreConfig? config,
  ) async {
    await _printLogoImage(printer, config?.storeLogoPath);

    final storeName = config?.storeName?.isNotEmpty == true 
        ? config!.storeName! 
        : 'FRITA';

    printer.text(
      storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
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

  static Future<void> _printLogoImage(NetworkPrinter printer, String? logoPath) async {
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
    }

    printer.hr();
  }

  static void _printTotals(NetworkPrinter printer, ReceiptData receipt, bool isTakeAway) {
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

    printer.text(
      'Payment: ${_formatPaymentMethod(receipt.paymentMethod)}',
      styles: const PosStyles(align: PosAlign.left, bold: true),
    );
  }

  static void _printFooter(NetworkPrinter printer, ReceiptData receipt, String comment) {
   

    printer.feed(2);
    if(comment=="" || comment.isEmpty){
      printer.text(
    "Thank you for your order! Come Again!", 
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      printer.feed(2);
    }
    printer.text(
        comment,
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

  static Future<void> simpleTestPrint(String ipAddress, int port) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);
    final result = await printer.connect(ipAddress, port: port);

    if (result == PosPrintResult.success) {
      try {
        printer.text('Test Print\n\n\n');
        printer.feed(2);
        printer.cut(mode: PosCutMode.partial);
      } finally {
        printer.disconnect();
      }
    } else {
      throw Exception('Failed to connect: $result');
    }
  }

  static Future<bool> isPrinterConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    final ipAddress = prefs.getString('printer_ip') ?? '';
    return ipAddress.isNotEmpty;
  }
}
