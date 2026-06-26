import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Easify/models/order.dart' as order_model;
import 'package:Easify/models/app_user.dart';
import 'package:Easify/models/game_session.dart';
import 'package:Easify/models/order_item.dart';
import 'package:Easify/models/expense.dart';
import 'package:Easify/models/daily_funds.dart';
import 'package:Easify/models/order_counter.dart';
import '../providers/dashboard_provider.dart';
import '../router.dart';
import '../service/activation_service.dart';
import '../service/auth_service.dart';
import '../widgets/activation_dialog.dart';
import '../widgets/user_selection_dialog.dart';
import '../widgets/admin_pin_dialog.dart';

class NavigationHubScreen extends ConsumerStatefulWidget {
  const NavigationHubScreen({super.key});

  @override
  ConsumerState<NavigationHubScreen> createState() =>
      _NavigationHubScreenState();
}

class _NavigationHubScreenState extends ConsumerState<NavigationHubScreen> {
  bool _showGames = false;
  bool _isLoading = true;
  bool _isCheckingActivation = true;
  AppUser? _selectedUser;
  DateTime? _lastTitleTap;
  int _titleTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkActivation();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showGames = prefs.getBool('show_games_tab') ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkActivation() async {
    final activated = await ActivationService.isActivated();
    if (mounted) {
      setState(() => _isCheckingActivation = false);
      if (!activated) {
        await _showActivationDialog();
      }
      _checkSessionAuth();
    }
  }

  Future<void> _checkSessionAuth() async {
    final mode = await AuthService.getAuthMode();
    if (mode == AuthMode.session && mounted) {
      _showUserSelectionFlow(isCancelable: false);
    }
  }

  Future<void> _showActivationDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ActivationDialog(
        onActivated: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _showUserSelectionFlow({bool isCancelable = true}) async {
    final objectbox = ref.read(objectBoxProvider);
    final selected = await showDialog<AppUser>(
      context: context,
      barrierDismissible: isCancelable,
      builder: (context) => UserSelectionDialog(
        objectbox: objectbox,
        isCancelable: isCancelable,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedUser = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connecté en tant que : ${selected.name}')),
      );
    }
  }

  void _onTitleTap() {
    final now = DateTime.now();
    if (_lastTitleTap != null &&
        now.difference(_lastTitleTap!) < const Duration(milliseconds: 600)) {
      _titleTapCount++;
    } else {
      _titleTapCount = 1;
    }
    _lastTitleTap = now;

    if (_titleTapCount >= 5) {
      _titleTapCount = 0;
      context.push(AppRoutes.devPanel);
    }
  }

  void _navigateTo(String path) async {
    // Dashboard admin check
    if (path == AppRoutes.dashboard) {
      final objectbox = ref.read(objectBoxProvider);
      final isAdmin = await AdminPinDialog.verify(context, objectbox);
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Accès au Dashboard restreint aux administrateurs')),
          );
        }
        return;
      }
    }

    if (mounted) {
      // Pass the selected user to routes that need it
      if (_selectedUser != null &&
          (path == AppRoutes.order ||
              path == AppRoutes.games ||
              path == AppRoutes.history)) {
        context.push(path,
            extra: OrderRouteExtras(assignedUser: _selectedUser));
      } else {
        context.push(path);
      }
    }
  }

  void _promptWipeAllOrders() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ ATTENTION ⚠️',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
            'Voulez-vous vraiment supprimer TOUTES les données (Commandes, Sessions de jeux, Dépenses) et repartir à zéro ?\n\nCette action est IRRÉVERSIBLE.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SUPPRIMER TOUT',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final objectbox = ref.read(objectBoxProvider);
      final store = objectbox.store;
      store.box<order_model.Order>().removeAll();
      store.box<OrderItem>().removeAll();
      store.box<GameSession>().removeAll();
      store.box<Expense>().removeAll();
      store.box<DailyFunds>().removeAll();
      final orderCounterBox = store.box<OrderCounter>();
      orderCounterBox.removeAll();
      orderCounterBox.put(OrderCounter(id: 1, value: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Toutes les données ont été supprimées.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingActivation || _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: Text(
            _selectedUser != null
                ? 'Easify - ${_selectedUser!.name}'
                : 'Easify',
          ),
        ),
        actions: [
          if (_selectedUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showUserSelectionFlow(),
              tooltip: "Changer d'utilisateur",
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Navigation',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Sélectionnez une section',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive: 2 columns on narrow, 3 on wide
                  final crossCount = constraints.maxWidth > 600 ? 3 : 2;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _HubCard(
                          icon: Icons.shopping_cart,
                          title: 'Commande',
                          subtitle: 'Créer une nouvelle commande',
                          color: colorScheme.primary,
                          onTap: () => _navigateTo(AppRoutes.order),
                        ),
                        _HubCard(
                          icon: Icons.history,
                          title: 'Historique',
                          subtitle: 'Voir les commandes passées',
                          color: const Color(0xFF5B8DEF),
                          onTap: () => _navigateTo(AppRoutes.history),
                          onLongPress: _promptWipeAllOrders,
                        ),
                        if (_showGames)
                          _HubCard(
                            icon: Icons.sports_esports,
                            title: 'Jeux',
                            subtitle: 'Sessions de jeux en cours',
                            color: const Color(0xFF7C4DFF),
                            onTap: () => _navigateTo(AppRoutes.games),
                          ),
                        _HubCard(
                          icon: Icons.dashboard,
                          title: 'Dashboard',
                          subtitle: 'Statistiques et métriques',
                          color: const Color(0xFF00BFA5),
                          onTap: () => _navigateTo(AppRoutes.dashboard),
                        ),
                        _HubCard(
                          icon: Icons.inventory_2,
                          title: 'Gestion',
                          subtitle: 'Produits, catégories, dépenses',
                          color: const Color(0xFFFF6D00),
                          onTap: () => _navigateTo(AppRoutes.management),
                        ),
                        _HubCard(
                          icon: Icons.settings,
                          title: 'Paramètres',
                          subtitle: 'Configuration du magasin',
                          color: const Color(0xFF78909C),
                          onTap: () => _navigateTo(AppRoutes.settings),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF210124),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF210124).withValues(alpha: 0.55),
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
