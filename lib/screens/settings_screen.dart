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
import '../widgets/admin_pin_dialog.dart';
import '../models/product.dart';
import '../objectbox.g.dart';
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
            onDestinationSelected: (int index) async {
              if (index == 4) {
                final isAdmin = await AdminPinDialog.verify(context, widget.objectbox);
                if (!isAdmin) return;
              }
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
    // Verify admin PIN before adding a user
    final isAdmin = await AdminPinDialog.verify(context, widget.objectbox);
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action refusée : Authentification administrateur requise')),
        );
      }
      return;
    }

    if (!mounted) return;

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
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'utilisateur',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: pinController,
                decoration: const InputDecoration(
                  labelText: 'PIN (4 chiffres)',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v == null || v.length != 4 ? '4 chiffres requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPinController,
                decoration: const InputDecoration(
                  labelText: 'Confirmer PIN',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
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
            child: const Text('Créer l\'utilisateur'),
          ),
        ],
      ),
    );

    if (result == true) {
      _userBox.put(AppUser(
        name: nameController.text.trim(),
        pin: AppUser.hashPin(pinController.text),
        isAdmin: false,
      ));
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Utilisateur ${nameController.text} créé avec succès')),
        );
      }
    }
  }

  Future<void> _editUserPin(AppUser user) async {
    // First verify admin PIN
    final isAdmin = await AdminPinDialog.verify(context, widget.objectbox);
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action refusée : Authentification administrateur requise')),
        );
      }
      return;
    }

    if (!mounted) return;

    // Now show the new PIN dialog
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.password, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(child: Text('Changer le PIN de ${user.name}')),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinController,
                decoration: const InputDecoration(
                  labelText: 'Nouveau PIN (4 chiffres)',
                  prefixIcon: Icon(Icons.lock_open),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v == null || v.length != 4 ? '4 chiffres requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPinController,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le nouveau PIN',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
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
            child: const Text('Enregistrer le nouveau PIN'),
          ),
        ],
      ),
    );

    if (result == true) {
      user.pin = AppUser.hashPin(pinController.text);
      _userBox.put(user);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Le PIN de ${user.name} a été mis à jour')),
        );
      }
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    if (user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L\'administrateur système ne peut pas être supprimé.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Verify admin PIN before deleting
    final isAdmin = await AdminPinDialog.verify(context, widget.objectbox);
    if (!isAdmin) return;

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Voulez-vous vraiment supprimer définitivement l\'utilisateur ${user.name} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _userBox.remove(user.id);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Utilisateur ${user.name} supprimé')),
        );
      }
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestion des Utilisateurs', style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                    'Seuls les administrateurs peuvent modifier les accès',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addUser,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _users.isEmpty
                ? const Center(child: Text('Aucun utilisateur configuré'))
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: user.isAdmin
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                  : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                              color: user.isAdmin
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade700,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (user.isAdmin) ...[
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'Créé le : ${user.createdAt.toString().split(' ')[0]}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: 'Modifier le PIN',
                                child: IconButton.filledTonal(
                                  icon: const Icon(Icons.key_outlined, size: 20),
                                  onPressed: () => _editUserPin(user),
                                ),
                              ),
                              if (!user.isAdmin) ...[
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Supprimer l\'utilisateur',
                                  child: IconButton.filledTonal(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    color: Colors.red,
                                    onPressed: () => _deleteUser(user),
                                  ),
                                ),
                              ],
                            ],
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

/// Dialog for verifying admin PIN before sensitive operations
class _AdminPinDialog extends StatefulWidget {
  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitTap(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });
      if (_enteredPin.length == 4) {
        // Automatically return the PIN to the caller for verification
        Navigator.pop(context, _enteredPin);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.admin_panel_settings,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Accès Administrateur',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Veuillez entrer le code administrateur',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool isFilled = index < _enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade200,
                          boxShadow: isFilled
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            _buildKeypad(),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('ANNULER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((d) => _buildKey(d)).toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 64),
            _buildKey('0'),
            _buildKey('⌫', isIcon: true, onTap: _onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String label, {bool isIcon = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => _onDigitTap(label),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isIcon
              ? Icon(Icons.backspace_outlined, size: 20, color: Colors.grey.shade800)
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
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
          Text('Configuration de la Boutique',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  StoreConfigWidget(objectbox: objectbox),
                  const SizedBox(height: 24),
                  SurgePriceSettingsSection(objectbox: objectbox),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SurgePriceSettingsSection extends StatefulWidget {
  final ObjectBox objectbox;
  const SurgePriceSettingsSection({super.key, required this.objectbox});

  @override
  State<SurgePriceSettingsSection> createState() =>
      _SurgePriceSettingsSectionState();
}

class _SurgePriceSettingsSectionState extends State<SurgePriceSettingsSection> {
  final _amountController = TextEditingController();
  bool _isSurgeEnabled = false;
  List<int> _selectedProductIds = [];
  StoreConfig? _currentConfig;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final configs = widget.objectbox.storeConfigBox.getAll();
    if (configs.isNotEmpty) {
      _currentConfig = configs.first;
      _isSurgeEnabled = _currentConfig?.isSurgePriceEnabled ?? false;
      _amountController.text = _currentConfig?.surgePriceAmount.toString() ?? '0.0';
      _selectedProductIds = List<int>.from(_currentConfig?.surgeProductIds ?? []);
    }
  }

  Future<void> _saveConfig() async {
    final config = _currentConfig ?? StoreConfig();
    config.isSurgePriceEnabled = _isSurgeEnabled;
    config.surgePriceAmount = double.tryParse(_amountController.text) ?? 0.0;
    config.surgeProductIds = List<int>.from(_selectedProductIds);

    widget.objectbox.storeConfigBox.put(config);
    _currentConfig = config;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres de majoration enregistrés')),
      );
    }
  }

  void _showProductSelection() async {
    final allProducts = widget.objectbox.productBox.getAll();
    allProducts.sort((a, b) => a.name.compareTo(b.name));

    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Sélectionner les produits'),
              content: SizedBox(
                width: 400,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allProducts.length,
                  itemBuilder: (context, index) {
                    final p = allProducts[index];
                    final isSelected = _selectedProductIds.contains(p.id);
                    return CheckboxListTile(
                      title: Text(p.name),
                      subtitle: Text('${p.price.toStringAsFixed(2)} DH'),
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            _selectedProductIds.add(p.id);
                          } else {
                            _selectedProductIds.remove(p.id);
                          }
                        });
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveConfig();
                  },
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Majoration des Prix (Plus)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Switch(
                  value: _isSurgeEnabled,
                  onChanged: (val) {
                    setState(() => _isSurgeEnabled = val);
                    _saveConfig();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Appliquer un supplément fixe aux produits sélectionnés.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Montant (DH)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_circle_outline),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: _showProductSelection,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(
                      _selectedProductIds.isEmpty
                          ? 'Choisir Produits'
                          : '${_selectedProductIds.length} Produits',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save),
                  tooltip: 'Enregistrer',
                ),
              ],
            ),
          ],
        ),
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
