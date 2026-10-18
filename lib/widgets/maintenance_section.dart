import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_provider.dart';
import '../service/history_cleanup_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'admin_pin_dialog.dart';

/// Settings → "Maintenance": automatic retention of old history plus a
/// manual cleanup with flexible scopes (PROBLEMS.md P04).
///
/// Opening this section is already PIN-gated by the settings rail; the
/// manual cleanup additionally asks the admin PIN before deleting.
class MaintenanceSection extends ConsumerStatefulWidget {
  const MaintenanceSection({super.key});

  @override
  ConsumerState<MaintenanceSection> createState() =>
      _MaintenanceSectionState();
}

class _MaintenanceSectionState extends ConsumerState<MaintenanceSection> {
  static const List<int> _dayOptions = [30, 90, 180, 365];

  late final HistoryCleanupService _cleanup;
  int _autoCleanDays = 0;

  @override
  void initState() {
    super.initState();
    _cleanup = HistoryCleanupService(ref.read(objectBoxProvider));
    _loadAutoClean();
  }

  Future<void> _loadAutoClean() async {
    final days = await _cleanup.getAutoCleanDays();
    if (mounted) setState(() => _autoCleanDays = days);
  }

  static String _daysLabel(int days) => days >= 365 ? '1 an' : '$days jours';

  Future<void> _setAutoClean(int days) async {
    setState(() => _autoCleanDays = days);
    await _cleanup.setAutoCleanDays(days);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(days == 0
            ? 'Nettoyage automatique désactivé'
            : 'Nettoyage automatique : les données de plus de ${_daysLabel(days)} seront supprimées au démarrage'),
      ),
    );
  }

  Future<void> _startManualClean() async {
    final scope = await showDialog<_CleanScope>(
      context: context,
      builder: (context) => const _CleanScopeDialog(dayOptions: _dayOptions),
    );
    if (scope == null || !mounted) return;

    // Deleting history is a user action: it uses the PIN the owner set
    // in the app (NOT the dev-panel code 9999).
    final isAdmin =
        await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
    if (!mounted) return;
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nettoyage annulé : code administrateur requis')),
      );
      return;
    }

    if (scope.deleteAll) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            '⚠️ ATTENTION ⚠️',
            style: TextStyle(
                color: AppColors.danger, fontWeight: FontWeight.bold),
          ),
          content: const Text(
              'Toutes les données (commandes, sessions de jeux, dépenses, totaux) seront supprimées et la numérotation des commandes repartira à 1.\n\nCette action est IRRÉVERSIBLE.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SUPPRIMER TOUT',
                  style: TextStyle(color: AppColors.surface0)),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    final result = scope.deleteAll
        ? _cleanup.cleanAll()
        : scope.keepToday
            ? _cleanup.cleanKeepingToday()
            : _cleanup.cleanOlderThan(scope.days);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Nettoyage terminé : ${result.orders} commandes, ${result.sessions} sessions de jeux, ${result.expenses} dépenses supprimées'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Maintenance',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.space2),
          const Text(
            "Gardez l'application rapide en limitant la quantité d'historique conservée. "
            'Les produits, utilisateurs et paramètres ne sont jamais touchés.',
            style: TextStyle(color: AppColors.ink3),
          ),
          const SizedBox(height: AppSpacing.space6),
          _buildAutoCleanCard(),
          const SizedBox(height: AppSpacing.space4),
          _buildManualCleanCard(),
        ],
      ),
    );
  }

  Widget _buildAutoCleanCard() {
    return Card(
      color: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rLg,
        side: const BorderSide(color: AppColors.surface3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_delete_outlined, color: AppColors.accentYellow),
                SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: Text('Nettoyage automatique',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space2),
            const Text(
              "À chaque démarrage, l'application supprime discrètement les données "
              'plus anciennes que la durée choisie. Les totaux journaliers sont conservés.',
              style: TextStyle(color: AppColors.ink3, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.space3),
            Wrap(
              spacing: AppSpacing.space2,
              children: [
                ChoiceChip(
                  label: const Text('Désactivé'),
                  selected: _autoCleanDays == 0,
                  onSelected: (_) => _setAutoClean(0),
                ),
                for (final days in _dayOptions)
                  ChoiceChip(
                    label: Text(_daysLabel(days)),
                    selected: _autoCleanDays == days,
                    onSelected: (_) => _setAutoClean(days),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualCleanCard() {
    return Card(
      color: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rLg,
        side: const BorderSide(color: AppColors.surface3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cleaning_services_outlined, color: AppColors.info),
                SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: Text('Nettoyage manuel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space2),
            const Text(
              "Choisissez quoi supprimer : l'ancien historique uniquement, garder "
              "seulement la journée en cours, ou tout supprimer. Un code "
              'administrateur est demandé avant toute suppression.',
              style: TextStyle(color: AppColors.ink3, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.space3),
            ElevatedButton.icon(
              onPressed: _startManualClean,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Nettoyer maintenant…'),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a manual cleanup should delete.
class _CleanScope {
  final int days;
  final bool keepToday;
  final bool deleteAll;

  const _CleanScope({
    required this.days,
    this.keepToday = false,
    this.deleteAll = false,
  });
}

class _CleanScopeDialog extends StatefulWidget {
  final List<int> dayOptions;

  const _CleanScopeDialog({required this.dayOptions});

  @override
  State<_CleanScopeDialog> createState() => _CleanScopeDialogState();
}

class _CleanScopeDialogState extends State<_CleanScopeDialog> {
  String _mode = 'older';
  int _days = 90;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nettoyer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option(
            value: 'older',
            title: "Supprimer l'ancien historique",
            subtitle: 'Les données récentes sont conservées',
            trailing: DropdownButton<int>(
              value: _days,
              items: [
                for (final d in widget.dayOptions)
                  DropdownMenuItem(value: d, child: Text(_label(d))),
              ],
              onChanged: _mode == 'older'
                  ? (v) => setState(() => _days = v!)
                  : null,
            ),
          ),
          _option(
            value: 'today',
            title: "Garder seulement aujourd'hui",
            subtitle: "Supprime tout l'historique sauf la journée en cours",
          ),
          _option(
            value: 'all',
            title: 'Tout supprimer',
            titleColor: AppColors.danger,
            subtitle: 'Commandes, sessions, dépenses et totaux — repartir à zéro',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _CleanScope(
              days: _days,
              keepToday: _mode == 'today',
              deleteAll: _mode == 'all',
            ),
          ),
          child: const Text('Continuer'),
        ),
      ],
    );
  }

  static String _label(int days) => days >= 365 ? '1 an' : '$days j';

  Widget _option({
    required String value,
    required String title,
    required String subtitle,
    Color? titleColor,
    Widget? trailing,
  }) {
    final selected = _mode == value;
    return InkWell(
      onTap: () => setState(() => _mode = value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.accentYellow : AppColors.ink3,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
