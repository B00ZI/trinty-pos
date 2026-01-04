import 'package:flutter/material.dart';
import '../models/expence.dart';
import '../objectbox.g.dart';

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
  final Box<expence> expenceBox;
  final String buttonText;
  final String dialogTitle;
  final String emptyListMessage;
  final Color? buttonColor;
  final TextStyle? buttonTextStyle;
  final ValueChanged<List<expence>>? onListChanged;

  const AddableListWidget({
    super.key,
    required this.expenceBox,
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
  final List<expence> _todayExpenses =
      []; // Store expence objects from database
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
    final query = widget.expenceBox
        .query(expence_.date.between(
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
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(widget.dialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _titleController.clear();
                _amountController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addItem,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addItem() {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();

    if (title.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Create and save new expense
    final newexpence = expence(
      title: title,
      amount: amount,
      date: DateTime.now(),
    );

    widget.expenceBox.put(newexpence);

    // Reload today's expenses
    _loadTodayExpenses();

    _titleController.clear();
    _amountController.clear();
    Navigator.of(context).pop();
  }

  void _removeItem(int index) {
    final expenseToRemove = _todayExpenses[index];
    widget.expenceBox.remove(expenseToRemove.id); // Remove from database
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
        ElevatedButton(
          onPressed: _showAddDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                Colors.orangeAccent, // Use provided button color or default
          ),
          child: Text(
            widget.buttonText,
            style: widget.buttonTextStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),

        const SizedBox(height: 16),

        // Items List - Show today's expenses from database
        Expanded(
          child: _todayExpenses.isEmpty
              ? Center(
                  child: Text(
                    widget.emptyListMessage,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Added: ${_formatDate(item.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${item.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
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
