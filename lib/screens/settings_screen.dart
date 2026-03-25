import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:validators/validators.dart';
import 'package:flutter/services.dart';
import '../models/printer_config.dart';
import '../models/store_config.dart';
import '../models/app_user.dart';
import '../widgets/store_config.dart';
import '../objectbox.dart';
import 'package:objectbox/objectbox.dart';

class SettingsScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const SettingsScreen({super.key, required this.objectbox});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Icons
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.print_outlined),
                selectedIcon: Icon(Icons.print),
                label: Text('Imprimante'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Utilisateurs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store),
                label: Text('Boutique'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                PrinterSettingsSection(objectbox: widget.objectbox),
                UserManagementSection(objectbox: widget.objectbox),
                StoreSettingsSection(objectbox: widget.objectbox),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrinterSettingsSection extends StatefulWidget {
  final ObjectBox objectbox;
  const PrinterSettingsSection({super.key, required this.objectbox});

  @override
  State<PrinterSettingsSection> createState() => _PrinterSettingsSectionState();
}

class _PrinterSettingsSectionState extends State<PrinterSettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _ipAddressController = TextEditingController();
  final _portController = TextEditingController();
  late final Box<PrinterConfig> _printerConfigBox;
  bool _singleTicketMode = false;
  bool _enableChangeWindow = true;

  @override
  void initState() {
    super.initState();
    _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();
    _loadConfig();
  }

  void _loadConfig() {
    final existingConfig = _printerConfigBox.getAll();
    if (existingConfig.isNotEmpty) {
      final config = existingConfig.first;
      setState(() {
        _ipAddressController.text = config.ipAddress;
        _portController.text = config.port.toString();
        _singleTicketMode = config.singleTicketMode;
        _enableChangeWindow = config.enableChangeWindow;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      _printerConfigBox.removeAll();
      final config = PrinterConfig(
        ipAddress: _ipAddressController.text,
        port: int.parse(_portController.text),
        singleTicketMode: _singleTicketMode,
        enableChangeWindow: _enableChangeWindow,
      );
      _printerConfigBox.put(config);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration enregistrée')),
      );
    }
  }

  Future<void> _testPrinter() async {
    if (_formKey.currentState!.validate()) {
      try {
        final ip = _ipAddressController.text;
        final port = int.parse(_portController.text);
        final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
        final List<int> bytes = [
          ...utf8.encode("Test Print\n\n\n"),
          0x1B, 0x64, 0x02,
          0x1D, 0x56, 0x41, 0x10,
        ];
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test envoyé')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paramètres de l\'Imprimante', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextFormField(
              controller: _ipAddressController,
              decoration: const InputDecoration(labelText: 'Adresse IP', prefixIcon: Icon(Icons.router)),
              validator: (v) => v == null || !isIP(v) ? 'IP invalide' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Port', prefixIcon: Icon(Icons.settings_input_component)),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final p = int.tryParse(v ?? '');
                return p == null || p < 1 || p > 65535 ? 'Port invalide' : null;
              },
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Mode Ticket Simple'),
              value: _singleTicketMode,
              onChanged: (v) => setState(() => _singleTicketMode = v),
            ),
            SwitchListTile(
              title: const Text('Fenêtre de Monnaie'),
              value: _enableChangeWindow,
              onChanged: (v) => setState(() => _enableChangeWindow = v),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: _testPrinter, child: const Text('Tester'))),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(onPressed: _saveConfig, child: const Text('Enregistrer'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UserManagementSection extends StatefulWidget {
  final ObjectBox objectbox;
  const UserManagementSection({super.key, required this.objectbox});

  @override
  State<UserManagementSection> createState() => _UserManagementSectionState();
}

class _UserManagementSectionState extends State<UserManagementSection> {
  late final Box<AppUser> _userBox;
  List<AppUser> _users = [];

  @override
  void initState() {
    super.initState();
    _userBox = widget.objectbox.store.box<AppUser>();
    _loadUsers();
  }

  void _loadUsers() {
    setState(() => _users = _userBox.getAll());
  }

  Future<void> _addUser() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un Utilisateur'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nom'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Ajouter')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      _userBox.put(AppUser(name: name.trim()));
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Utilisateurs', style: Theme.of(context).textTheme.headlineSmall),
              ElevatedButton.icon(onPressed: _addUser, icon: const Icon(Icons.add), label: const Text('Nouveau')),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _users.isEmpty
                ? const Center(child: Text('Aucun utilisateur'))
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        child: ListTile(
                          title: Text(user.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              _userBox.remove(user.id);
                              _loadUsers();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class StoreSettingsSection extends StatelessWidget {
  final ObjectBox objectbox;
  const StoreSettingsSection({super.key, required this.objectbox});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configuration de la Boutique', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Expanded(child: SingleChildScrollView(child: StoreConfigWidget(objectbox: objectbox))),
        ],
      ),
    );
  }
}
