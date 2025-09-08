import 'package:flutter/material.dart';

class Product {
  final String title;
  final String price;
  final String rank;
  final Color? rankColor;
  

  Product({
    required this.title,
    required this.price,
    required this.rank,
    this.rankColor,

  });
}

class ProductCardsRow extends StatelessWidget {
  final List<Product> products;
  final String sectionTitle;
  final TextStyle? titleStyle;
  final double cardWidth;
  final double cardHeight;
  final Color cardColor;
  final bool scrollable;

  const ProductCardsRow({
    super.key,
    required this.products,
    this.sectionTitle = 'Top Products',
    this.titleStyle,
    this.cardWidth = 120,
    this.cardHeight = 150,
    this.cardColor = Colors.white,
    this.scrollable = true,
  }) : assert(products.length >= 3, 'At least 3 products are required');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            sectionTitle,
            style: titleStyle ?? const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        // Products Row
        SizedBox(
          height: cardHeight,
          child: scrollable
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: products.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return SmallProductCard(
                      product: products[index],
                      width: cardWidth,
                      cardColor: cardColor,
                    );
                  },
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: products.take(3).map((product) {
                    return SmallProductCard(
                      product: product,
                      width: cardWidth,
                      cardColor: cardColor,
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class SmallProductCard extends StatelessWidget {
  final Product product;
  final double width;
  final Color cardColor;

  const SmallProductCard({
    super.key,
    required this.product,
    this.width = 120,
    this.cardColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Rank badge with optional icon
            Row(
              children: [
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (product.rankColor ?? Colors.blue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.rank,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: product.rankColor ?? Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            
            // Title
            Text(
              product.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Price
            Text(
              product.price,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}