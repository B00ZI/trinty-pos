import 'package:flutter/material.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/screens/history_screen.dart';
import 'package:Easify/screens/order_screen.dart';
import 'package:Easify/screens/products_screen.dart';
import 'package:Easify/models/order_counter.dart';
import 'package:Easify/screens/settings_screen.dart';
import 'package:Easify/screens/dashboard_screen.dart';

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
      DashboardScreen(objectbox: widget.objectbox),
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
        title: const Text('Easify'),
        backgroundColor: Colors.orangeAccent,
        foregroundColor: Colors.black,
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
