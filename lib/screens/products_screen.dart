import 'package:flutter/material.dart';
import 'package:Drywich/models/product.dart';
import 'package:Drywich/objectbox.dart';
import 'package:Drywich/widgets/product_item.dart';
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

  @override
  void initState() {
    super.initState();
    _productBox = widget.objectbox.store.box<Product>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addProduct() {
    if (_formKey.currentState!.validate()) {
      final product = Product(
        name: _nameController.text,
        price: double.parse(_priceController.text),
      );
      _productBox.put(product);
      _nameController.clear();
      _priceController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully!')),
      );
    }
  }

  void _deleteProduct(Product product) {
    _productBox.remove(product.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${product.name}')),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Product'),
        content: Form(
          key: _formKey,
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
            ],
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
                _addProduct();
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddProductDialog(context),
          ),
        ],
      ),
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
                  ),
                );
        },
      ),
    );
  }
}
