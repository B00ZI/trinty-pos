import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:Easify/objectbox.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'models/order_counter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/providers/dashboard_provider.dart';
import 'models/app_user.dart';
import 'service/notification_service.dart';
import 'router.dart';

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
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF2D7DD2),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF2D7DD2),
          onSecondary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFEDF5FC),
          onPrimaryContainer: Color(0xFF210124),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF210124),
          surfaceContainer: Color(0xFFEDF5FC),
          error: Color(0xFFD32F2F),
          onError: Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF210124),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF2D7DD2)),
          titleTextStyle: TextStyle(
            color: Color(0xFF210124),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFEDF5FC),
          elevation: 0,
          shadowColor: const Color(0xFF2D7DD2).withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide.none,
          ),
          margin: const EdgeInsets.all(8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D7DD2),
            foregroundColor: const Color(0xFFFFFFFF),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2D7DD2),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFEDF5FC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2D7DD2), width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF210124)),
          hintStyle:
              TextStyle(color: const Color(0xFF210124).withValues(alpha: 0.5)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFF2D7DD2),
          unselectedItemColor: Color(0xFF210124),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          showUnselectedLabels: true,
        ),
        textTheme: const TextTheme(
          headlineLarge:
              TextStyle(color: Color(0xFF210124), fontWeight: FontWeight.bold),
          titleLarge:
              TextStyle(color: Color(0xFF210124), fontWeight: FontWeight.bold),
          titleMedium:
              TextStyle(color: Color(0xFF210124), fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: Color(0xFF210124)),
          bodyMedium: TextStyle(color: Color(0xFF210124)),
          bodySmall: TextStyle(color: Color(0xFF210124)),
        ),
      ),
      routerConfig: router,
    );
  }
}
