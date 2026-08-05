import 'package:flutter/material.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';

class CategoryCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: widget.imageUrl.isNotEmpty
                        ? Image.file(
                            File(widget.imageUrl),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.surface2,
                            child: const Icon(Icons.category,
                                size: 50, color: AppColors.ink4),
                          ),
                  ),
                  if (widget.onEdit != null || widget.onDelete != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface0.withAlpha(230),
                          borderRadius: AppRadius.rMd,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onEdit != null)
                              GestureDetector(
                                onTap: widget.onEdit,
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.edit,
                                      size: 14, color: AppColors.primary),
                                ),
                              ),
                            if (widget.onDelete != null)
                              GestureDetector(
                                onTap: widget.onDelete,
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.delete,
                                      size: 14, color: AppColors.danger),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2, vertical: AppSpacing.space2),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.ink0,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
