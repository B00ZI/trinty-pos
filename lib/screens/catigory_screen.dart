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

  void _saveCatigory() {
    if (_formKey.currentState!.validate()) {
      final catigory = Catigory(
        name: _nameController.text,
        imageUrl: _selectedImagePath,
      );
      
      _catigoryBox.put(catigory);
      
      _nameController.clear();
      setState(() {
        _selectedImagePath = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category added successfully!')),
        );
      }
    }
  }

  void _showAddDialog() {
    _nameController.clear();
    _selectedImagePath = null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Category'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Category Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Category Image', style: TextStyle(fontWeight: FontWeight.bold)),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _saveCatigory();
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add'),
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data!;

          return categories.isEmpty
              ? const Center(child: Text('No categories available'))
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => OrderScreen(
                              objectbox: widget.objectbox,
                              initialCategory: cat.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}
