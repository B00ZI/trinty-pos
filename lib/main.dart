import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:Easify/objectbox.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'models/order_counter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/providers/dashboard_provider.dart';
import 'models/app_user.dart';
import 'service/history_cleanup_service.dart';
import 'service/notification_service.dart';
import 'router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Quiet automatic cleanup of old history, if the owner enabled it
  // (Settings → Maintenance, PROBLEMS.md P04). Never touches setup data.
  Future.microtask(() async {
    try {
      await HistoryCleanupService(objectbox).runAutoClean();
    } catch (e) {
      debugPrint('Auto-clean failed: $e');
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        objectBoxProvider.overrideWithValue(objectbox),
      ],
      child: Easify(objectbox: objectbox),
    ),
  );
}

class Easify extends ConsumerWidget {
  final ObjectBox objectbox;
  const Easify({super.key, required this.objectbox});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = createRouter(ref);

    return MaterialApp.router(
      title: 'Easify',
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
      routerConfig: router,
    );
  }
}
