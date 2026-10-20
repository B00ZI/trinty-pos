import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:Easify/models/store_config.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:Easify/providers/dashboard_provider.dart'
    show objectBoxProvider;
import 'package:Easify/screens/history_screen.dart';
import 'package:Easify/service/business_day_helper.dart';

/// P63 — Histoire must never sit on a stale day (owner: "yes, it should").
///
/// Rule: opening the Histoire screen lands on TODAY's business day; ← →
/// browsing works normally while you stay on it; coming back to it (reopened
/// from the hub, or an older instance in the stack brought back by ← after
/// editing an order) snaps back to today. There is also an "Aujourd'hui"
/// button whenever the displayed day is not today, so browsing is never a
/// trap.
///
/// Real-store test: needs `objectbox.dll` discoverable (it ships with the
/// debug build): run `flutter build windows --debug` once and add
/// `build\windows\x64\runner\Debug` to PATH before `flutter test`.
/// Without it the tests skip instead of failing.
void main() {
  final storeAvailable = Platform.environment['PATH']?.split(';').any(
          (d) => File('$d/objectbox.dll').existsSync()) ??
      false;
  final storeSkip = storeAvailable
      ? null
      : 'objectbox.dll not on PATH — build windows debug and add '
          'build\\windows\\x64\\runner\\Debug to PATH';

  final today = DateTime.now();
  final config = StoreConfig();
  final String todayLabel = DateFormat('dd/MM/yyyy')
      .format(BusinessDayHelper.getBusinessDayDate(today, config));
  final String yesterdayLabel = DateFormat('dd/MM/yyyy').format(
      BusinessDayHelper.getBusinessDayDate(today, config)
          .subtract(const Duration(days: 1)));

  Future<({GlobalKey<NavigatorState> nav})> pumpHistory(
      WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('easify_p63');
    final store = Store(getObjectBoxModel(), directory: dir.path);
    final objectbox = ObjectBox.attach(store);
    addTearDown(() {
      store.close();
      dir.deleteSync(recursive: true);
    });

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [objectBoxProvider.overrideWithValue(objectbox)],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
                child: const Text('open-history'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open-history'));
    await tester.pumpAndSettle();
    return (nav: navigatorKey);
  }

  testWidgets(
      'P63 — opens on today, browses with ←, snaps back to today when '
      'covered and reopened', (tester) async {
    final h = await pumpHistory(tester);

    // 1. Opening lands on today's business day.
    expect(find.text(todayLabel), findsOneWidget);

    // 2. Browsing one day back with ← works while the screen stays in front.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text(yesterdayLabel), findsOneWidget);
    expect(find.text(todayLabel), findsNothing);
    expect(find.text("Aujourd'hui"), findsOneWidget,
        reason: 'the way back must be visible while browsing');

    // 3. Another route covers Histoire (e.g. Modifier an order on top)…
    h.nav.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('somewhere else'))));
    await tester.pumpAndSettle();
    expect(find.text(yesterdayLabel), findsNothing);

    // …and coming back snaps to today instead of keeping the stale day.
    h.nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text(todayLabel), findsOneWidget);
    expect(find.text("Aujourd'hui"), findsNothing);
  }, skip: storeSkip != null);

  testWidgets('P63 — the "Aujourd\'hui" button jumps back in one tap',
      (tester) async {
    await pumpHistory(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text(todayLabel), findsNothing);

    await tester.tap(find.text("Aujourd'hui"));
    await tester.pumpAndSettle();
    expect(find.text(todayLabel), findsOneWidget);
    expect(find.text("Aujourd'hui"), findsNothing);
  }, skip: storeSkip != null);
}
