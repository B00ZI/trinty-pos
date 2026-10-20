import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/store_config.dart';
import '../objectbox.dart';
import '../service/printer_helper.dart';
import '../service/wifi_password_store.dart';
import '../theme/app_colors.dart';

class StoreConfigWidget extends StatefulWidget {
  final ObjectBox objectbox;

  const StoreConfigWidget({super.key, required this.objectbox});

  @override
  State<StoreConfigWidget> createState() => _StoreConfigWidgetState();
}

class _StoreConfigWidgetState extends State<StoreConfigWidget> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storePhoneController = TextEditingController();
  final _wifiPasswordController = TextEditingController();

  File? _logoImage;
  final ImagePicker _picker = ImagePicker();
  StoreConfig? _currentConfig;
  bool _wifiPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final configs = widget.objectbox.storeConfigBox.getAll();
    if (configs.isNotEmpty) {
      _currentConfig = configs.first;
      _storeNameController.text = _currentConfig?.storeName ?? '';
      _storePhoneController.text = _currentConfig?.storePhone ?? '';
      // Legacy fallback: the startup migration clears this field (P07).
      _wifiPasswordController.text = _currentConfig?.wifiPassword ?? '';

      if (_currentConfig?.storeLogoPath != null) {
        final file = File(_currentConfig!.storeLogoPath!);
        if (file.existsSync()) {
          _logoImage = file;
        }
      }
    }
    // The real value lives in platform secure storage (P07).
    final wifi = await WifiPasswordStore.read();
    if (wifi.isNotEmpty) {
      _wifiPasswordController.text = wifi;
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String appDirPath = appDir.path;
        final String fileName = path.basename(image.path);
        final String savedImagePath = path.join(appDirPath, 'store_logo_$fileName');

        final File localImage = await File(image.path).copy(savedImagePath);

        setState(() {
          _logoImage = localImage;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur d\'enregistrement de l\'image : $e')),
          );
        }
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      final config = _currentConfig ?? StoreConfig();
      config.storeName = _storeNameController.text;
      config.storePhone = _storePhoneController.text;
      // P07: the password is kept in secure storage, never in the database.
      config.wifiPassword = null;
      await WifiPasswordStore.write(_wifiPasswordController.text);

      config.storeLogoPath = _logoImage?.path;

      widget.objectbox.storeConfigBox.put(config);
      _currentConfig = config;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Détails du magasin enregistrés')),
        );
      }
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storePhoneController.dispose();
    _wifiPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final cardPadding = isMobile ? 12.0 : 16.0;
    final fieldSpacing = isMobile ? 12.0 : 16.0;
    final logoSize = isMobile ? 64.0 : 80.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Détails du Magasin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: fieldSpacing),
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du Magasin',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom du magasin';
                  }
                  return null;
                },
              ),
              SizedBox(height: fieldSpacing),
              TextFormField(
                controller: _storePhoneController,
                decoration: const InputDecoration(
                  labelText: 'Numéro de Téléphone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              SizedBox(height: fieldSpacing),
              TextFormField(
                controller: _wifiPasswordController,
                obscureText: !_wifiPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Mot de passe WIFI',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.wifi_password),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _wifiPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                        () => _wifiPasswordVisible = !_wifiPasswordVisible),
                  ),
                ),
              ),
              SizedBox(height: fieldSpacing),

              Row(
                children: [
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _logoImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _logoImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.image,
                            size: logoSize / 2,
                            color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Logo du Magasin',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.upload),
                          label: const Text('Télécharger une Image'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 16 : 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => PrinterHelper.printStoreConfig(widget.objectbox),
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimer un test'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.surface2,
                        foregroundColor: AppColors.ink0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveConfig,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer les Détails'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.accentYellow,
                        foregroundColor: AppColors.payNowText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
