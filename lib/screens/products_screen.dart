import 'package:flutter/material.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/widgets/product_item.dart';
import 'package:objectbox/objectbox.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:Easify/models/catigory.dart';

class ProductsScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const ProductsScreen({super.key, required this.objectbox});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final Box<Product> _productBox;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _selectedImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _productBox = widget.objectbox.store.box<Product>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _saveProduct(Product? originalProduct) {
    if (_formKey.currentState!.validate()) {
      final product = originalProduct ?? Product(name: '', price: 0);
      product.name = _nameController.text;
      product.price = double.parse(_priceController.text);
      product.category = _categoryController.text.isNotEmpty ? _categoryController.text : null;
      product.imageUrl = _selectedImagePath;
      
      _productBox.put(product);
      
      _nameController.clear();
      _priceController.clear();
      _categoryController.clear();
      setState(() {
        _selectedImagePath = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(originalProduct == null ? 'Produit ajouté avec succès !' : 'Produit mis à jour avec succès !')),
        );
      }
    }
  }

  void _deleteProduct(Product product) {
    _productBox.remove(product.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Supprimé ${product.name}')),
    );
  }

  void _showProductDialog(BuildContext context, [Product? product]) {
    if (product != null) {
      _nameController.text = product.name;
      _priceController.text = product.price.toString();
      _categoryController.text = product.category ?? '';
      _selectedImagePath = product.imageUrl;
    } else {
      _nameController.clear();
      _priceController.clear();
      _categoryController.clear();
      _selectedImagePath = null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: Text(product == null ? 'Ajouter un Nouveau Produit' : 'Modifier le Produit'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom du Produit'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un nom de produit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Prix'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un prix';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Veuillez entrer un nombre valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: [
                    const DropdownMenuItem(value: 'Extra', child: Text('Supplément')),
                    ...widget.objectbox.store.box<Catigory>().getAll().map((cat) => DropdownMenuItem(
                      value: cat.name,
                      child: Text(cat.name),
                    )),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _categoryController.text = value ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Image du Produit', style: TextStyle(fontWeight: FontWeight.bold)),
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
                if (_selectedImagePath != null)
                   TextButton.icon(
                     onPressed: () {
                        setDialogState(() {
                           _selectedImagePath = null;
                        });
                        setState(() {
                           _selectedImagePath = null;
                        });
                     }, 
                     icon: const Icon(Icons.delete, color: Colors.red), 
                     label: const Text('Supprimer l\'Image', style: TextStyle(color: Colors.red))
                   )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _saveProduct(product);
                Navigator.of(ctx).pop();
              }
            },
            child: Text(product == null ? 'Ajouter' : 'Mettre à jour'),
          ),
        ],
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     
      body: StreamBuilder<List<Product>>(
        stream: _productBox
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

          final products = snapshot.data!;

          return products.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun produit disponible',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: products.length,
                  itemBuilder: (ctx, index) => ProductItem(
                    product: products[index],
                    onAddToCart: (product) {}, // Not used in management screen
                    onDelete: _deleteProduct, // Delete enabled here
                    onEdit: (product) => _showProductDialog(context, product),
                  ),
                );
        },
      ),
      // Add Floating Action Button at bottom right with orange accent
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}
