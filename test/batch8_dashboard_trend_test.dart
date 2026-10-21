import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart' as obx;

import 'package:Easify/models/order.dart' as order_model;
import 'package:Easify/models/order_item.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:Easify/widgets/charts.dart';

/// Batch 8 — P25: the dashboard's weekly trend labels used to be hardcoded
/// fiction (`+12.5%`, `+8.4%`, `+18.7%`, always positive) displayed next to
/// real numbers. Now the chip shows the REAL change of these 7 days against
/// the previous 7 — green when up, red when down — and hides itself when the
/// previous week was empty (nothing honest to compare against).
void main() {
  final storeAvailable = Platform.environment['PATH']?.split(';').any(
          (d) => File('$d/objectbox.dll').existsSync()) ??
      false;
  final storeSkip = storeAvailable
      ? null
      : 'objectbox.dll not on PATH — build windows debug and add '
          'build\\windows\\x64\\runner\\Debug to PATH';

  ({obx.Store store, Directory dir}) openStore(String tag) {
    final dir = Directory.systemTemp.createTempSync(tag);
    final store = Store(getObjectBoxModel(), directory: dir.path);
    return (store: store, dir: dir);
  }

  void putOrder(obx.Store store,
      {required int daysAgo, required int quantity, required double price}) {
    final order = order_model.Order(
        date: DateTime.now().subtract(Duration(days: daysAgo)),
        orderNumber: daysAgo * 100 + quantity);
    order.items.add(OrderItem(quantity: quantity, price: price));
    store.box<order_model.Order>().put(order);
  }

  group('P25 — the trend math is real (service rule)', () {
    test('growth is a real percentage', () {
      expect(computeTrendPercent(112.5, 100), closeTo(12.5, 0.0001));
    });

    test('a slow week goes DOWN — sign included', () {
      expect(computeTrendPercent(50, 100), closeTo(-50, 0.0001));
    });

    test('an equal week is exactly zero', () {
      expect(computeTrendPercent(100, 100), 0);
    });

    test('empty previous week = no number invented (null)', () {
      expect(computeTrendPercent(250, 0), isNull,
          reason: 'a first-time week has no trend — the chip must hide, '
              'never invent a percentage');
      expect(computeTrendPercent(0, 0), isNull);
    });
  });

  group('P25 — on the real dashboard chart', () {
    Future<void> pumpChart(WidgetTester tester, obx.Store store) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
                height: 1200, child: WeeklyPerformanceChart(store: store)),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a week half as good as the last shows −50.0 %, not +12.5 %',
        (tester) async {
      final s = openStore('easify_b8_down');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      // This week: one order of 20 DH (yesterday).
      putOrder(s.store, daysAgo: 1, quantity: 2, price: 10);
      // Previous week: one order of 40 DH (8 days ago).
      putOrder(s.store, daysAgo: 8, quantity: 4, price: 10);

      await pumpChart(tester, s.store);

      // Revenue and profit (no expenses → same number) both fell by half.
      expect(find.text('-50.0 %'), findsNWidgets(2));
      // Orders: 1 vs 1 = a real 0.0 % (not the old fake +8.4 %).
      expect(find.text('+0.0 %'), findsOneWidget);
      // The old fiction is gone for good.
      expect(find.text('+ 12.5%'), findsNothing);
      expect(find.text('+ 8.4%'), findsNothing);
      expect(find.text('+ 18.7%'), findsNothing);
    }, skip: storeSkip != null);

    testWidgets('a brand-new week shows totals without inventing a trend',
        (tester) async {
      final s = openStore('easify_b8_first');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      // Only current-week sales: nothing to compare against.
      putOrder(s.store, daysAgo: 2, quantity: 3, price: 10);

      await pumpChart(tester, s.store);

      expect(find.text('30.00 DH'), findsNWidgets(2),
          reason: 'the real totals must still show (revenue + profit — no '
              'expenses, so both equal 30.00)');
      expect(find.textContaining('%'), findsNothing,
          reason: 'no previous week = no trend chip at all');
    }, skip: storeSkip != null);
  });
}
