import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/models/app_user.dart';
import 'package:Easify/models/order.dart' as order_model;
import 'providers/dashboard_provider.dart';
import 'providers/navigation_provider.dart';
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
  static const String orderEdit = '/order/edit/:orderId';

  static String orderEditPath(int orderId) => '/order/edit/$orderId';
}

// ─── Route extras (for passing non-path data) ───────────────────────────────
class OrderRouteExtras {
  final AppUser? assignedUser;
  final String? initialCategory;

  OrderRouteExtras({this.assignedUser, this.initialCategory});
}

// ─── Router builder ──────────────────────────────────────────────────────────
GoRouter createRouter(WidgetRef ref) {
  final objectbox = ref.read(objectBoxProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Erreur')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Page introuvable',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(state.uri.toString(),
                  style: TextStyle(color: Colors.grey[600])),
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
      // Navigation Hub – the home screen
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const NavigationHubScreen(),
      ),

      // Section routes (pushed on top of the hub)
      GoRoute(
        path: AppRoutes.order,
        pageBuilder: (context, state) {
          final extras = state.extra as OrderRouteExtras?;
          return CustomTransitionPage(
            child: OrderScreen(
              objectbox: objectbox,
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
              objectbox: objectbox,
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
              objectbox: objectbox,
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
            child: DashboardScreen(objectbox: objectbox),
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
            child: ManagementScreen(objectbox: objectbox),
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
              objectbox: objectbox,
              onSettingsChanged: () {
                ref.invalidate(showGamesProvider);
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
        path: AppRoutes.orderEdit,
        builder: (context, state) {
          final orderId = int.parse(state.pathParameters['orderId']!);
          final order = objectbox.store.box<order_model.Order>().get(orderId);
          if (order == null) {
            return const Scaffold(
              body: Center(child: Text('Order not found')),
            );
          }
          return OrderScreen(
            objectbox: objectbox,
            orderToEdit: order,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.devPanel,
        builder: (context, state) => DevPanelScreen(objectbox: objectbox),
      ),
    ],
  );
}
