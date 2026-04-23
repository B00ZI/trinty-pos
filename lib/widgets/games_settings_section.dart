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

  Future<void> _addTier() async {
    final labelController = TextEditingController();
    final durationController = TextEditingController();
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un Palier'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label (ex: 1 Heure)'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Durée (minutes, 0 = ouvert)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Prix (DH)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v == null || double.tryParse(v) == null ? 'Prix invalide' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result == true) {
      _tierBox.put(PartyTier(
        label: labelController.text.trim(),
        durationMinutes: int.parse(durationController.text),
        price: double.parse(priceController.text),
      ));
      _loadData();
    }
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
          _buildHeader('Paliers de Temps', _addTier),
          const SizedBox(height: 16),
          _buildTierList(),
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

  Widget _buildTierList() {
    if (_tiers.isEmpty) return const Text('Aucun palier configuré');
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tiers.length,
      itemBuilder: (context, index) {
        final tier = _tiers[index];
        return Card(
          child: ListTile(
            title: Text(tier.label),
            subtitle: Text('${tier.durationMinutes == 0 ? "Ouvert" : "${tier.durationMinutes} min"} - ${tier.price.toStringAsFixed(2)} DH'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                _tierBox.remove(tier.id);
                _loadData();
              },
            ),
          ),
        );
      },
    );
  }
}
