import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;
  final IconData? icon;
  final String? trendText;
  final bool isPositive;
  final String? comparisonLabel;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    this.color,
    this.icon,
    this.trendText,
    this.isPositive = true,
    this.comparisonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.space1, horizontal: AppSpacing.space1),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.surface3),
        boxShadow: AppShadows.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: themeColor.withAlpha(30),
                      borderRadius: AppRadius.rMd,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: themeColor,
                    ),
                  ),
                if (trendText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2, vertical: AppSpacing.space1),
                    decoration: BoxDecoration(
                      color: (isPositive ? AppColors.success : AppColors.danger).withAlpha(25),
                      borderRadius: AppRadius.rFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: isPositive ? AppColors.success : AppColors.danger,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          trendText!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPositive ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.ink3,
              ),
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.ink0,
              ),
            ),
            if (comparisonLabel != null) ...[
              const SizedBox(height: AppSpacing.space1),
              Text(
                comparisonLabel!,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.ink4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
