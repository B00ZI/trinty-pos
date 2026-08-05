import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class PaymentDialog extends StatefulWidget {
  final double totalAmount;
  final String? sessionDetails;
  final bool isGameSession;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    this.sessionDetails,
    this.isGameSession = false,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late TextEditingController _amountController;
  double _calculatedChange = 0;
  String _changeStatus = '';

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _amountController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final amountText = _amountController.text;
    if (amountText.isEmpty) {
      setState(() {
        _calculatedChange = 0;
        _changeStatus = '';
      });
      return;
    }

    try {
      final amount = double.parse(amountText);
      setState(() {
        _calculatedChange = amount - widget.totalAmount;
        if (_calculatedChange >= 0) {
          _changeStatus = 'Monnaie à rendre';
        } else {
          _changeStatus = 'Montant manquant';
        }
      });
    } catch (e) {
      setState(() {
        _calculatedChange = 0;
        _changeStatus = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      elevation: 24,
      title: const Text(
        'Paiement de la Commande',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink0,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.space4),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: AppRadius.rMd,
              ),
              child: Column(
                children: [
                  if (widget.sessionDetails != null) ...[
                    Text(
                      widget.sessionDetails!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppColors.ink2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    const Divider(),
                    const SizedBox(height: AppSpacing.space2),
                  ],
                  const Text(
                    'Total à Payer',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.ink3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    '${widget.totalAmount.toStringAsFixed(2)} DH',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink0,
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.isGameSession) ...[
              const SizedBox(height: AppSpacing.space6),
              // Amount input
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink0,
                ),
                decoration: InputDecoration(
                  labelText: 'Montant Reçu',
                  prefixIcon: const Icon(Icons.attach_money, color: AppColors.ink3),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.rMd,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rMd,
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space6),
            ],
            // Change calculation display
            if (!widget.isGameSession && _changeStatus.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: _calculatedChange >= 0
                      ? AppColors.successLight
                      : AppColors.dangerLight,
                  borderRadius: AppRadius.rMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _changeStatus,
                      style: TextStyle(
                        fontSize: 14,
                        color: _calculatedChange >= 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Text(
                      '${_calculatedChange.abs().toStringAsFixed(2)} DH',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _calculatedChange >= 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: (widget.isGameSession || _amountController.text.isNotEmpty)
              ? () => Navigator.pop(context, true)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentYellow,
            foregroundColor: AppColors.payNowText,
          ),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
