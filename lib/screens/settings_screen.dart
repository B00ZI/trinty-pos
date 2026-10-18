import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:validators/validators.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_config.dart';
import '../models/store_config.dart';
import '../models/app_user.dart';
import '../widgets/store_config.dart';
import '../widgets/business_day_settings.dart';
import '../widgets/games_settings_section.dart';
import '../widgets/maintenance_section.dart';
import '../widgets/admin_pin_dialog.dart';
import '../objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import '../providers/dashboard_provider.dart';
import '../service/printer_helper.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSettingsChanged;
  const SettingsScreen({super.key, this.onSettingsChanged});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final sections = [
      const PrinterSettingsSection(),
      const UserManagementSection(),
      const StoreSettingsSection(),
      BusinessDaySettingsWidget(objectbox: ref.read(objectBoxProvider)),
      const AuthModeSection(),
      GamesSettingsSection(
        objectbox: ref.read(objectBoxProvider),
        onSettingsChanged: widget.onSettingsChanged,
      ),
      const MaintenanceSection(),
    ];

    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.surface1,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      color: AppColors.ink0,
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildMobileTab(0, Icons.print_outlined, 'Imprimante'),
                          _buildMobileTab(1, Icons.people_outline, 'Utilisateurs'),
                          _buildMobileTab(2, Icons.store_outlined, 'Boutique'),
                          _buildMobileTab(3, Icons.schedule_outlined, 'Horaires'),
                          _buildMobileTab(4, Icons.security_outlined, 'Sécurité'),
                          _buildMobileTab(5, Icons.sports_esports_outlined, 'Jeux'),
                          _buildMobileTab(6, Icons.cleaning_services_outlined, 'Maintenance'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sections[_currentIndex],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Row(
          children: [
            Column(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: AppColors.ink0,
                    onPressed: () => context.pop(),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              selectedIndex: _currentIndex,
                              backgroundColor: AppColors.surface1,
                              indicatorColor: AppColors.accentYellow.withOpacity(0.12),
                              selectedIconTheme: IconThemeData(color: AppColors.accentYellow),
                              unselectedIconTheme: IconThemeData(color: AppColors.ink4),
                              selectedLabelTextStyle: const TextStyle(color: AppColors.accentYellow, fontWeight: FontWeight.w600),
                              unselectedLabelTextStyle: const TextStyle(color: AppColors.ink4),
                              onDestinationSelected: (int index) async {
                                if (index == 4 || index == 6) {
                                  final isAdmin = await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
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
                                NavigationRailDestination(
                                  icon: Icon(Icons.cleaning_services_outlined),
                                  selectedIcon: Icon(Icons.cleaning_services),
                                  label: Text('Maintenance'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            VerticalDivider(thickness: 1, width: 1, color: AppColors.surface3),
            Expanded(
              child: sections[_currentIndex],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTab(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () async {
        if (index == 4 || index == 6) {
          final isAdmin = await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
          if (!isAdmin) return;
        }
        setState(() => _currentIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentYellow.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentYellow : AppColors.surface3,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? AppColors.accentYellow : AppColors.ink4),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.accentYellow : AppColors.ink4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrinterSettingsSection extends ConsumerStatefulWidget {
  const PrinterSettingsSection({super.key});

  @override
  ConsumerState<PrinterSettingsSection> createState() => _PrinterSettingsSectionState();
}

class _PrinterSettingsSectionState extends ConsumerState<PrinterSettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _ipAddressController = TextEditingController();
  final _portController = TextEditingController();
  late final Box<PrinterConfig> _printerConfigBox;
  bool _singleTicketMode = false;
  bool _enableChangeWindow = true;

  @override
  void initState() {
    super.initState();
    _printerConfigBox = ref.read(objectBoxProvider).store.box<PrinterConfig>();
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
      final config = PrinterConfig(
        ipAddress: _ipAddressController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 91000,
        singleTicketMode: _singleTicketMode,
        enableChangeWindow: _enableChangeWindow,
      );
      // P29: delete-then-rewrite commits as ONE sealed save — a crash in
      // between used to leave no printer config at all.
      ref.read(objectBoxProvider).store.runInTransaction(TxMode.write, () {
        _printerConfigBox.removeAll();
        _printerConfigBox.put(config);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration enregistrée')),
      );
    }
  }

  Future<void> _testPrinter() async {
    if (_formKey.currentState!.validate()) {
      final ip = _ipAddressController.text.trim();
      if (ip.isEmpty) {
        // No printer on purpose — say it instead of crashing the socket.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Aucune imprimante configurée')));
        return;
      }
      try {
        final port = int.tryParse(_portController.text.trim()) ?? 91000;
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
        // Short French message instead of the raw socket dump (timeouts).
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(PrinterHelper.friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.space6),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paramètres de l\'Imprimante', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: AppSpacing.space6),
            TextFormField(
              controller: _ipAddressController,
              decoration: InputDecoration(
                labelText: 'Adresse IP',
                hintText: 'Laisser vide = pas d\'imprimante',
                prefixIcon: const Icon(Icons.router),
                filled: true,
                fillColor: AppColors.surface0,
                border: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
              validator: (v) => v == null || (v.trim().isNotEmpty && !isIP(v.trim())) ? 'IP invalide' : null,
            ),
            SizedBox(height: AppSpacing.space4),
            TextFormField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'Port',
                hintText: 'Laisser vide = 91000',
                prefixIcon: const Icon(Icons.settings_input_component),
                filled: true,
                fillColor: AppColors.surface0,
                border: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                // Empty port = default 91000 (the standard printer port) —
                // clearing IP + port ("no printer") must stay savable.
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final p = int.tryParse(s);
                return p == null || p < 1 || p > 65535 ? 'Port invalide' : null;
              },
            ),
            SizedBox(height: AppSpacing.space6),
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
            SizedBox(height: AppSpacing.space8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testPrinter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface2,
                      foregroundColor: AppColors.ink0,
                    ),
                    child: const Text('Tester'),
                  ),
                ),
                SizedBox(width: AppSpacing.space4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentYellow,
                      foregroundColor: AppColors.payNowText,
                    ),
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UserManagementSection extends ConsumerStatefulWidget {
  const UserManagementSection({super.key});

  @override
  ConsumerState<UserManagementSection> createState() => _UserManagementSectionState();
}

class _UserManagementSectionState extends ConsumerState<UserManagementSection> {
  late final Box<AppUser> _userBox;
  List<AppUser> _users = [];

  @override
  void initState() {
    super.initState();
    _userBox = ref.read(objectBoxProvider).store.box<AppUser>();
    _loadUsers();
  }

  void _loadUsers() {
    setState(() => _users = _userBox.getAll());
  }

  Future<void> _addUser() async {
    final isAdmin = await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
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
        backgroundColor: AppColors.surface0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        title: const Text('Ajouter un Utilisateur'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nom de l\'utilisateur',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: AppColors.surface1,
                    border: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                    enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                    focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                ),
                SizedBox(height: AppSpacing.space4),
                TextFormField(
                  controller: pinController,
                  decoration: InputDecoration(
                    labelText: 'PIN (4 chiffres)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: AppColors.surface1,
                    border: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                    enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                    focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v == null || v.length != 4 ? '4 chiffres requis' : null,
                ),
                SizedBox(height: AppSpacing.space4),
                TextFormField(
                  controller: confirmPinController,
                  decoration: InputDecoration(
                    labelText: 'Confirmer PIN',
                    prefixIcon: const Icon(Icons.check_circle_outline),
                    filled: true,
                    fillColor: AppColors.surface1,
                    border: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                    enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                    focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
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
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentYellow,
              foregroundColor: AppColors.payNowText,
            ),
            child: const Text('Créer l\'utilisateur'),
          ),
        ],
      ),
    );

    if (result == true) {
      final (hash, salt) = AppUser.hashPin(pinController.text);
      _userBox.put(AppUser(
        name: nameController.text.trim(),
        pin: hash,
        pinSalt: salt,
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
    final isAdmin = await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action refusée : Authentification administrateur requise')),
        );
      }
      return;
    }

    if (!mounted) return;

    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        title: Row(
          children: [
            const Icon(Icons.password, color: AppColors.primary),
            SizedBox(width: AppSpacing.space3),
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
                decoration: InputDecoration(
                  labelText: 'Nouveau PIN (4 chiffres)',
                  prefixIcon: const Icon(Icons.lock_open),
                  filled: true,
                  fillColor: AppColors.surface1,
                  border: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                  focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v == null || v.length != 4 ? '4 chiffres requis' : null,
              ),
              SizedBox(height: AppSpacing.space4),
              TextFormField(
                controller: confirmPinController,
                decoration: InputDecoration(
                  labelText: 'Confirmer le nouveau PIN',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  filled: true,
                  fillColor: AppColors.surface1,
                  border: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                  focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentYellow,
              foregroundColor: AppColors.payNowText,
            ),
            child: const Text('Enregistrer le nouveau PIN'),
          ),
        ],
      ),
    );

    if (result == true) {
      final (hash, salt) = AppUser.hashPin(pinController.text);
      user.pin = hash;
      user.pinSalt = salt;
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
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final isAdmin = await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
    if (!isAdmin) return;

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Voulez-vous vraiment supprimer définitivement l\'utilisateur ${user.name} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.surface0,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.all(isMobile ? AppSpacing.space3 : AppSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Text('Gestion des Utilisateurs', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              'Seuls les administrateurs peuvent modifier les accès',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink3),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addUser,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentYellow,
                  foregroundColor: AppColors.payNowText,
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gestion des Utilisateurs', style: Theme.of(context).textTheme.headlineSmall),
                    Text(
                      'Seuls les administrateurs peuvent modifier les accès',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink3),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _addUser,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentYellow,
                    foregroundColor: AppColors.payNowText,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: isMobile ? AppSpacing.space3 : AppSpacing.space6),
          Expanded(
            child: _users.isEmpty
                ? const Center(child: Text('Aucun utilisateur configuré'))
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        color: AppColors.surface0,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.rLg,
                          side: const BorderSide(color: AppColors.surface3),
                        ),
                        margin: EdgeInsets.only(bottom: AppSpacing.space3),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.space5, vertical: AppSpacing.space2),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: user.isAdmin
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.surface2,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                              color: user.isAdmin ? AppColors.primary : AppColors.ink2,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (user.isAdmin) ...[
                                SizedBox(width: AppSpacing.space3),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.space2 + 2, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primary.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: AppRadius.rFull,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.3),
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
                                      color: AppColors.surface0,
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
                                SizedBox(width: AppSpacing.space2),
                                Tooltip(
                                  message: 'Supprimer l\'utilisateur',
                                  child: IconButton.filledTonal(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    color: AppColors.danger,
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



class StoreSettingsSection extends ConsumerWidget {
  const StoreSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ref.read(objectBoxProvider);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configuration de la Boutique',
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: AppSpacing.space6),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  StoreConfigWidget(objectbox: ob),
                  SizedBox(height: AppSpacing.space6),
                  const SurgePriceSettingsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SurgePriceSettingsSection extends ConsumerStatefulWidget {
  const SurgePriceSettingsSection({super.key});

  @override
  ConsumerState<SurgePriceSettingsSection> createState() =>
      _SurgePriceSettingsSectionState();
}

class _SurgePriceSettingsSectionState extends ConsumerState<SurgePriceSettingsSection> {
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
    final configs = ref.read(objectBoxProvider).storeConfigBox.getAll();
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

    ref.read(objectBoxProvider).storeConfigBox.put(config);
    _currentConfig = config;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres de majoration enregistrés')),
      );
    }
  }

  void _showProductSelection() async {
    final allProducts = ref.read(objectBoxProvider).productBox.getAll();
    allProducts.sort((a, b) => a.name.compareTo(b.name));

    await showDialog<List<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface0,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
              title: const Text('Sélectionner les produits'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.5,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allProducts.length,
                  itemBuilder: (context, index) {
                    final p = allProducts[index];
                    final isSelected = _selectedProductIds.contains(p.id);
                    return CheckboxListTile(
                      title: Text(p.name, overflow: TextOverflow.ellipsis),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final cardPadding = isMobile ? 12.0 : 16.0;
    final spacing = isMobile ? 12.0 : AppSpacing.space6;

    return Card(
      color: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rLg,
        side: const BorderSide(color: AppColors.surface3),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Majoration des Prix (Plus)',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
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
            SizedBox(height: AppSpacing.space4),
            Text(
              'Appliquer un supplément fixe aux produits sélectionnés.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink3),
            ),
            SizedBox(height: spacing),
            if (isMobile) ...[
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Montant (DH)',
                  prefixIcon: const Icon(Icons.add_circle_outline),
                  filled: true,
                  fillColor: AppColors.surface1,
                  border: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                  focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: AppSpacing.space3),
              SizedBox(
                width: double.infinity,
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
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
                    side: const BorderSide(color: AppColors.surface3),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.space3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
                    backgroundColor: AppColors.accentYellow,
                    foregroundColor: AppColors.payNowText,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Montant (DH)',
                        prefixIcon: const Icon(Icons.add_circle_outline),
                        filled: true,
                        fillColor: AppColors.surface1,
                        border: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.surface3)),
                        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rLg, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: AppSpacing.space3),
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
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.space5),
                        side: const BorderSide(color: AppColors.surface3),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.space3),
                  IconButton.filled(
                    onPressed: _saveConfig,
                    icon: const Icon(Icons.save),
                    tooltip: 'Enregistrer',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accentYellow,
                      foregroundColor: AppColors.payNowText,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AuthModeSection extends ConsumerStatefulWidget {
  const AuthModeSection({super.key});

  @override
  ConsumerState<AuthModeSection> createState() => _AuthModeSectionState();
}

class _AuthModeSectionState extends ConsumerState<AuthModeSection> {
  String _authMode = 'off';
  late final Box<AppUser> _userBox;

  @override
  void initState() {
    super.initState();
    _userBox = ref.read(objectBoxProvider).store.box<AppUser>();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sécurité et Authentification', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: AppSpacing.space8),
          Card(
            color: AppColors.surface0,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.rLg,
              side: const BorderSide(color: AppColors.surface3),
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Désactivé'),
                  subtitle: const Text('Pas d\'authentification requise'),
                  value: 'off',
                  groupValue: _authMode,
                  onChanged: _saveAuthMode,
                ),
                const Divider(height: 1, color: AppColors.surface3),
                RadioListTile<String>(
                  title: const Text('Connexion Session'),
                  subtitle: const Text('Sélectionner un utilisateur au lancement de l\'application'),
                  value: 'session',
                  groupValue: _authMode,
                  onChanged: _saveAuthMode,
                ),
                const Divider(height: 1, color: AppColors.surface3),
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
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Text(
                      'Aucun utilisateur configuré. Les modes d\'authentification ne peuvent pas être activés.',
                      style: const TextStyle(color: AppColors.warning),
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
