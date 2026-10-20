import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Easify/service/auth_service.dart';
import 'package:Easify/service/error_reporter.dart';

/// Batch 5 — the two behaviour-visible fixes:
///
/// P47 — "PIN par commande" used to forget itself: the settings screen saved
/// `per_order`, but AuthService.setAuthMode wrote `perOrder` while reading
/// only `per_order`, so a saved mode came back as OFF. Writing and reading
/// now share ONE spelling.
///
/// P42 — nothing fails silently: any uncaught error shows a short French
/// message on the shop screen, rate-limited so a failing loop cannot flood.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P47 — the PIN mode keeps what the owner chose', () {
    test('setAuthMode(perOrder) is read back as perOrder (round trip)',
        () async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.setAuthMode(AuthMode.perOrder);
      expect(await AuthService.getAuthMode(), AuthMode.perOrder);
    });

    test("the old 'perOrder' spelling still reads as perOrder", () async {
      SharedPreferences.setMockInitialValues({'auth_mode': 'perOrder'});
      expect(await AuthService.getAuthMode(), AuthMode.perOrder);
    });

    test('session and off round trip too', () async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.setAuthMode(AuthMode.session);
      expect(await AuthService.getAuthMode(), AuthMode.session);
      await AuthService.setAuthMode(AuthMode.off);
      expect(await AuthService.getAuthMode(), AuthMode.off);
    });

    test("the stored value is the one the settings screen writes ('per_order')",
        () async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.setAuthMode(AuthMode.perOrder);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_mode'), 'per_order');
    });

    test('an unknown/empty setting reads as off (never a crash)', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AuthService.getAuthMode(), AuthMode.off);
    });
  });

  group('P42 — an error is shown, in French, and cannot flood', () {
    testWidgets('report() puts the message on the shop screen', (tester) async {
      final key = GlobalKey<ScaffoldMessengerState>();
      final reporter = ErrorReporter(key);
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: key,
        home: const Scaffold(body: Text('café')),
      ));

      final shown = reporter.report(StateError('boom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(shown, isTrue);
      expect(find.text('Une erreur est survenue — réessayez'), findsOneWidget);
    });

    testWidgets('an error loop is swallowed by the rate limit', (tester) async {
      final key = GlobalKey<ScaffoldMessengerState>();
      final reporter = ErrorReporter(key);
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: key,
        home: const Scaffold(body: Text('café')),
      ));

      expect(reporter.report(StateError('boom')), isTrue);
      await tester.pump();
      // Same moment, second failure: swallowed — the screen shows ONE message.
      expect(reporter.report(StateError('boom again')), isFalse);
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('Une erreur est survenue — réessayez'), findsOneWidget);
    });
  });
}
