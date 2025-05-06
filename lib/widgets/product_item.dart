import 'package:flutter/material.dart';
import '../models.dart';

class ProductItem extends StatelessWidget {
  final Product product;
  final void Function(Product) onAddToCart;

  const ProductItem({
    Key? key,
    required this.product,
    required this.onAddToCart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => onAddToCart(product),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '\$${product.price.toStringAsFixed(2)}', // Escaped dollar sign
                style: TextStyle(fontSize: 16, color: Colors.green[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
