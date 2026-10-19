import 'package:flutter/material.dart';
import '../models/daily_funds.dart';
import '../service/money_parser.dart';
import '../theme/app_colors.dart';

class DailyFundsDialog extends StatefulWidget {
  final DailyFunds? currentFunds;
  final Function(double) onSave;

  const DailyFundsDialog({
    super.key,
    required this.currentFunds,
    required this.onSave,
  });

  @override
  State<DailyFundsDialog> createState() => _DailyFundsDialogState();
}

class _DailyFundsDialogState extends State<DailyFundsDialog> {
  late TextEditingController _controller;
  bool _alreadySet = false;

  @override
  void initState() {
    super.initState();
    _alreadySet = widget.currentFunds != null;
    _controller = TextEditingController(
      text: _alreadySet ? widget.currentFunds!.amount.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    // P18: no more silent 0.00 — comma accepted, garbage refuses to save.
    final amount = MoneyParser.parse(_controller.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Montant invalide — tapez un nombre, ex: 12,5')),
      );
      return;
    }
    widget.onSave(amount);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Fond de caisse',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_alreadySet)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentYellowLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentYellow, width: 1),
                ),
                child: Text(
                  'Fond de caisse déjà défini pour aujourd\'hui',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.payNowText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant (DH)',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentYellow,
            foregroundColor: AppColors.payNowText,
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
