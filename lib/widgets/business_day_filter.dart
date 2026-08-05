import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class BusinessDayFilter extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const BusinessDayFilter({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4, vertical: AppSpacing.space2),
      decoration: const BoxDecoration(
        color: AppColors.surface0,
        border: Border(bottom: BorderSide(color: AppColors.surface3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadius.rMd,
            ),
            child: IconButton(
              icon: const Icon(Icons.chevron_left, size: 18, color: AppColors.ink3),
              padding: EdgeInsets.zero,
              onPressed: () => onDateChanged(selectedDate.subtract(const Duration(days: 1))),
            ),
          ),
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2101),
              );
              if (picked != null) {
                onDateChanged(picked);
              }
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: AppColors.ink3),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  DateFormat('dd/MM/yyyy').format(selectedDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.ink0,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadius.rMd,
            ),
            child: IconButton(
              icon: const Icon(Icons.chevron_right, size: 18, color: AppColors.ink3),
              padding: EdgeInsets.zero,
              onPressed: () => onDateChanged(selectedDate.add(const Duration(days: 1))),
            ),
          ),
        ],
      ),
    );
  }
}
