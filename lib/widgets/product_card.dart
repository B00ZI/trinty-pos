import 'package:flutter/material.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';

class ProductCard extends StatefulWidget {
  final String title;
  final double price;
  final String imageUrl;
  final VoidCallback onAdd;

  const ProductCard({
    super.key,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.onAdd,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onAdd,
      onTapDown: (_) => setState(() => _hovering = true),
      onTapUp: (_) => setState(() => _hovering = false),
      onTapCancel: () => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.surface0,
          borderRadius: AppRadius.rLg,
          border: Border.all(
            color: _hovering ? AppColors.primary : AppColors.surface3,
            width: _hovering ? 1.5 : 1,
          ),
          boxShadow: _hovering ? AppShadows.md : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: widget.imageUrl.isNotEmpty
                    ? Image.file(
                        File(widget.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.surface2,
                        child: const Icon(Icons.image, size: 50, color: AppColors.ink4),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.ink0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    '${widget.price.toStringAsFixed(2)} DH',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
