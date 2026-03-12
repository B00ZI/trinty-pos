import 'package:flutter/material.dart';
import 'package:Easify/models/catigory.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/widgets/catigory_card.dart';
import 'package:Easify/screens/order_screen.dart';
import 'package:objectbox/objectbox.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CatigoryScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const CatigoryScreen({super.key, required this.objectbox});

  @override
  State<CatigoryScreen> createState() => _CatigoryScreenState();
}

class _CatigoryScreenState extends State<CatigoryScreen> {
  late final Box<Catigory> _catigoryBox;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _catigoryBox = widget.objectbox.store.box<Catigory>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCatigory([Catigory? catigory]) {
    if (_formKey.currentState!.validate()) {
      final newCatigory = Catigory(
        id: catigory?.id ?? 0,
        name: _nameController.text,
        imageUrl: _selectedImagePath,
      );
      
      _catigoryBox.put(newCatigory);
      
      _nameController.clear();
      setState(() {
        _selectedImagePath = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(catigory == null ? 'Catégorie ajoutée avec succès !' : 'Catégorie mise à jour !')),
        );
      }
    }
  }

  void _deleteCatigory(Catigory cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer la catégorie "${cat.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              _catigoryBox.remove(cat.id);
              Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Catégorie supprimée')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog([Catigory? catigory]) {
    _nameController.text = catigory?.name ?? '';
    _selectedImagePath = catigory?.imageUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(catigory == null ? 'Ajouter une Nouvelle Catégorie' : 'Modifier la Catégorie'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nom de la Catégorie'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un nom';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Image de la Catégorie', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        final appDir = await getApplicationDocumentsDirectory();
                        final fileName = path.basename(image.path);
                        final localFile = await File(image.path).copy('${appDir.path}/$fileName');
                        
                        setDialogState(() {
                          _selectedImagePath = localFile.path;
                        });
                        setState(() {
                           _selectedImagePath = localFile.path;
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _selectedImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_selectedImagePath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _saveCatigory(catigory);
                  Navigator.of(ctx).pop();
                }
              },
              child: Text(catigory == null ? 'Ajouter' : 'Mettre à jour'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Catigory>>(
        stream: _catigoryBox
            .query()
            .watch(triggerImmediately: true)
            .map((query) => query.find()),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data!;

          return categories.isEmpty
              ? const Center(child: Text('Aucune catégorie disponible'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (ctx, index) {
                    final cat = categories[index];
                    return CatigoryCard(
                      title: cat.name,
                      imageUrl: cat.imageUrl ?? '',
                      onTap: () {
                        // Navigator.of(context).push(
                        //   MaterialPageRoute(
                        //     builder: (context) => OrderScreen(
                        //       objectbox: widget.objectbox,
                        //       initialCategory: cat.name,
                        //     ),
                        //   ),
                        // );
                      },
                      onEdit: () => _showAddEditDialog(cat),
                      onDelete: () => _deleteCatigory(cat),
                    );
                  },
                );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}
