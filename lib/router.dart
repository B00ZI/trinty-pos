import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/models/app_user.dart';
import 'theme/app_colors.dart';
import 'screens/order_screen.dart';
import 'screens/history_screen.dart';
import 'screens/games_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/management_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/dev_panel_screen.dart';
import 'screens/navigation_hub_screen.dart';

// ─── Route paths ─────────────────────────────────────────────────────────────
class AppRoutes {
  static const String home = '/';
  static const String order = '/order';
  static const String history = '/history';
  static const String games = '/games';
  static const String dashboard = '/dashboard';
  static const String management = '/management';
  static const String settings = '/settings';
  static const String devPanel = '/dev-panel';
}

// ─── Route extras (for passing non-path data) ───────────────────────────────
class OrderRouteExtras {
  final AppUser? assignedUser;
  final String? initialCategory;

  OrderRouteExtras({this.assignedUser, this.initialCategory});
}

// ─── Router builder ──────────────────────────────────────────────────────────
GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    // P49: GoRouter traces exist in debug builds only — a tablet in the
    // café must not log every navigation to the console.
    debugLogDiagnostics: kDebugMode,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Erreur')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              const Text('Page introuvable',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(state.uri.toString(),
                  style: TextStyle(color: AppColors.ink3)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.home),
                label: const Text("Retour à l'accueil"),
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      // Navigation Hub – the default home screen
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const NavigationHubScreen(),
      ),

      // Section routes
      GoRoute(
        path: AppRoutes.order,
        pageBuilder: (context, state) {
          final extras = state.extra as OrderRouteExtras?;
          return CustomTransitionPage(
            child: OrderScreen(
              assignedUser: extras?.assignedUser,
              initialCategory: extras?.initialCategory,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.history,
        pageBuilder: (context, state) {
          final extras = state.extra as OrderRouteExtras?;
          return CustomTransitionPage(
            child: HistoryScreen(
              currentUser: extras?.assignedUser,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.games,
        pageBuilder: (context, state) {
          final extras = state.extra as OrderRouteExtras?;
          return CustomTransitionPage(
            child: GamesScreen(
              assignedUser: extras?.assignedUser,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            child: const DashboardScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.management,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            child: const ManagementScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            child: SettingsScreen(
              onSettingsChanged: () {
                //this line is bugging the hubscreen
                // ref.invalidate(showGamesProvider);
              },
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),

      // Standalone routes
      GoRoute(
        path: AppRoutes.devPanel,
        builder: (context, state) => const DevPanelScreen(),
      ),
    ],
  );
}
