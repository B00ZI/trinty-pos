import 'package:flutter/material.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/widgets/product_item.dart';
import 'package:objectbox/objectbox.dart';

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
      
      _productBox.put(product);
      
      _nameController.clear();
      _priceController.clear();
      _categoryController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(originalProduct == null ? 'Product added successfully!' : 'Product updated successfully!')),
      );
    }
  }

  void _deleteProduct(Product product) {
    _productBox.remove(product.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${product.name}')),
    );
  }

  void _showProductDialog(BuildContext context, [Product? product]) {
    if (product != null) {
      _nameController.text = product.name;
      _priceController.text = product.price.toString();
      _categoryController.text = product.category ?? '';
    } else {
      _nameController.clear();
      _priceController.clear();
      _categoryController.clear();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product == null ? 'Add New Product' : 'Edit Product'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: "e.g. 'Extra', 'Drink', 'Food'",
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
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
            child: Text(product == null ? 'Add' : 'Update'),
          ),
        ],
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!;

          return products.isEmpty
              ? const Center(
                  child: Text(
                    'No products available',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
