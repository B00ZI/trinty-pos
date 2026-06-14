import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/screens/games_screen.dart';
import 'package:Easify/screens/history_screen.dart';
import 'package:Easify/screens/order_screen.dart';
import 'package:Easify/screens/dashboard_screen.dart';
import 'package:Easify/screens/management_screen.dart';
import 'package:Easify/screens/settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'models/order_counter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/providers/dashboard_provider.dart';
import 'models/app_user.dart';
import 'screens/dev_panel_screen.dart';
import 'models/game_session.dart';
import 'models/order.dart';
import 'models/order_item.dart';
import 'models/expence.dart';
import 'models/daily_funds.dart';
import 'service/activation_service.dart';
import 'service/auth_service.dart';
import 'service/notification_service.dart';
import 'service/game_session_service.dart';
import 'widgets/activation_dialog.dart';
import 'widgets/user_selection_dialog.dart';
import 'widgets/admin_pin_dialog.dart';

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
    userBox.put(AppUser(
      name: 'Admin',
      pin: AppUser.hashPin('0000'),
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

class Easify extends StatelessWidget {
  final ObjectBox objectbox;
  const Easify({super.key, required this.objectbox});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easify',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'), // Set French as the supported locale
      ],
      locale: const Locale('fr', 'FR'), // Default to French
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF2D7DD2), // Steel Blue
          onPrimary: Color(0xFFFFFFFF), // White
          secondary: Color(0xFF2D7DD2), // Steel Blue (Highlights/Accents)
          onSecondary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFEDF5FC), // Alice Blue (Containers/Inputs)
          onPrimaryContainer: Color(0xFF210124), // Midnight Violet
          surface: Color(0xFFFFFFFF), // White (Main Background)
          onSurface: Color(0xFF210124), // Midnight Violet (Primary Text)
          surfaceContainer: Color(0xFFEDF5FC), // Alice Blue (Secondary Background)
          error: Color(0xFFD32F2F), // Standard Red for Error/Delete
          onError: Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF210124),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF2D7DD2)), // Steel Blue Icons
          titleTextStyle: TextStyle(
            color: Color(0xFF210124),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFEDF5FC), // Alice Blue Cards
          elevation: 0, // "No heavy borders", "Elevation via soft shadow only"
          shadowColor: const Color(0xFF2D7DD2).withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide.none,
          ),
          margin: const EdgeInsets.all(8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D7DD2), // Steel Blue
            foregroundColor: const Color(0xFFFFFFFF), // White
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2D7DD2), // Steel Blue
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFEDF5FC), // Alice Blue
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          hintStyle: TextStyle(color: const Color(0xFF210124).withValues(alpha: 0.5)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFF2D7DD2), // Steel Blue
          unselectedItemColor: Color(0xFF210124), // Midnight Violet (or opacity)
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          showUnselectedLabels: true,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: Color(0xFF210124), fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: Color(0xFF210124), fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Color(0xFF210124), fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: Color(0xFF210124)),
          bodyMedium: TextStyle(color: Color(0xFF210124)),
          bodySmall: TextStyle(color: Color(0xFF210124)),
        ),
      ),
      home: MainScreen(objectbox: objectbox),
    );
  }
}


enum MainTab { order, history, games, dashboard, management, settings }

class MainScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const MainScreen({super.key, required this.objectbox});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  MainTab _selectedTab = MainTab.order;
  bool _showGames = false;
  bool _isLoadingSettings = true;
  bool _isCheckingActivation = true;
  AppUser? _selectedUser;
  DateTime? _lastTabTap;
  DateTime? _lastHistoryTabTap;
  int _historyTapCount = 0;
  
  DateTime? _lastTitleTap;
  int _titleTapCount = 0;

  void _promptWipeAllOrders() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ ATTENTION ⚠️', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment supprimer TOUTES les données (Commandes, Sessions de jeux, Dépenses) et repartir à zéro ?\n\nCette action est IRRÉVERSIBLE.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SUPPRIMER TOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final store = widget.objectbox.store;
      
      store.box<Ruci>().removeAll();
      store.box<OrderItem>().removeAll();
      store.box<GameSession>().removeAll();
      store.box<expence>().removeAll();
      store.box<DailyFunds>().removeAll();

      final orderCounterBox = store.box<OrderCounter>();
      orderCounterBox.removeAll();
      orderCounterBox.put(OrderCounter(id: 1, value: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toutes les données ont été supprimées.')),
        );
        setState(() {
          _selectedTab = MainTab.order;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadGamesTabVisibility();
    _checkActivation();
  }

  Future<void> _loadGamesTabVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showGames = prefs.getBool('show_games_tab') ?? false;
      _isLoadingSettings = false;
    });
  }

  List<MainTab> get _enabledTabs => [
        MainTab.order,
        MainTab.history,
        if (_showGames) MainTab.games,
        MainTab.dashboard,
        MainTab.management,
        MainTab.settings,
      ];

  int get _selectedIndex {
    final index = _enabledTabs.indexOf(_selectedTab);
    return index != -1 ? index : 0;
  }

  Future<void> _checkActivation() async {
    final activated = await ActivationService.isActivated();
    if (mounted) {
      setState(() {
        _isCheckingActivation = false;
      });
      if (!activated) {
        await _showActivationDialog();
      }
      
      // After activation, check auth mode
      _checkSessionAuth();
    }
  }

  Future<void> _checkSessionAuth() async {
    final mode = await AuthService.getAuthMode();
    if (mode == AuthMode.session) {
      _showUserSelectionFlow(isCancelable: false);
    }
  }

  Future<void> _showActivationDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ActivationDialog(
        onActivated: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showUserSelectionFlow({bool isCancelable = true}) async {
    final selected = await showDialog<AppUser>(
      context: context,
      barrierDismissible: isCancelable,
      builder: (context) => UserSelectionDialog(
        objectbox: widget.objectbox,
        isCancelable: isCancelable,
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedUser = selected;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connecté en tant que : ${selected.name}')),
        );
      }
    }
  }

  void _onItemTapped(int index) async {
    final selectedTab = _enabledTabs[index];

    // If the user selects the Dashboard, verify admin status
    if (selectedTab == MainTab.dashboard) {
      final isAdmin = await AdminPinDialog.verify(context, widget.objectbox);
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Accès au Dashboard restreint aux administrateurs')),
          );
        }
        return; // Don't switch tab
      }
    }

    if (selectedTab == MainTab.order) {
      final now = DateTime.now();
      if (_lastTabTap != null &&
          now.difference(_lastTabTap!) < const Duration(milliseconds: 500)) {
        _showUserSelectionFlow();
      }
      _lastTabTap = now;
    } else if (selectedTab == MainTab.history) {
      final now = DateTime.now();
      if (_lastHistoryTabTap != null &&
          now.difference(_lastHistoryTabTap!) < const Duration(milliseconds: 600)) {
        _historyTapCount++;
      } else {
        _historyTapCount = 1;
      }

      if (_historyTapCount >= 5) {
        _promptWipeAllOrders();
        _historyTapCount = 0;
      }
      _lastHistoryTabTap = now;
    }

    setState(() {
      _selectedTab = selectedTab;
    });
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DevPanelScreen(objectbox: widget.objectbox)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingActivation || _isLoadingSettings) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<Widget> widgetOptions = _enabledTabs.map((tab) {
      switch (tab) {
        case MainTab.order:
          return OrderScreen(objectbox: widget.objectbox, assignedUser: _selectedUser);
        case MainTab.history:
          return HistoryScreen(objectbox: widget.objectbox);
        case MainTab.games:
          return GamesScreen(objectbox: widget.objectbox, assignedUser: _selectedUser);
        case MainTab.dashboard:
          return DashboardScreen(objectbox: widget.objectbox);
        case MainTab.management:
          return ManagementScreen(objectbox: widget.objectbox);
        case MainTab.settings:
          return SettingsScreen(
            objectbox: widget.objectbox,
            onSettingsChanged: _loadGamesTabVisibility,
          );
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: Text(_selectedUser != null ? 'Easify - ${_selectedUser!.name}' : 'Easify'),
        ),
        actions: [
          if (_selectedUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showUserSelectionFlow(),
              tooltip: 'Changer d\'utilisateur',
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        items: _enabledTabs.map((tab) {
          switch (tab) {
            case MainTab.order:
              return const BottomNavigationBarItem(
                icon: Icon(Icons.shopping_cart),
                label: 'Commande',
              );
            case MainTab.history:
              return const BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Historique',
              );
            case MainTab.games:
              return const BottomNavigationBarItem(
                icon: Icon(Icons.sports_esports),
                label: 'Jeux',
              );
            case MainTab.dashboard:
              return const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              );
            case MainTab.management:
              return const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2),
                label: 'Gestion',
              );
            case MainTab.settings:
              return const BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Paramètres',
              );
          }
        }).toList(),
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black45,
        onTap: _onItemTapped,
      ),
    );
  }
}
