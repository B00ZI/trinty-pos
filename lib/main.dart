import 'package:flutter/material.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/screens/history_screen.dart';
import 'package:Easify/screens/order_screen.dart';
import 'package:Easify/screens/products_screen.dart';
import 'package:Easify/models/order_counter.dart';
import 'package:Easify/screens/settings_screen.dart';
import 'package:Easify/screens/dashboard_screen.dart';
import 'service/activation_service.dart';
import 'widgets/activation_dialog.dart';
import 'screens/catigory_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final objectbox = await ObjectBox.create();
  final counterBox = objectbox.store.box<OrderCounter>();
  if (counterBox.isEmpty()) {
    counterBox.put(OrderCounter(value: 1));
  }

  runApp(Easify(objectbox: objectbox));
}

class Easify extends StatelessWidget {
  final ObjectBox objectbox;
  const Easify({super.key, required this.objectbox});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easify',
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


class MainScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const MainScreen({super.key, required this.objectbox});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;
  bool _isCheckingActivation = true;

  @override
  void initState() {
    super.initState();
    _checkActivation();
    _widgetOptions = <Widget>[
      CatigoryScreen(objectbox: widget.objectbox),
      HistoryScreen(objectbox: widget.objectbox),
      DashboardScreen(objectbox: widget.objectbox),
      ProductsScreen(objectbox: widget.objectbox),
      SettingsScreen(objectbox: widget.objectbox),
    ];
  }

  Future<void> _checkActivation() async {
    final activated = await ActivationService.isActivated();
    if (mounted) {
      setState(() {
        _isCheckingActivation = false;
      });
      if (!activated) {
        _showActivationDialog();
      }
    }
  }

  void _showActivationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ActivationDialog(
        onActivated: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingActivation) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Easify'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ), 
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Order',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings), // Removed unnecessary const
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black45,
        onTap: _onItemTapped,
      ),
    );
  }
}
