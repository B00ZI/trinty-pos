import 'package:flutter/material.dart';
import '../models/store_config.dart';
import '../objectbox.dart';
import '../theme/app_colors.dart';

class BusinessDaySettingsWidget extends StatefulWidget {
  final ObjectBox objectbox;

  const BusinessDaySettingsWidget({super.key, required this.objectbox});

  @override
  State<BusinessDaySettingsWidget> createState() => _BusinessDaySettingsWidgetState();
}

class _BusinessDaySettingsWidgetState extends State<BusinessDaySettingsWidget> {
  late StoreConfig _config;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final configs = widget.objectbox.storeConfigBox.getAll();
    if (configs.isNotEmpty) {
      _config = configs.first;
    } else {
      _config = StoreConfig();
    }
    _startTime = TimeOfDay(hour: _config.dayStartHour, minute: _config.dayStartMinute);
    _endTime = TimeOfDay(hour: _config.dayEndHour, minute: _config.dayEndMinute);
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveConfig() {
    _config.dayStartHour = _startTime?.hour ?? 0;
    _config.dayStartMinute = _startTime?.minute ?? 0;
    _config.dayEndHour = _endTime?.hour ?? 23;
    _config.dayEndMinute = _endTime?.minute ?? 59;

    widget.objectbox.storeConfigBox.put(_config);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Horaires enregistrés avec succès')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final pad = isMobile ? 12.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paramètres de la Journée',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: isMobile ? 18 : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Définissez les heures de début et de fin de votre journée de travail.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink3),
              ),
              SizedBox(height: isMobile ? 16 : 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Début de journée'),
                subtitle: Text(_startTime?.format(context) ?? 'Non défini'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context, true),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fin de journée (Affichage)'),
                subtitle: Text(_endTime?.format(context) ?? 'Non défini'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context, false),
              ),
              SizedBox(height: isMobile ? 20 : 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer les Horaires'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                    backgroundColor: AppColors.accentYellow,
                    foregroundColor: AppColors.payNowText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
