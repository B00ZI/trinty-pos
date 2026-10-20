import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:Easify/objectbox.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'models/order_counter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/providers/dashboard_provider.dart';
import 'models/app_user.dart';
import 'service/error_reporter.dart';
import 'service/history_cleanup_service.dart';
import 'service/notification_service.dart';
import 'service/printer_helper.dart';
import 'service/wifi_password_store.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'widgets/error_boundary.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // P42: nothing fails silently.
  // - FlutterError.onError catches framework errors (build/layout).
  // - PlatformDispatcher.onError catches what escapes async code.
  // - runZonedGuarded below catches the rest inside this zone.
  // All three show a short French message; only debug builds log details (P49).
  final reporter = ErrorReporter(rootMessengerKey);
  FlutterError.onError = (details) => reporter.report(details.exception, details.stack);
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report(error, stack);
    return true; // handled: the app keeps running for the shop
  };

  runZonedGuarded(() async {
    // Initialize Timezone
    tz.initializeTimeZones();

    // Initialize Notifications
    await NotificationService.init();

    final objectbox = await ObjectBox.create();
    final counterBox = objectbox.store.box<OrderCounter>();
    if (counterBox.isEmpty()) {
      counterBox.put(OrderCounter(value: 1));
    }

    // Seed default admin user if no admin exists
    final userBox = objectbox.userBox;
    final allUsers = userBox.getAll();
    final hasAdmin = allUsers.any((u) => u.isAdmin);
    if (!hasAdmin) {
      final (hash, salt) = AppUser.hashPin('0000');
      userBox.put(AppUser(
        name: 'Admin',
        pin: hash,
        pinSalt: salt,
        isAdmin: true,
      ));
    }

    // One-time move of the Wi-Fi password from the database into platform
    // secure storage (Windows DPAPI / Android Keystore) — P07.
    await WifiPasswordStore.migrateFromConfigs(objectbox.storeConfigBox);

    // Quiet automatic cleanup of old history, if the owner enabled it
    // (Settings → Maintenance, PROBLEMS.md P04). Never touches setup data.
    Future.microtask(() async {
      try {
        await HistoryCleanupService(objectbox).runAutoClean();
      } catch (e) {
        if (kDebugMode) debugPrint('Auto-clean failed: $e');
      }
    });

    // P32/P37: any print failure surfaces as a snackbar — a ticket never
    // fails silently behind a button that "does nothing".
    PrinterHelper.onError = (message) => rootMessengerKey.currentState
        ?.showSnackBar(SnackBar(
            content: Text(message), duration: const Duration(seconds: 4)));
    // Success feedback too: "Ticket imprimé" appears when the paper really
    // came out — no more guessing if it worked.
    PrinterHelper.onSuccess = (message) => rootMessengerKey.currentState
        ?.showSnackBar(SnackBar(
            content: Text(message), duration: const Duration(seconds: 2)));

    runApp(
      ProviderScope(
        overrides: [
          objectBoxProvider.overrideWithValue(objectbox),
        ],
        child: Easify(objectbox: objectbox),
      ),
    );
  }, (error, stack) {
    // P42: an async failure (button handler that threw) is reported above —
    // never dropped on the floor.
    reporter.report(error, stack);
  });
}

/// Global key so print errors can reach the screen from any service.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class Easify extends ConsumerStatefulWidget {
  final ObjectBox objectbox;
  const Easify({super.key, required this.objectbox});

  @override
  ConsumerState<Easify> createState() => _EasifyState();
}

class _EasifyState extends ConsumerState<Easify> {
  // P56: the navigation map is built ONCE for the app's whole life.
  // It used to be rebuilt on every root build(), which threw the shop
  // back to the home screen whenever the whole app redrew.
  late final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: rootMessengerKey,
      title: 'Easify',
      // P42: the safety net that was written but never plugged in — any
      // code calling reportError(context, e) now shows the friendly
      // "Réessayer" screen instead of nothing happening.
      builder: (context, child) =>
          ErrorBoundary(label: 'Easify', child: child ?? const SizedBox.shrink()),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      locale: const Locale('fr', 'FR'),
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
