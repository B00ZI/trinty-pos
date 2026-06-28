import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/models/category.dart';
import 'package:Easify/widgets/product_item.dart';
import 'package:objectbox/objectbox.dart';
import 'package:Easify/widgets/category_card.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:share_plus/share_plus.dart';
import 'package:Easify/service/data_backup_service.dart';
import 'package:Easify/providers/dashboard_provider.dart';

class ManagementScreen extends ConsumerStatefulWidget {
  const ManagementScreen({super.key});

  @override
  ConsumerState<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends ConsumerState<ManagementScreen> {
  int _currentIndex = 0; // 0 for Products, 1 for Categories
  late final DataBackupService _backupService;

  @override
  void initState() {
    super.initState();
    _backupService = DataBackupService(ref.read(objectBoxProvider));
  }

  Future<void> _exportData() async {
    try {
      final jsonString = _backupService.exportData();
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/easify_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      // Offer to share/save the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Sauvegarde Easify',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur export: $e')));
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final importResult = _backupService.importData(jsonString);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Import réussi: ${importResult['products']} produits, ${importResult['categories']} catégories'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur import: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            0, // We use a custom header or rely on MainScreen's app bar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavIcon(0, Icons.inventory_2, 'Produits'),
                    const SizedBox(width: 40),
                    _buildNavIcon(1, Icons.category, 'Catégories'),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.file_upload_outlined,
                          color: Colors.blue),
                      tooltip: 'Exporter',
                      onPressed: _exportData,
                    ),
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined,
                          color: Colors.green),
                      tooltip: 'Importer',
                      onPressed: _importData,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const ProductsListSection(),
          const CategoriesListSection(),
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
          Icon(icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey),
          Text(label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              )),
          if (isSelected)
            Container(
                height: 2,
                width: 20,
                margin: const EdgeInsets.only(top: 4),
                color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }
}

class ProductsListSection extends ConsumerStatefulWidget {
  const ProductsListSection({super.key});

  @override
  ConsumerState<ProductsListSection> createState() => _ProductsListSectionState();
}

class _ProductsListSectionState extends ConsumerState<ProductsListSection> {
  late final Box<Product> _productBox;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _selectedImagePath;
  final ImagePicker _picker = ImagePicker();
  Product? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _productBox = ref.read(objectBoxProvider).store.box<Product>();
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
                  TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Nom requis' : null),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Prix'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || double.tryParse(v) == null
                          ? 'Prix valide requis'
                          : null),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _categoryController.text.isNotEmpty
                        ? _categoryController.text
                        : null,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: [
                      const DropdownMenuItem(
                          value: 'Extra', child: Text('Supplément')),
                      ...(() {
                        final cats =
                            ref.read(objectBoxProvider).store.box<Category>().getAll();
                        cats.sort(
                            (a, b) => a.displayOrder.compareTo(b.displayOrder));
                        return cats.map((cat) => DropdownMenuItem(
                            value: cat.name, child: Text(cat.name)));
                      })(),
                    ],
                    onChanged: (v) => setDialogState(
                        () => _categoryController.text = v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  _buildImagePicker(setDialogState),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final p = product ?? Product(name: '', price: 0);
                    p.name = _nameController.text;
                    p.price = double.parse(_priceController.text);
                    p.category = _categoryController.text.isNotEmpty
                        ? _categoryController.text
                        : null;
                    p.imageUrl = _selectedImagePath;
                    _productBox.put(p);
                    Navigator.pop(ctx);
                  }
                },
                child: Text(product == null ? 'Ajouter' : 'Mettre à jour')),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(StateSetter setDialogState) {
    return GestureDetector(
      onTap: () async {
        final XFile? image =
            await _picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = path.basename(image.path);
          final localFile =
              await File(image.path).copy('${appDir.path}/$fileName');
          setDialogState(() => _selectedImagePath = localFile.path);
        }
      },
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8)),
        child: _selectedImagePath != null
            ? Image.file(File(_selectedImagePath!), fit: BoxFit.cover)
            : const Icon(Icons.add_a_photo),
      ),
    );
  }

  void _deselectProduct() {
    setState(() {
      _selectedProduct = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedProduct == null
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _deselectProduct,
              ),
              title: Text(_selectedProduct!.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    final p = _selectedProduct;
                    _deselectProduct();
                    _showProductDialog(p);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Supprimer Produit'),
                        content: Text(
                            'Voulez-vous vraiment supprimer ${_selectedProduct!.name} ?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Supprimer',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      _productBox.remove(_selectedProduct!.id);
                      _deselectProduct();
                    }
                  },
                ),
              ],
            ),
      body: StreamBuilder<List<Product>>(
        stream: _productBox
            .query()
            .watch(triggerImmediately: true)
            .map((q) => q.find()),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final products = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: products.length,
            itemBuilder: (ctx, i) {
              final product = products[i];
              return ProductItem(
                product: product,
                isSelected: _selectedProduct?.id == product.id,
                onAddToCart: (_) {
                  if (_selectedProduct != null) {
                    if (_selectedProduct?.id == product.id) {
                      _deselectProduct();
                    } else {
                      setState(() => _selectedProduct = product);
                    }
                  }
                },
                onLongPress: () {
                  setState(() => _selectedProduct = product);
                },
              );
            },
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

class CategoriesListSection extends ConsumerStatefulWidget {
  const CategoriesListSection({super.key});

  @override
  ConsumerState<CategoriesListSection> createState() => _CategoriesListSectionState();
}

class _CategoriesListSectionState extends ConsumerState<CategoriesListSection> {
  late final Box<Category> _categoryBox;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedImagePath;
  final ImagePicker _picker = ImagePicker();
  @override
  void initState() {
    super.initState();
    _categoryBox = ref.read(objectBoxProvider).store.box<Category>();
  }

  void _showCategoryDialog([Category? cat]) {
    _nameController.text = cat?.name ?? '';
    _selectedImagePath = cat?.imageUrl;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(cat == null ? 'Nouvelle Catégorie' : 'Modifier Catégorie'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null),
                const SizedBox(height: 16),
                _buildImagePicker(setDialogState),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final newCat = Category(
                        id: cat?.id ?? 0,
                        name: _nameController.text,
                        imageUrl: _selectedImagePath);
                    _categoryBox.put(newCat);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(StateSetter setDialogState) {
    return GestureDetector(
      onTap: () async {
        final XFile? image =
            await _picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = path.basename(image.path);
          final localFile =
              await File(image.path).copy('${appDir.path}/$fileName');
          setDialogState(() => _selectedImagePath = localFile.path);
        }
      },
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8)),
        child: _selectedImagePath != null
            ? Image.file(File(_selectedImagePath!), fit: BoxFit.cover)
            : const Icon(Icons.add_a_photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Category>>(
        stream: _categoryBox
            .query()
            .watch(triggerImmediately: true)
            .map((q) => q.find()),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final categories = snapshot.data!;
          categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
          return ReorderableGridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 0.7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                final cat = categories.removeAt(oldIndex);
                categories.insert(newIndex, cat);
                for (int i = 0; i < categories.length; i++) {
                  categories[i].displayOrder = i;
                }
                _categoryBox.putMany(categories);
              });
            },
            itemBuilder: (ctx, i) {
              final c = categories[i];
              return CategoryCard(
                key: ValueKey(c.id),
                title: c.name,
                imageUrl: c.imageUrl ?? '',
                onTap: () {},
                onEdit: () => _showCategoryDialog(c),
                onDelete: () => _categoryBox.remove(c.id),
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
