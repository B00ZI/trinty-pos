import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/store_config.dart'; // Make sure this import is correct based on your file structure
import '../objectbox.dart';
import '../objectbox.g.dart'; // This will be generated
import 'package:objectbox/objectbox.dart';
import '../service/printer_helper.dart';

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
  File? _logoImage;
  final ImagePicker _picker = ImagePicker();
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
      _storeNameController.text = _currentConfig?.storeName ?? '';
      _storePhoneController.text = _currentConfig?.storePhone ?? '';
      if (_currentConfig?.storeLogoPath != null) {
        final file = File(_currentConfig!.storeLogoPath!);
        if (file.existsSync()) {
          _logoImage = file;
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String appDirPath = appDir.path;
        final String fileName = path.basename(image.path);
        // Create a dedicated directory for store config if you prefer, or just use root
        final String savedImagePath = path.join(appDirPath, 'store_logo_$fileName');
        
        // Copy the file
        final File localImage = await File(image.path).copy(savedImagePath);

        setState(() {
          _logoImage = localImage;
        });
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving image: $e')),
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
      config.storeLogoPath = _logoImage?.path;
      
      // If we're updating, we need to make sure we keep the ID if it was loaded
      // StoreConfig object from objectbox usually has ID if it was read from box
      
      widget.objectbox.storeConfigBox.put(config);
      
      // Reload current config to ensure we have the latest state (like ID)
      _currentConfig = config;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store details saved')),
        );
      }
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storePhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Store Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter store name';
                  }
                  return null;
                },
              ),const SizedBox(height: 16),
              TextFormField(
                controller: _storePhoneController,
                decoration: const InputDecoration(
                  labelText: 'Store Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter store phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
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
                            size: 40,
                            color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Store Logo',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.upload),
                        label: const Text('Upload Image'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => PrinterHelper.printStoreConfig(widget.objectbox),
                      icon: const Icon(Icons.print),
                      label: const Text('Print Test'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveConfig,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Details'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
