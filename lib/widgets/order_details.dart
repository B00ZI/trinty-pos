import 'package:flutter/material.dart';

class OrderDetails extends StatelessWidget {
  final bool isTakeAway;
  final ValueChanged<bool?> onTakeAwayChanged;
  final VoidCallback onCommentPressed;

  const OrderDetails({
    super.key,
    required this.isTakeAway,
    required this.onTakeAwayChanged,
    required this.onCommentPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Radio<bool>(
                  visualDensity: VisualDensity.compact,
                  value: true,
                  groupValue: isTakeAway,
                  onChanged: (value) => onTakeAwayChanged(value),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onTakeAwayChanged(!isTakeAway),
                child: Text(
                  'In House',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: onCommentPressed,
            icon: Icon(
              Icons.message_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
