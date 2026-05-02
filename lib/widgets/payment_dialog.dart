import 'package:flutter/material.dart';

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
                    if (widget.sessionDetails != null) ...[
                      Text(
                        widget.sessionDetails!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Total à Payer',
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
            if (!widget.isGameSession) ...[
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
            ],
            // Change calculation display
            if (!widget.isGameSession && _changeStatus.isNotEmpty)
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
          onPressed: (widget.isGameSession || _amountController.text.isNotEmpty)
              ? () => Navigator.pop(context, true)
              : null,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
