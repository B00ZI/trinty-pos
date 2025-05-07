// main.dart
import 'package:flutter/material.dart';
import 'package:myApp/objectbox.dart';
import 'package:myApp/screens/history_screen.dart';
import 'package:myApp/screens/order_screen.dart';
import 'package:myApp/screens/products_screen.dart';
import 'package:myApp/screens/settings_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final objectbox = await ObjectBox.create();
  runApp(MyApp(objectbox: objectbox));
}
class MyApp extends StatelessWidget {
  final ObjectBox objectbox;
  const MyApp({super.key, required this.objectbox});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyApp',
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
      OrderScreen(), 
      HistoryScreen(), 
      ProductsScreen(), 
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
        title: const Text('MyApp'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      drawer: const Drawer(
        child: ListView(children: []),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[ // Added const here
          BottomNavigationBarItem( 
            icon: const Icon(Icons.shopping_cart), // Added const here
            label: 'Order',
          ),
          BottomNavigationBarItem( 
            icon: const Icon(Icons.history), // Added const here
            label: 'History',
          ),
          BottomNavigationBarItem( 
            icon: const Icon(Icons.apps), // Added const here
            label: 'Products',
          ),
          BottomNavigationBarItem( 
            icon: const Icon(Icons.settings), // Added const here
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