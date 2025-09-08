import 'package:flutter/material.dart';
import 'package:Drywich/objectbox.dart';
import 'package:Drywich/screens/history_screen.dart';
import 'package:Drywich/screens/order_screen.dart';
import 'package:Drywich/screens/products_screen.dart';
import 'package:Drywich/models/order_counter.dart';
import 'package:Drywich/screens/settings_screen.dart';
import 'package:Drywich/screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final objectbox = await ObjectBox.create();
  final counterBox = objectbox.store.box<OrderCounter>();
  if (counterBox.isEmpty()) {
    counterBox.put(OrderCounter(value: 1));
  }


  runApp(Drywich(objectbox: objectbox));
}
class Drywich extends StatelessWidget {
  final ObjectBox objectbox;
  const Drywich({super.key, required this.objectbox});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drywich',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      OrderScreen(objectbox: widget.objectbox),
      HistoryScreen(objectbox: widget.objectbox),
       DashboardScreen(),
      ProductsScreen(objectbox: widget.objectbox),
      SettingsScreen(objectbox: widget.objectbox),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drywich'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}
