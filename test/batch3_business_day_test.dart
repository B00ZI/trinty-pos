import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Easify/models/daily_funds.dart';
import 'package:Easify/models/order.dart' as order_model;
import 'package:Easify/models/store_config.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:Easify/service/business_day_helper.dart';

/// Batch 3 — P19/P27/P28: ONE clock for the whole app.
///
/// P27: the reset is calculated from the owner's usual hours (middle of
/// the closed gap). P19: every screen uses that one boundary. P28: a
/// record landing exactly on the boundary counts in exactly ONE day.
///
/// The real-store group needs `objectbox.dll` discoverable (it ships
/// with the debug build): run `flutter build windows --debug` once and
/// add `build\windows\x64\runner\Debug` to PATH before `flutter test`.
/// Without it the group skips instead of failing.
void main() {
  final storeAvailable = Platform.environment['PATH']?.split(';').any(
          (d) => File('$d/objectbox.dll').existsSync()) ??
      false;
  final storeSkip = storeAvailable
      ? null
      : 'objectbox.dll not on PATH — build windows debug and add '
          'build\\windows\\x64\\runner\\Debug to PATH';
  group('P27 — reset calculated from the owner\'s usual hours', () {
    test('café 16:00→23:00 resets at 07:30', () {
      final r = BusinessDayHelper.resetFromHours(
          openHour: 16, openMinute: 0, closeHour: 23, closeMinute: 0);
      expect(r, (7, 30));
    });

    test('bar 22:00→04:00 resets at 13:00 (whole night = one day)', () {
      final r = BusinessDayHelper.resetFromHours(
          openHour: 22, openMinute: 0, closeHour: 4, closeMinute: 0);
      expect(r, (13, 0));
    });

    test('shop 10:00→19:00 resets at 02:30', () {
      final r = BusinessDayHelper.resetFromHours(
          openHour: 10, openMinute: 0, closeHour: 19, closeMinute: 0);
      expect(r, (2, 30));
    });

    test('open 01:00→23:00 (only 2h closed) resets at midnight', () {
      final r = BusinessDayHelper.resetFromHours(
          openHour: 1, openMinute: 0, closeHour: 23, closeMinute: 0);
      expect(r, (0, 0));
    });

    test('open == close (no closed gap) falls back to midnight', () {
      final r = BusinessDayHelper.resetFromHours(
          openHour: 8, openMinute: 0, closeHour: 8, closeMinute: 0);
      expect(r, (0, 0));
    });

    test('random openings still land in ONE day (the owner\'s worry)', () {
      // Owner answers 16:00→23:00 → reset 07:30. One day he opens at
      // 14:00 (2h early), another at 20:00 (4h late): both whole.
      final cfg = StoreConfig(dayStartHour: 7, dayStartMinute: 30);
      final early = DateTime(2026, 10, 19, 14, 0);
      final late = DateTime(2026, 10, 20, 20, 0);
      expect(BusinessDayHelper.getBusinessDayDate(early, cfg),
          DateTime(2026, 10, 19));
      expect(BusinessDayHelper.getBusinessDayDate(late, cfg),
          DateTime(2026, 10, 20));
    });
  });

  group('P19/P28 — business day math', () {
    final cfg = StoreConfig(dayStartHour: 7, dayStartMinute: 30);

    test('range = boundary → +24h', () {
      final range =
          BusinessDayHelper.getBusinessDayRange(DateTime(2026, 10, 19), cfg);
      expect(range.$1, DateTime(2026, 10, 19, 7, 30));
      expect(range.$2, DateTime(2026, 10, 20, 7, 30));
    });

    test('a moment before the reset = previous business day', () {
      expect(
          BusinessDayHelper.getBusinessDayDate(
              DateTime(2026, 10, 20, 7, 29, 59, 999), cfg),
          DateTime(2026, 10, 19));
    });

    test('the reset instant itself opens the new business day', () {
      expect(BusinessDayHelper.getBusinessDayDate(DateTime(2026, 10, 20, 7, 30), cfg),
          DateTime(2026, 10, 20));
    });

    test('getBusinessDayDate always returns midnight (both branches)', () {
      expect(BusinessDayHelper.getBusinessDayDate(DateTime(2026, 10, 20, 7, 29), cfg).hour, 0);
      expect(BusinessDayHelper.getBusinessDayDate(DateTime(2026, 10, 20, 9, 0), cfg).hour, 0);
    });

    test('default config (00:00) behaves exactly like a calendar day', () {
      final def = StoreConfig();
      expect(
          BusinessDayHelper.getBusinessDayDate(DateTime(2026, 10, 20, 3, 0), def),
          DateTime(2026, 10, 20));
      final range =
          BusinessDayHelper.getBusinessDayRange(DateTime(2026, 10, 19), def);
      expect(range.$1, DateTime(2026, 10, 19));
      expect(range.$2, DateTime(2026, 10, 20));
    });
  });

  group('P19/P28 — real store: boundary records count in exactly ONE day',
      () {
    late Store store;
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('easify_b3');
      store = Store(getObjectBoxModel(), directory: tmpDir.path);
    });

    tearDown(() {
      store.close();
      tmpDir.deleteSync(recursive: true);
    });

    test('order on the exact boundary: next day only, last ms kept (P28)',
        () {
      final box = store.box<order_model.Order>();
      final start = DateTime(2026, 10, 20, 7, 30);
      final end = start.add(const Duration(hours: 24));

      box.put(order_model.Order(
          orderNumber: 1,
          date: end.subtract(const Duration(milliseconds: 1))));
      box.put(order_model.Order(orderNumber: 2, date: end)); // the boundary
      box.put(order_model.Order(
          orderNumber: 3, date: end.add(const Duration(milliseconds: 1))));

      // The repository rule (between is inclusive → query end − 1ms).
      List<int> dayQuery(DateTime s, DateTime e) {
        final q = box
            .query(Order_.date.between(
                s.millisecondsSinceEpoch, e.millisecondsSinceEpoch - 1))
            .build();
        final ids = q.find().map((o) => o.orderNumber).toList();
        q.close();
        return ids;
      }

      final day1 = dayQuery(start, end);
      final day2 = dayQuery(end, end.add(const Duration(hours: 24)));

      expect(day1, [1],
          reason: 'the last millisecond of the day is NOT lost '
              '(the old dashboard cut the whole last second)');
      expect(day2, [2, 3],
          reason: 'the boundary instant belongs to the NEXT day only — '
              'never counted twice');
    });

    test('funds float belongs to the business day and carries over (P19)',
        () {
      final fundsBox = store.box<DailyFunds>();
      final cfg = StoreConfig(dayStartHour: 7, dayStartMinute: 30);

      // Café owner sets the float at 20:00 (evening) — it belongs to
      // TODAY's business day, exactly like every other screen shows.
      final evening = DateTime(2026, 10, 20, 20, 0);
      final businessDate = BusinessDayHelper.getBusinessDayDate(evening, cfg);
      expect(businessDate, DateTime(2026, 10, 20));
      fundsBox.put(DailyFunds(date: businessDate, amount: 300));

      // Calendar midnight passed (00:10) but the 07:30 reset hasn't —
      // same business day: the float is found, NO re-prompt.
      final afterMidnight =
          BusinessDayHelper.getBusinessDayDate(DateTime(2026, 10, 21, 0, 10), cfg);
      expect(afterMidnight, DateTime(2026, 10, 20));
      final q = fundsBox
          .query(DailyFunds_.date.between(afterMidnight.millisecondsSinceEpoch,
              afterMidnight.add(const Duration(days: 1)).millisecondsSinceEpoch - 1))
          .build();
      expect(q.find().single.amount, 300);
      q.close();

      // After the reset (08:00): new business day, no record yet → the
      // drawer cash carries over from the latest record (repo fallback).
      final newDay =
          BusinessDayHelper.getBusinessDayDate(DateTime(2026, 10, 21, 8, 0), cfg);
      expect(newDay, DateTime(2026, 10, 21));
      final latest = fundsBox.query().order(DailyFunds_.date, flags: Order.descending).build();
      expect(latest.findFirst()!.amount, 300,
          reason: 'carry-over fallback, business-day aware');
      latest.close();
    });
  }, skip: storeSkip);
}
