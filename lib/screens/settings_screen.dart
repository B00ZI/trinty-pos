import 'dart:convert';
import 'dart:io';

// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:validators/validators.dart';
import 'package:flutter/services.dart';
import '../models/printer_config.dart';
import '../models/store_config.dart';
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
    _loadPrinterConfig();
  }

  Future<void> _loadPrinterConfig() async {
    try {
      final existingConfig = _printerConfigBox.getAll();
      final config = existingConfig.isNotEmpty ? existingConfig.first : null;

      if (mounted) {
        setState(() {
          _ipAddressController.text = config?.ipAddress ?? '';
          _portController.text = config?.port.toString() ?? '';
          _singleTicketMode = config?.singleTicketMode ?? false;
          _enableChangeWindow = config?.enableChangeWindow ?? true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement : ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _ipAddressController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paramètres de l\'Imprimante',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ipAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Adresse IP de l\'imprimante',
                            prefixIcon: Icon(Icons.router),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer une adresse IP';
                            }
                            if (!isIP(value)) {
                              return 'Veuillez entrer une adresse IP valide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          keyboardType: TextInputType.number,
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port de l\'imprimante',
                            prefixIcon: Icon(Icons.settings_input_component),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un port';
                            }
                            final port = int.tryParse(value);
                            if (port == null) {
                              return "Veuillez entrer un nombre valide";
                            }
                            if (port < 1 || port > 65535) {
                              return "Le port doit être entre 1 et 65535";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Card(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  title: const Text('Mode Ticket Simple'),
                                  subtitle: const Text(
                                      'Affiche deux boutons : "Sauvegarder & Double Impression" et "Impression Simple"'),
                                  value: _singleTicketMode,
                                  onChanged: (value) {
                                    setState(() {
                                      _singleTicketMode = value;
                                    });
                                  },
                                ),
                                SwitchListTile(
                                  title: const Text('Fenêtre de Monnaie'),
                                  subtitle: const Text(
                                      'Affiche une fenêtre pour calculer le montant et la monnaie à rendre'),
                                  value: _enableChangeWindow,
                                  onChanged: (value) {
                                    setState(() {
                                      _enableChangeWindow = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _testPrinterConnection,
                                icon: const Icon(Icons.print),
                                label: const Text('Imprimer un test'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _savePrinterConfig,
                                icon: const Icon(Icons.save),
                                label: const Text('Enregistrer l\'IP'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                StoreConfigWidget(objectbox: widget.objectbox),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _savePrinterConfig() async {
    if (_formKey.currentState!.validate()) {
      try {
        _printerConfigBox.removeAll();
        final config = PrinterConfig(
          ipAddress: _ipAddressController.text,
          port: int.parse(_portController.text),
          singleTicketMode: _singleTicketMode,
          enableChangeWindow: _enableChangeWindow,
        );
        _printerConfigBox.put(config);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configuration enregistrée')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur d\'enregistrement : ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _testPrinterConnection() async {
    if (_formKey.currentState!.validate()) {
      try {
        final ipAddress = _ipAddressController.text;
        final port = int.parse(_portController.text);

        final socket = await Socket.connect(ipAddress, port,
            timeout: const Duration(seconds: 5));

        // ESC/POS command to print "Test Print" and cut the paper
        final List<int> bytes = [
          ...utf8.encode("Test Print\n\n\n"),
          0x1B, 0x64, 0x02, // Feed 2 lines
          0x1D, 0x56, 0x41, 0x10, // Partial cut
        ];

        socket.add(bytes);
        await socket.flush();
        await socket.close();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test d\'impression envoyé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : ${e.toString()}')),
          );
        }
      }
    }
  }
}
