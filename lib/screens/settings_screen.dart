import 'dart:convert';
import 'dart:io';

// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:validators/validators.dart';
import 'package:flutter/services.dart';
import '../models/printer_config.dart';
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
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading config: ${e.toString()}')),
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
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _ipAddressController,
                decoration: const InputDecoration(
                  labelText: 'Printer IP Address'
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an IP address';
                  }
                  if (!isIP(value)) {
                    return 'Please enter a valid IP address';
                  }
                  return null;
                },
              ),
              TextFormField(
                keyboardType: TextInputType.number,
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Printer Port',
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a port';
                  }
                  final port = int.tryParse(value);
                  if (port == null) {
                    return "Please enter a valid number";
                  }
                  if (port < 1 || port > 65535) {
                    return "Port must be between 1-65535";
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                  ),
                  onPressed: _savePrinterConfig,
                  child: const Text('Save Configuration', style: TextStyle(color: Colors.black45)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                  ),
                  onPressed: _testPrinterConnection,
                  child: const Text('Test Printer Connection', style: TextStyle(color: Colors.black45)),
                ),
              ),
            ],
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
        );
        _printerConfigBox.put(config);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configuration saved')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving config: ${e.toString()}')),
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

      final socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 5));

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
          const SnackBar(content: Text('Test print sent to printer')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  }
}
