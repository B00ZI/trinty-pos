import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../objectbox.dart';

class UserSelectionDialog extends StatefulWidget {
  final ObjectBox objectbox;
  final bool isCancelable;

  const UserSelectionDialog({
    super.key,
    required this.objectbox,
    this.isCancelable = true,
  });

  @override
  State<UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<UserSelectionDialog> with SingleTickerProviderStateMixin {
  AppUser? _selectedUser;
  String _enteredPin = "";
  bool _isError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitTap(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _isError = false;
      });
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isError = false;
      });
    }
  }

  void _verifyPin() {
    if (_selectedUser != null && _selectedUser!.verifyPin(_enteredPin)) {
      Navigator.pop(context, _selectedUser);
    } else {
      _shakeController.forward();
      setState(() {
        _isError = true;
        _enteredPin = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isCancelable,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: _selectedUser == null ? _buildUserSelection() : _buildPinEntry(),
        ),
      ),
    );
  }

  Widget _buildUserSelection() {
    final users = widget.objectbox.userBox.getAll();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sélectionner un utilisateur', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        if (users.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Aucun utilisateur configuré'),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(user.name[0].toUpperCase())),
                    title: Text(user.name),
                    onTap: () => setState(() => _selectedUser = user),
                  ),
                );
              },
            ),
          ),
        if (widget.isCancelable)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
      ],
    );
  }

  Widget _buildPinEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedUser = null;
                _enteredPin = "";
                _isError = false;
              }),
            ),
            Expanded(
              child: Text(
                'Bonjour, ${_selectedUser!.name}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48), // Spacer for centering
          ],
        ),
        const SizedBox(height: 8),
        const Text('Entrez votre PIN', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _enteredPin.length
                          ? (_isError ? Colors.red : Theme.of(context).colorScheme.primary)
                          : Colors.grey.shade300,
                      border: _isError && index < _enteredPin.length
                          ? Border.all(color: Colors.red.shade900, width: 2)
                          : null,
                    ),
                  );
                }),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        _buildNumericKeypad(),
      ],
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        for (var row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((digit) => _buildKeypadButton(digit)).toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('⌫', isAction: true, onTap: _onBackspace),
            _buildKeypadButton('0'),
            _buildKeypadButton('✓', isAction: true, onTap: _verifyPin, color: Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String label, {bool isAction = false, VoidCallback? onTap, Color? color}) {
    return InkWell(
      onTap: onTap ?? () => _onDigitTap(label),
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color?.withOpacity(0.1) ?? (isAction ? Colors.grey.shade100 : null),
          border: Border.all(color: color?.withOpacity(0.5) ?? Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color ?? (isAction ? Colors.grey.shade700 : null),
            ),
          ),
        ),
      ),
    );
  }
}
