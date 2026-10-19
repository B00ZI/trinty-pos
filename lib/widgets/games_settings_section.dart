import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_post.dart';
import '../models/party_tier.dart';
import '../objectbox.dart';
import '../providers/navigation_provider.dart';
import '../service/money_parser.dart';
import '../theme/app_colors.dart';
import 'package:objectbox/objectbox.dart';

class GamesSettingsSection extends ConsumerStatefulWidget {
  final ObjectBox objectbox;
  final VoidCallback? onSettingsChanged;
  const GamesSettingsSection({super.key, required this.objectbox, this.onSettingsChanged});

  @override
  ConsumerState<GamesSettingsSection> createState() => _GamesSettingsSectionState();
}

class _GamesSettingsSectionState extends ConsumerState<GamesSettingsSection> {
  late final Box<GamePost> _postBox;
  late final Box<PartyTier> _tierBox;
  List<GamePost> _posts = [];
  List<PartyTier> _tiers = [];
  bool _showGames = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _postBox = widget.objectbox.gamePostBox;
    _tierBox = widget.objectbox.partyTierBox;
    _loadData();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showGames = prefs.getBool('show_games_tab') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleGames(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_games_tab', value);
    ref.read(showGamesProvider.notifier).state = value;
    
    setState(() {
      _showGames = value;
    });
    widget.onSettingsChanged?.call();
  }

  void _loadData() {
    setState(() {
      _posts = _postBox.getAll();
      _tiers = _tierBox.getAll();
    });
  }

  Future<void> _addPost() async {
    final controller = TextEditingController(text: 'Poste ${_posts.length + 1}');
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un Poste'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nom du poste'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentYellow,
              foregroundColor: AppColors.payNowText,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (label != null && label.trim().isNotEmpty) {
      _postBox.put(GamePost(label: label.trim()));
      _loadData();
    }
  }

  Widget _buildTierSection() {
    final rateController = TextEditingController(
      text: _tiers.isNotEmpty ? _tiers.first.ratePerHour.toString() : '',
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarif Horaire Global', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: isMobile ? 10 : 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rateController,
                    decoration: const InputDecoration(labelText: 'Prix par Heure (DH)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final rate = MoneyParser.parse(rateController.text);
                    if (rate != null) {
                      final tier = _tiers.isNotEmpty ? _tiers.first : PartyTier(label: 'Tarif Standard', ratePerHour: rate);
                      tier.ratePerHour = rate;
                      tier.label = 'Tarif Standard';
                      _tierBox.put(tier);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarif enregistré')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer un tarif valide')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentYellow,
                    foregroundColor: AppColors.payNowText,
                  ),
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final pad = isMobile ? 12.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: EdgeInsets.only(bottom: pad),
            child: SwitchListTile(
              secondary: Icon(
                Icons.sports_esports,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Activer la section Jeux'),
              subtitle: const Text('Afficher l\'onglet des jeux et sessions sur l\'écran principal'),
              value: _showGames,
              onChanged: _toggleGames,
            ),
          ),
          if (!_showGames) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sports_esports_outlined,
                        size: isMobile ? 48 : 72,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      ),
                      SizedBox(height: isMobile ? 10 : 16),
                      Text(
                        'Gestion des jeux désactivée',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          fontSize: isMobile ? 18 : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Activez l\'option ci-dessus pour configurer les postes de jeux et le tarif horaire.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            _buildHeader('Gestion des Postes', _addPost),
            SizedBox(height: isMobile ? 10 : 16),
            _buildPostList(),
            SizedBox(height: isMobile ? 24 : 40),
            _buildTierSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentYellow,
            foregroundColor: AppColors.payNowText,
          ),
        ),
      ],
    );
  }

  Widget _buildPostList() {
    if (_posts.isEmpty) return const Text('Aucun poste configuré');
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _posts.map((post) => Chip(
        label: Text(post.label),
        onDeleted: () {
          _postBox.remove(post.id);
          _loadData();
        },
      )).toList(),
    );
  }

// Removed _buildTierList
}
