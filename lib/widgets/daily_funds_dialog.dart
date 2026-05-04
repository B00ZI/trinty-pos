import 'package:flutter/material.dart';
import '../models/daily_funds.dart';

class DailyFundsDialog extends StatefulWidget {
  final DailyFunds? currentFunds;
  final bool isAlreadySet;
  final Function(double) onSave;

  const DailyFundsDialog({
    super.key,
    required this.currentFunds,
    this.isAlreadySet = false,
    required this.onSave,
  });

  @override
  State<DailyFundsDialog> createState() => _DailyFundsDialogState();
}

class _DailyFundsDialogState extends State<DailyFundsDialog> {
  late TextEditingController _controller;
  bool _alreadySetForToday = false;

  @override
  void initState() {
    super.initState();
    _alreadySetForToday = widget.isAlreadySet;
    _controller = TextEditingController(
      text: widget.currentFunds != null ? widget.currentFunds!.amount.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    final amount = double.tryParse(_controller.text) ?? 0.0;
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
            if (_alreadySetForToday)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400, width: 1),
                ),
                child: Text(
                  'Fond de caisse déjà défini pour aujourd\'hui',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.amber.shade900,
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
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
