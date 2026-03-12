import 'package:flutter/material.dart';

class PaymentDialog extends StatefulWidget {
  final double totalAmount;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
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
      title: const Text('Paiement de la Commande'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total section
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Total de la Commande',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.totalAmount.toStringAsFixed(2)} DH',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Amount input
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant Reçu',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Change calculation display
            if (_changeStatus.isNotEmpty)
              Card(
                color: _calculatedChange >= 0
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _changeStatus,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _calculatedChange >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_calculatedChange.abs().toStringAsFixed(2)} DH',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: _calculatedChange >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
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
          onPressed: _amountController.text.isEmpty
              ? null
              : () => Navigator.pop(context, true),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
