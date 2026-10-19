import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/store_config.dart';
import '../objectbox.dart';
import '../service/business_day_helper.dart';
import '../theme/app_colors.dart';

/// Business-day settings (P19/P27).
///
/// Instead of asking the owner for a raw "reset time" (plus an "end
/// time" that nothing ever read — P27), ask the two questions every
/// shop can answer: when do you OPEN and when do you CLOSE? The app
/// calculates the reset itself — the middle of the closed hours — so
/// a day's work always lands in one business day, even when the
/// opening hour is random ("some days 16h, some days 20h").
///
/// "Standard" (reset at midnight) stays the default: shops that never
/// open this screen behave exactly like before (StoreConfig defaults).
/// The boundary is stored in the existing dayStart fields — no schema
/// change. The owner's two answers live in SharedPreferences (UI
/// memory only); the dead dayEnd fields are never touched again.
class BusinessDaySettingsWidget extends StatefulWidget {
  final ObjectBox objectbox;

  const BusinessDaySettingsWidget({super.key, required this.objectbox});

  @override
  State<BusinessDaySettingsWidget> createState() =>
      _BusinessDaySettingsWidgetState();
}

class _BusinessDaySettingsWidgetState extends State<BusinessDaySettingsWidget> {
  static const _modeKey = 'biz_day_mode';
  static const _openHKey = 'biz_open_h';
  static const _openMKey = 'biz_open_m';
  static const _closeHKey = 'biz_close_h';
  static const _closeMKey = 'biz_close_m';

  late StoreConfig _config;
  bool _basedOnHours = false;
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final configs = widget.objectbox.storeConfigBox.getAll();
    _config = configs.isNotEmpty ? configs.first : StoreConfig();

    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_modeKey);
    if (mode == null) {
      // First run after the upgrade: infer from the stored boundary —
      // anything other than midnight was set on the old start picker.
      _basedOnHours = _config.dayStartHour != 0 || _config.dayStartMinute != 0;
    } else {
      _basedOnHours = mode == 'hours';
    }
    _openTime = TimeOfDay(
      hour: prefs.getInt(_openHKey) ??
          (_basedOnHours ? _config.dayStartHour : 8),
      minute: prefs.getInt(_openMKey) ??
          (_basedOnHours ? _config.dayStartMinute : 0),
    );
    _closeTime = TimeOfDay(
      hour: prefs.getInt(_closeHKey) ?? 20,
      minute: prefs.getInt(_closeMKey) ?? 0,
    );
    if (mounted) setState(() {});
  }

  /// The reset we would store for the current answers (middle of the
  /// closed hours).
  (int, int) get _reset => BusinessDayHelper.resetFromHours(
        openHour: _openTime.hour,
        openMinute: _openTime.minute,
        closeHour: _closeTime.hour,
        closeMinute: _closeTime.minute,
      );

  String _format(int h, int m) =>
      '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}';

  Future<void> _selectTime({required bool isOpen}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? _openTime : _closeTime,
    );
    if (picked != null) {
      setState(() {
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, _basedOnHours ? 'hours' : 'standard');
    await prefs.setInt(_openHKey, _openTime.hour);
    await prefs.setInt(_openMKey, _openTime.minute);
    await prefs.setInt(_closeHKey, _closeTime.hour);
    await prefs.setInt(_closeMKey, _closeTime.minute);

    if (_basedOnHours) {
      final reset = _reset;
      _config.dayStartHour = reset.$1;
      _config.dayStartMinute = reset.$2;
    } else {
      _config.dayStartHour = 0;
      _config.dayStartMinute = 0;
    }
    // P27: the old "end time" fields are intentionally left untouched —
    // nothing reads them, and no schema change (no codegen) is needed.
    widget.objectbox.storeConfigBox.put(_config);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Horaires enregistrés avec succès')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final pad = isMobile ? 12.0 : 24.0;
    final reset = _reset;

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
                'Dites-nous quand vous travaillez — nous calculons '
                'le meilleur moment de réinitialisation.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.ink3),
              ),
              SizedBox(height: isMobile ? 16 : 24),
              _ModeTile(
                selected: !_basedOnHours,
                title: 'Jour standard',
                subtitle: 'La journée démarre à minuit (00h00)',
                onTap: () => setState(() => _basedOnHours = false),
              ),
              _ModeTile(
                selected: _basedOnHours,
                title: 'Basé sur mes horaires',
                subtitle:
                    'La journée se réinitialise pendant vos heures de fermeture',
                onTap: () => setState(() => _basedOnHours = true),
              ),
              if (_basedOnHours) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Heure d\'ouverture (généralement)'),
                  subtitle: Text(_openTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectTime(isOpen: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Heure de fermeture (généralement)'),
                  subtitle: Text(_closeTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectTime(isOpen: false),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: AppColors.accentYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '→ Votre journée se réinitialise à '
                        '${_format(reset.$1, reset.$2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vous êtes généralement fermé à cette heure — les '
                        'ventes de la journée restent toujours ensemble, '
                        'même si vous ouvrez plus tôt ou plus tard que '
                        'd\'habitude.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.ink3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'À régler une seule fois : si vos horaires changent plus '
                  'tard, l\'ancien découpage des jours passés change aussi.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.ink3, fontStyle: FontStyle.italic),
                ),
              ],
              SizedBox(height: isMobile ? 20 : 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer les Horaires'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 12 : 16),
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

/// One selectable mode row (radio-style, no deprecated Radio API).
class _ModeTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.accentYellow : AppColors.ink3,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.ink3),
      ),
      onTap: onTap,
    );
  }
}
