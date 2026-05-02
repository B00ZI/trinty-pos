import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_post.dart';
import '../models/party_tier.dart';
import '../objectbox.dart';
import 'package:objectbox/objectbox.dart';

class GamesSettingsSection extends StatefulWidget {
  final ObjectBox objectbox;
  const GamesSettingsSection({super.key, required this.objectbox});

  @override
  State<GamesSettingsSection> createState() => _GamesSettingsSectionState();
}

class _GamesSettingsSectionState extends State<GamesSettingsSection> {
  late final Box<GamePost> _postBox;
  late final Box<PartyTier> _tierBox;
  List<GamePost> _posts = [];
  List<PartyTier> _tiers = [];

  @override
  void initState() {
    super.initState();
    _postBox = widget.objectbox.gamePostBox;
    _tierBox = widget.objectbox.partyTierBox;
    _loadData();
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
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Ajouter')),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarif Horaire Global', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rateController,
                    decoration: const InputDecoration(labelText: 'Prix par Heure (DH)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    final rate = double.tryParse(rateController.text);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Gestion des Postes', _addPost),
          const SizedBox(height: 16),
          _buildPostList(),
          const SizedBox(height: 40),
          _buildTierSection(),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Ajouter')),
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
