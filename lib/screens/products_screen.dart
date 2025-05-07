import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';

import 'package:myApp/objectbox.dart' hide store, initObjectBox;
import '../models/product.dart';
import '../widgets/product_item.dart';

class ProductsScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const ProductsScreen({super.key, required this.objectbox});

  @override
  State<ProductsScreen> createState() => ProductsScreenState();
}





class ProductsScreenState extends State<ProductsScreen> {
  late final Box<Product> productBoxInstance;

  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _productPriceController = TextEditingController();

  void emptyFunction(Product product){

  }

  @override
  void initState() {
    super.initState();
    productBoxInstance = widget.objectbox.productBox;
  }


  @override
  void dispose() {
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _productPriceController.dispose();
    super.dispose();
  }

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Product'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _productNameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a product name';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _productDescriptionController,
                  decoration: const InputDecoration(labelText: 'Product Description'),
                ),
                TextFormField(
                  controller: _productPriceController,
                  decoration: const InputDecoration(labelText: 'Product Price'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a product price';
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
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // Create a Product object
                  final newProduct = Product(
                      name: _productNameController.text,
                      price: double.parse(_productPriceController.text),
                    );


                  productBoxInstance.put(newProduct);

                  // StreamBuilder handles updating the list

                  // Clear the form
                  _productNameController.clear();
                  _productDescriptionController.clear();
                  _productPriceController.clear();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product Added')),
                  );

                  Navigator.of(context).pop(); // Close the dialog
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
      ),
     body: StreamBuilder<List<Product>>(
       stream: productBoxInstance.query().watch(triggerImmediately: true).map((query) => query.find()),
       builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!;
                     if (products.isEmpty) {
            return Center(child: Text('No products yet. Add some!'));
          }

          return ListView.builder(
             itemCount: products.length,
             itemBuilder: (context, index) {
              final product = products[index];
              return ProductItem(product: product,onAddToCart:emptyFunction);
            },
          );
        },
      
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(context),
        child: const Icon(Icons.add),
      ),   
    );
  }
}

