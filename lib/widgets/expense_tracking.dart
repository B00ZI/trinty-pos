import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../objectbox.g.dart';
import '../theme/app_colors.dart';

class ListItem {
  final String title;
  final double amount;
  final DateTime createdAt;

  ListItem({
    required this.title,
    required this.amount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() => '$title: \$${amount.toStringAsFixed(2)}';
}

class AddableListWidget extends StatefulWidget {
  final Box<Expense> expenseBox;
  final String buttonText;
  final String dialogTitle;
  final String emptyListMessage;
  final Color? buttonColor;
  final TextStyle? buttonTextStyle;
  final ValueChanged<List<Expense>>? onListChanged;

  const AddableListWidget({
    super.key,
    required this.expenseBox,
    this.buttonText = 'Add expense',
    this.dialogTitle = 'Add New expense',
    this.emptyListMessage = 'No expenses added yet',
    this.buttonColor,
    this.buttonTextStyle,
    this.onListChanged,
  });

  @override
  State<AddableListWidget> createState() => _AddableListWidgetState();
}

class _AddableListWidgetState extends State<AddableListWidget> {
  final List<Expense> _todayExpenses =
      []; // Store Expense objects from database
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodayExpenses(); // Load today's expenses on initialization
  }

  // Load expenses from database for today
  void _loadTodayExpenses() {
    final DateTime todayStart =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final DateTime todayEnd = todayStart.add(const Duration(days: 1));

    // Query expenses for today
    final query = widget.expenseBox
        .query(Expense_.date.between(
          todayStart.millisecondsSinceEpoch,
          todayEnd.millisecondsSinceEpoch,
        ))
        .build();
    final expenses = query.find();
    query.close();
    setState(() {
      _todayExpenses.clear();
      _todayExpenses.addAll(expenses);
    });

    // Notify parent if callback exists
    widget.onListChanged?.call(_todayExpenses);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_card_outlined,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.dialogTitle,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () {
                _titleController.clear();
                _amountController.clear();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => _addItem(dialogContext),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                foregroundColor: AppColors.payNowText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addItem(BuildContext dialogContext) {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();

    if (title.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.surface0, size: 18),
              const SizedBox(width: 8),
              const Text('Please fill in both fields'),
            ],
          ),
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.surface0, size: 18),
              const SizedBox(width: 8),
              const Text('Please enter a valid amount'),
            ],
          ),
        ),
      );
      return;
    }

    // Create and save new expense
    final newExpense = Expense(
      title: title,
      amount: amount,
      date: DateTime.now(),
    );

    widget.expenseBox.put(newExpense);

    // Reload today's expenses
    _loadTodayExpenses();

    _titleController.clear();
    _amountController.clear();
    Navigator.of(dialogContext).pop();
  }

  void _removeItem(int index) {
    final expenseToRemove = _todayExpenses[index];
    widget.expenseBox.remove(expenseToRemove.id); // Remove from database
    _loadTodayExpenses(); // Reload the list
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add Button
        FilledButton.icon(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            widget.buttonText,
            style: widget.buttonTextStyle ??
                const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: widget.buttonColor ??
                Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Items List - Show today's expenses from database
        Expanded(
          child: _todayExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.25),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.emptyListMessage,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _todayExpenses.length,
                  itemBuilder: (context, index) {
                    final expense = _todayExpenses[index];
                    return _ListItemCard(
                      item: ListItem(
                        title: expense.title,
                        amount: expense.amount,
                        createdAt: expense.date,
                      ),
                      onDelete: () => _removeItem(index),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ListItemCard extends StatelessWidget {
  final ListItem item;
  final VoidCallback onDelete;

  const _ListItemCard({
    required this.item,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.surface3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt_outlined, color: errorColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 12, color: AppColors.ink4),
                      const SizedBox(width: 4),
                      Text(
                        'Added: ${_formatDate(item.createdAt)}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.ink3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '\$${item.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: errorColor,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: errorColor),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}