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
import '../providers/navigation_provider.dart';
import '../router.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
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
  bool _isLoading = true;
  bool _isCheckingActivation = true;
  AppUser? _selectedUser;
  DateTime? _lastTitleTap;
  int _titleTapCount = 0;

  @override
  void initState() {
    super.initState();
    _initShowGames();
    _checkActivation();
  }

  Future<void> _initShowGames() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('show_games_tab') ?? false;
    ref.read(showGamesProvider.notifier).state = saved;
    if (mounted) {
      setState(() => _isLoading = false);
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
        title: Text('⚠️ ATTENTION ⚠️',
            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
        content: const Text(
            'Voulez-vous vraiment supprimer TOUTES les données (Commandes, Sessions de jeux, Dépenses) et repartir à zéro ?\n\nCette action est IRRÉVERSIBLE.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SUPPRIMER TOUT',
                style: TextStyle(color: AppColors.surface0)),
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
    final showGames = ref.watch(showGamesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (_isCheckingActivation || _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSpacing.space3 : AppSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'lib/assets/easify (1).png',
                      width: isMobile ? 20 : 24,
                      height: isMobile ? 20 : 24,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _onTitleTap,
                          child: Text(
                            _selectedUser != null
                                ? 'Bienvenue, ${_selectedUser!.name}'
                                : 'Bienvenue',
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink0,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          'Sélectionnez une section',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedUser != null)
                    IconButton(
                      icon: const Icon(Icons.logout_rounded,
                          color: AppColors.ink3),
                      onPressed: () => _showUserSelectionFlow(),
                      tooltip: "Changer d'utilisateur",
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),

              LayoutBuilder(
                builder: (context, constraints) {
                  int crossCount;
                  if (constraints.maxWidth > 900) {
                    crossCount = 4;
                  } else if (constraints.maxWidth > 600) {
                    crossCount = 3;
                  } else {
                    crossCount = 2;
                  }

                  final cards = [
                    _HubCard(
                      icon: Icons.shopping_cart_rounded,
                      title: 'Commande',
                      subtitle: 'Créer une nouvelle commande',
                      color: AppColors.accentYellow,
                      onTap: () => _navigateTo(AppRoutes.order),
                      compact: isMobile,
                    ),
                    _HubCard(
                      icon: Icons.receipt_long_rounded,
                      title: 'Historique',
                      subtitle: 'Voir les commandes passées',
                      color: AppColors.info,
                      onTap: () => _navigateTo(AppRoutes.history),
                      onLongPress: _promptWipeAllOrders,
                      compact: isMobile,
                    ),
                    if (showGames)
                      _HubCard(
                        icon: Icons.sports_esports_rounded,
                        title: 'Jeux',
                        subtitle: 'Sessions de jeux en cours',
                        color: AppColors.accentPurple,
                        onTap: () => _navigateTo(AppRoutes.games),
                        compact: isMobile,
                      ),
                    _HubCard(
                      icon: Icons.analytics_rounded,
                      title: 'Dashboard',
                      subtitle: 'Statistiques et métriques',
                      color: AppColors.success,
                      onTap: () => _navigateTo(AppRoutes.dashboard),
                      compact: isMobile,
                    ),
                    _HubCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'Gestion',
                      subtitle: 'Produits, catégories, dépenses',
                      color: AppColors.warning,
                      onTap: () => _navigateTo(AppRoutes.management),
                      compact: isMobile,
                    ),
                    _HubCard(
                      icon: Icons.settings_rounded,
                      title: 'Paramètres',
                      subtitle: 'Configuration du magasin',
                      color: AppColors.ink3,
                      onTap: () => _navigateTo(AppRoutes.settings),
                      compact: isMobile,
                    ),
                  ];

                  return GridView.count(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: isMobile ? AppSpacing.space3 : AppSpacing.space4,
                    crossAxisSpacing: isMobile ? AppSpacing.space3 : AppSpacing.space4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isMobile ? 1.2 : 1.4,
                    children: cards,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  @override
  State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final padding = widget.compact ? AppSpacing.space3 : AppSpacing.space5;
    final iconSize = widget.compact ? 22.0 : 28.0;
    final iconPadding = widget.compact ? AppSpacing.space2 : AppSpacing.space3;
    final titleSize = widget.compact ? 13.0 : 16.0;
    final subtitleSize = widget.compact ? 10.0 : 12.0;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _hovering = true),
      onTapUp: (_) => setState(() => _hovering = false),
      onTapCancel: () => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.surface0,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _hovering ? widget.color : AppColors.surface3,
            width: _hovering ? 1.5 : 1,
          ),
          boxShadow: _hovering ? [
            const BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: widget.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(widget.icon, color: widget.color, size: iconSize),
              ),
              const Spacer(),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink0,
                ),
              ),
              SizedBox(height: widget.compact ? 2 : AppSpacing.space1),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: AppColors.ink3,
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
