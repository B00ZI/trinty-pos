import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:Easify/service/money_parser.dart';
import 'package:Easify/service/input_rules.dart';
import 'package:Easify/providers/dashboard_provider.dart';
import 'package:Easify/widgets/admin_pin_dialog.dart';
import 'package:Easify/theme/app_colors.dart';
import 'package:Easify/theme/app_spacing.dart';
import 'package:Easify/theme/app_radius.dart';

class ManagementScreen extends ConsumerStatefulWidget {
  const ManagementScreen({super.key});

  @override
  ConsumerState<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends ConsumerState<ManagementScreen> {
  int _currentIndex = 0;
  late final DataBackupService _backupService;

  @override
  void initState() {
    super.initState();
    _backupService = DataBackupService(ref.read(objectBoxProvider));
  }

  /// P26: which slices of the shop the owner can tick in the export dialog.
  static const Map<String, String> _sectionLabels = {
    'catalogue': 'Produits & catégories',
    'orders': 'Commandes & tickets',
    'users': 'Utilisateurs',
    'expenses': 'Dépenses',
    'funds': 'Fond de caisse',
    'games': 'Jeux & parties',
    'settings': 'Réglages boutique & imprimantes',
  };

  static const Map<String, String> _countLabels = {
    'orders': 'commandes',
    'products': 'produits',
    'categories': 'catégories',
    'users': 'utilisateurs',
    'expenses': 'dépenses',
    'funds': 'fonds de caisse',
    'gameSessions': 'parties de jeu',
    'gamePosts': 'postes de jeu',
    'partyTiers': 'paliers',
    'printerConfigs': 'configs imprimante',
    'settings': 'réglages boutique',
  };

  /// One button (P26) → this dialog with the two actions.
  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        title: const Text('Sauvegarde'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Que voulez-vous faire ?',
              style: TextStyle(fontSize: 13, color: AppColors.ink3),
            ),
            SizedBox(height: AppSpacing.space4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                label: const Text('Exporter'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showExportOptions();
                },
              ),
            ),
            SizedBox(height: AppSpacing.space3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 20),
                label: const Text('Importer'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _importData();
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// "Que voulez-vous exporter ?" — everything (recommended) or a selection.
  void _showExportOptions() {
    final selected = <String, bool>{
      for (final key in _sectionLabels.keys) key: true,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final all = selected.values.every((v) => v);
          return AlertDialog(
            backgroundColor: AppColors.surface0,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
            title: const Text('Que voulez-vous exporter ?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: all,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Tout (recommandé)',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    onChanged: (v) => setDialogState(() {
                      for (final key in _sectionLabels.keys) {
                        selected[key] = v ?? true;
                      }
                    }),
                  ),
                  const Divider(),
                  for (final entry in _sectionLabels.entries)
                    CheckboxListTile(
                      value: selected[entry.key],
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(entry.value,
                          style: const TextStyle(fontSize: 13)),
                      onChanged: all
                          ? null
                          : (v) => setDialogState(
                              () => selected[entry.key] = v ?? false),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentYellow,
                  foregroundColor: AppColors.payNowText,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportData(BackupSections.fromMap(selected));
                },
                child: const Text('Exporter la sélection'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportData(BackupSections sections) async {
    try {
      final jsonString = _backupService.exportData(sections: sections);
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/easify_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

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

      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      // P26: ask "what will be replaced?" BEFORE writing anything.
      final preview = _backupService.previewImport(jsonString);
      if (!mounted) return;
      final confirmed = await _confirmImport(preview);
      if (confirmed != true || !mounted) return;

      final importResult = _backupService.importData(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import réussi : ${_summaryCounts(importResult)}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur import: $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  Future<bool?> _confirmImport(Map<String, int> preview) {
    final legacy = preview['legacy'] == 1;
    final lines = <String>[
      for (final e in preview.entries)
        if (e.key != 'legacy' && e.value > 0)
          '• ${e.value} ${_countLabels[e.key] ?? e.key}',
    ];
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        title: const Text('Importer cette sauvegarde ?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                legacy
                    ? 'Ancienne sauvegarde : produits et catégories uniquement.'
                    : 'Ce fichier contient :',
                style: const TextStyle(fontSize: 13, color: AppColors.ink2),
              ),
              if (!legacy && lines.isNotEmpty) ...[
                SizedBox(height: AppSpacing.space2),
                Text(lines.join('\n'),
                    style: const TextStyle(fontSize: 13, color: AppColors.ink0)),
              ],
              SizedBox(height: AppSpacing.space4),
              const Text(
                'Ces données seront ajoutées ou remplacées dans la base. '
                'Les commandes et dépenses déjà présentes ne sont jamais '
                'écrasées. Cette action est irréversible.',
                style: TextStyle(fontSize: 12, color: AppColors.ink3),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.surface0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }

  String _summaryCounts(Map<String, int> counts) {
    final parts = <String>[
      for (final e in counts.entries)
        if (e.key != 'legacy' && e.value > 0)
          '${e.value} ${_countLabels[e.key] ?? e.key}',
    ];
    return parts.isEmpty ? 'rien à importer' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? AppSpacing.space2 : AppSpacing.space4,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface0,
                border: Border(bottom: BorderSide(color: AppColors.surface3, width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back button + tabs + icons on one row
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                          color: AppColors.ink0,
                          onPressed: () => context.pop(),
                        ),
                        // Tabs centered
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildNavIcon(0, Icons.inventory_2, 'Produits'),
                              SizedBox(width: isMobile ? AppSpacing.space6 : AppSpacing.space10),
                              _buildNavIcon(1, Icons.category, 'Catégories'),
                            ],
                          ),
                        ),
                        // P26: ONE backup button → dialog with Exporter /
                        // Importer (was two bare icons that looked like a
                        // full backup and asked no questions).
                        IconButton(
                          icon: Icon(Icons.import_export_rounded,
                              color: AppColors.primary, size: isMobile ? 20 : 24),
                          tooltip: 'Sauvegarde',
                          onPressed: _showBackupDialog,
                          padding: EdgeInsets.all(isMobile ? 8 : 12),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  const ProductsListSection(),
                  const CategoriesListSection(),
                ],
              ),
            ),
          ],
        ),
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
              color: isSelected ? AppColors.primary : AppColors.ink3),
          Text(label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.ink3,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              )),
          if (isSelected)
            Container(
                height: 2,
                width: 20,
                margin: EdgeInsets.only(top: AppSpacing.space1),
                color: AppColors.primary),
        ],
      ),
    );
  }
}

class ProductsListSection extends ConsumerStatefulWidget {
  const ProductsListSection({super.key});

  @override
  ConsumerState<ProductsListSection> createState() =>
      _ProductsListSectionState();
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

  @override
  void dispose() {
    // P44: the product dialog fields must not outlive this section.
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _showProductDialog([Product? product]) {
    // P30: name must be unique (a duplicate name broke the category dropdown
    // and made backup-by-name ambiguous) — snapshot taken when the dialog opens.
    final existingNames =
        _productBox.getAll().map((p) => p.name).toList(growable: false);
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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nom requis';
                        // P30: never two products with the same name.
                        return InputRules.uniqueName(v, existingNames,
                            excluding: product?.name);
                      }),
                  SizedBox(height: AppSpacing.space4),
                  TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Prix'),
                      keyboardType: TextInputType.number,
                      // P30: 0 is allowed (free product), negative never.
                      validator: (v) =>
                          InputRules.nonNegativePrice(v ?? '')),
                  SizedBox(height: AppSpacing.space4),
                  DropdownButtonFormField<String>(
                    value: () {
                      final selected = _categoryController.text;
                      if (selected.isEmpty) return null;
                      if (selected == 'Extra') return selected;
                      // P59: only show a category that still exists — a
                      // deleted (or duplicated) category used to crash this
                      // dialog with a red assertion screen.
                      final exists = ref
                          .read(objectBoxProvider)
                          .store
                          .box<Category>()
                          .getAll()
                          .any((cat) => cat.name == selected);
                      return exists ? selected : null;
                    }(),
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: [
                      const DropdownMenuItem(
                          value: 'Extra', child: Text('Supplément')),
                      ...(() {
                        final cats = ref
                            .read(objectBoxProvider)
                            .store
                            .box<Category>()
                            .getAll();
                        cats.sort(
                            (a, b) => a.displayOrder.compareTo(b.displayOrder));
                        // P59: collapse duplicate names to a single entry —
                        // two categories with the same name crashed the list.
                        final seenNames = <String>{};
                        return cats
                            .where((cat) => seenNames.add(cat.name))
                            .map((cat) => DropdownMenuItem(
                                value: cat.name, child: Text(cat.name)));
                      })(),
                    ],
                    onChanged: (v) => setDialogState(
                        () => _categoryController.text = v ?? ''),
                  ),
                  SizedBox(height: AppSpacing.space4),
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
                    p.name = _nameController.text.trim();
                    p.price = MoneyParser.parse(_priceController.text)!;
                    p.category = _categoryController.text.isNotEmpty
                        ? _categoryController.text
                        : null;
                    p.imageUrl = _selectedImagePath;
                    _productBox.put(p);
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentYellow,
                  foregroundColor: AppColors.payNowText,
                ),
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
            border: Border.all(color: AppColors.ink5),
            borderRadius: AppRadius.rMd),
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
              backgroundColor: AppColors.surface2,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _deselectProduct,
              ),
              title: Text(_selectedProduct!.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.info),
                  onPressed: () {
                    final p = _selectedProduct;
                    _deselectProduct();
                    _showProductDialog(p);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.danger),
                  onPressed: () async {
                    // Deleting a product is a destructive admin action (P06):
                    // same gate as history cleanup.
                    final isAdmin = await AdminPinDialog.verify(
                        context, ref.read(objectBoxProvider));
                    if (!context.mounted) return;
                    if (!isAdmin) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Suppression annulée : code administrateur requis')),
                      );
                      return;
                    }
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
                                  style: TextStyle(color: AppColors.danger))),
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
            padding: EdgeInsets.only(bottom: AppSpacing.space10),
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
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.surface0),
      ),
    );
  }
}

class CategoriesListSection extends ConsumerStatefulWidget {
  const CategoriesListSection({super.key});

  @override
  ConsumerState<CategoriesListSection> createState() =>
      _CategoriesListSectionState();
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

  @override
  void dispose() {
    // P44: the category dialog field must not outlive this section.
    _nameController.dispose();
    super.dispose();
  }

  void _showCategoryDialog([Category? cat]) {
    // P30: duplicate category names were the seed of the old red-screen
    // crash (P59) — never two categories with the same name.
    final existingNames =
        _categoryBox.getAll().map((c) => c.name).toList(growable: false);
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requis';
                        return InputRules.uniqueName(v, existingNames,
                            excluding: cat?.name);
                      }),
                  SizedBox(height: AppSpacing.space4),
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
                    final newCat = Category(
                        id: cat?.id ?? 0,
                        name: _nameController.text.trim(),
                        imageUrl: _selectedImagePath);
                    _categoryBox.put(newCat);
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentYellow,
                  foregroundColor: AppColors.payNowText,
                ),
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
            border: Border.all(color: AppColors.ink5),
            borderRadius: AppRadius.rMd),
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
          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              double aspectRatio;
              if (constraints.maxWidth < 600) {
                crossAxisCount = 2;
                aspectRatio = 0.85;
              } else if (constraints.maxWidth <= 900) {
                crossAxisCount = 3;
                aspectRatio = 0.8;
              } else {
                crossAxisCount = 4;
                aspectRatio = 0.75;
              }
              return ReorderableGridView.builder(
                padding: EdgeInsets.all(AppSpacing.space3),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: AppSpacing.space2,
                    mainAxisSpacing: AppSpacing.space2),
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
                    onDelete: () async {
                      // Deleting a category unlinks its products (P06/P21):
                      // destructive → admin PIN.
                      final isAdmin = await AdminPinDialog.verify(
                          context, ref.read(objectBoxProvider));
                      if (!context.mounted) return;
                      if (!isAdmin) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Suppression annulée : code administrateur requis')),
                        );
                        return;
                      }
                      _categoryBox.remove(c.id);
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.surface0),
      ),
    );
  }
}
