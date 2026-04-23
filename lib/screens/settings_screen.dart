import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:validators/validators.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_config.dart';
import '../models/store_config.dart';
import '../models/app_user.dart';
import '../widgets/store_config.dart';
import '../widgets/business_day_settings.dart';
import '../widgets/games_settings_section.dart';
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
              NavigationRailDestination(
                icon: Icon(Icons.schedule_outlined),
                selectedIcon: Icon(Icons.schedule),
                label: Text('Horaires'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.security_outlined),
                selectedIcon: Icon(Icons.security),
                label: Text('Sécurité'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports),
                label: Text('Jeux'),
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
                BusinessDaySettingsWidget(objectbox: widget.objectbox),
                AuthModeSection(objectbox: widget.objectbox),
                GamesSettingsSection(objectbox: widget.objectbox),
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
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un Utilisateur'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: pinController,
                decoration: const InputDecoration(labelText: 'PIN (4 chiffres)'),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v == null || v.length != 4 ? '4 chiffres requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPinController,
                decoration: const InputDecoration(labelText: 'Confirmer PIN'),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v != pinController.text ? 'Les PIN ne correspondent pas' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result == true) {
      _userBox.put(AppUser(
        name: nameController.text.trim(),
        pin: AppUser.hashPin(pinController.text),
      ));
      _loadUsers();
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${user.name} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _userBox.remove(user.id);
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
                          subtitle: Text('Créé le : ${user.createdAt.toString().split('.')[0]}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteUser(user),
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

class AuthModeSection extends StatefulWidget {
  final ObjectBox objectbox;
  const AuthModeSection({super.key, required this.objectbox});

  @override
  State<AuthModeSection> createState() => _AuthModeSectionState();
}

class _AuthModeSectionState extends State<AuthModeSection> {
  String _authMode = 'off';
  late final Box<AppUser> _userBox;

  @override
  void initState() {
    super.initState();
    _userBox = widget.objectbox.store.box<AppUser>();
    _loadAuthMode();
  }

  Future<void> _loadAuthMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authMode = prefs.getString('auth_mode') ?? 'off';
    });
  }

  Future<void> _saveAuthMode(String? mode) async {
    if (mode == null) return;
    
    if (mode != 'off' && _userBox.isEmpty()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord ajouter au moins un utilisateur')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_mode', mode);
    setState(() {
      _authMode = mode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mode d\'authentification mis à jour')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sécurité et Authentification', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Désactivé'),
                  subtitle: const Text('Pas d\'authentification requise'),
                  value: 'off',
                  groupValue: _authMode,
                  onChanged: _saveAuthMode,
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: const Text('Connexion Session'),
                  subtitle: const Text('Sélectionner un utilisateur au lancement de l\'application'),
                  value: 'session',
                  groupValue: _authMode,
                  onChanged: _saveAuthMode,
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: const Text('PIN par Commande'),
                  subtitle: const Text('Demander le PIN pour chaque nouvelle commande'),
                  value: 'per_order',
                  groupValue: _authMode,
                  onChanged: _saveAuthMode,
                ),
              ],
            ),
          ),
          if (_userBox.isEmpty())
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aucun utilisateur configuré. Les modes d\'authentification ne peuvent pas être activés.',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
