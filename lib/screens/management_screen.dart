import 'package:flutter/material.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/models/catigory.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/widgets/product_item.dart';
import 'package:Easify/widgets/catigory_card.dart';
import 'package:objectbox/objectbox.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ManagementScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const ManagementScreen({super.key, required this.objectbox});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  int _currentIndex = 0; // 0 for Products, 1 for Categories

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // We use a custom header or rely on MainScreen's app bar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNavIcon(0, Icons.inventory_2, 'Produits'),
              const SizedBox(width: 40),
              _buildNavIcon(1, Icons.category, 'Catégories'),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ProductsListSection(objectbox: widget.objectbox),
          CategoriesListSection(objectbox: widget.objectbox),
        ],
      ),
    );
  }

  Widget _buildNavIcon(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
          Text(label, style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          )),
          if (isSelected)
            Container(height: 2, width: 20, margin: const EdgeInsets.only(top: 4), color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }
}

class ProductsListSection extends StatefulWidget {
  final ObjectBox objectbox;
  const ProductsListSection({super.key, required this.objectbox});

  @override
  State<ProductsListSection> createState() => _ProductsListSectionState();
}

class _ProductsListSectionState extends State<ProductsListSection> {
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

  void _showProductDialog([Product? product]) {
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
          title: Text(product == null ? 'Ajouter Produit' : 'Modifier Produit'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom'), validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'Prix'), keyboardType: TextInputType.number, validator: (v) => v == null || double.tryParse(v) == null ? 'Prix valide requis' : null),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: [
                      const DropdownMenuItem(value: 'Extra', child: Text('Supplément')),
                      ...widget.objectbox.store.box<Catigory>().getAll().map((cat) => DropdownMenuItem(value: cat.name, child: Text(cat.name))),
                    ],
                    onChanged: (v) => setDialogState(() => _categoryController.text = v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  _buildImagePicker(setDialogState),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(onPressed: () {
              if (_formKey.currentState!.validate()) {
                final p = product ?? Product(name: '', price: 0);
                p.name = _nameController.text;
                p.price = double.parse(_priceController.text);
                p.category = _categoryController.text.isNotEmpty ? _categoryController.text : null;
                p.imageUrl = _selectedImagePath;
                _productBox.put(p);
                Navigator.pop(ctx);
              }
            }, child: Text(product == null ? 'Ajouter' : 'Mettre à jour')),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(StateSetter setDialogState) {
    return GestureDetector(
      onTap: () async {
        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = path.basename(image.path);
          final localFile = await File(image.path).copy('${appDir.path}/$fileName');
          setDialogState(() => _selectedImagePath = localFile.path);
        }
      },
      child: Container(
        height: 100, width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
        child: _selectedImagePath != null ? Image.file(File(_selectedImagePath!), fit: BoxFit.cover) : const Icon(Icons.add_a_photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Product>>(
        stream: _productBox.query().watch(triggerImmediately: true).map((q) => q.find()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final products = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: products.length,
            itemBuilder: (ctx, i) => ProductItem(
              product: products[i],
              onAddToCart: (_) {},
              onDelete: (p) => _productBox.remove(p.id),
              onEdit: (p) => _showProductDialog(p),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CategoriesListSection extends StatefulWidget {
  final ObjectBox objectbox;
  const CategoriesListSection({super.key, required this.objectbox});

  @override
  State<CategoriesListSection> createState() => _CategoriesListSectionState();
}

class _CategoriesListSectionState extends State<CategoriesListSection> {
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

  void _showCategoryDialog([Catigory? cat]) {
    _nameController.text = cat?.name ?? '';
    _selectedImagePath = cat?.imageUrl;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(cat == null ? 'Nouvelle Catégorie' : 'Modifier Catégorie'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom'), validator: (v) => v == null || v.isEmpty ? 'Requis' : null),
                const SizedBox(height: 16),
                _buildImagePicker(setDialogState),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(onPressed: () {
              if (_formKey.currentState!.validate()) {
                final newCat = Catigory(id: cat?.id ?? 0, name: _nameController.text, imageUrl: _selectedImagePath);
                _catigoryBox.put(newCat);
                Navigator.pop(ctx);
              }
            }, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(StateSetter setDialogState) {
    return GestureDetector(
      onTap: () async {
        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = path.basename(image.path);
          final localFile = await File(image.path).copy('${appDir.path}/$fileName');
          setDialogState(() => _selectedImagePath = localFile.path);
        }
      },
      child: Container(
        height: 100, width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
        child: _selectedImagePath != null ? Image.file(File(_selectedImagePath!), fit: BoxFit.cover) : const Icon(Icons.add_a_photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Catigory>>(
        stream: _catigoryBox.query().watch(triggerImmediately: true).map((q) => q.find()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final categories = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: categories.length,
            itemBuilder: (ctx, i) {
              final c = categories[i];
              return CatigoryCard(
                title: c.name,
                imageUrl: c.imageUrl ?? '',
                onTap: () {},
                onEdit: () => _showCategoryDialog(c),
                onDelete: () => _catigoryBox.remove(c.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
