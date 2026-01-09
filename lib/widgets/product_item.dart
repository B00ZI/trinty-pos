import 'package:flutter/material.dart';
import 'package:Easify/models/product.dart';

class ProductItem extends StatelessWidget {
  final Product product;
  final void Function(Product) onAddToCart;
  final void Function(Product)? onDelete;
  final void Function(Product)? onEdit;

  const ProductItem({
    super.key,
    required this.product,
    required this.onAddToCart,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => onAddToCart(product),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.price.toStringAsFixed(2)} DH',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => onEdit!(product),
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => onDelete!(product),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
