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

class _UserSelectionDialogState extends State<UserSelectionDialog>
    with SingleTickerProviderStateMixin {
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
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
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
      // Transparently upgrade legacy (unsalted) PINs to salted hashes
      if (_selectedUser!.needsPinUpgrade) {
        final (hash, salt) = AppUser.hashPin(_enteredPin);
        _selectedUser!.pin = hash;
        _selectedUser!.pinSalt = salt;
        widget.objectbox.userBox.put(_selectedUser!);
      }
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
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    final bool isShort = screenHeight < 600;
    final bool isNarrow = screenWidth < 360;

    final double padding = isShort ? 12.0 : 24.0;
    final double dialogWidth = isNarrow ? (screenWidth * 0.9) : 400.0;

    return PopScope(
      canPop: widget.isCancelable,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(padding),
          child: _selectedUser == null
              ? _buildUserSelection(isShort)
              : _buildPinEntry(isShort, isNarrow),
        ),
      ),
    );
  }

  Widget _buildUserSelection(bool isShort) {
    final users = widget.objectbox.userBox.getAll();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sélectionner un utilisateur',
          style: isShort
              ? Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)
              : Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: isShort ? 12 : 24),
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
                    dense: isShort,
                    leading: CircleAvatar(
                      radius: isShort ? 16 : 20,
                      child: Text(user.name[0].toUpperCase()),
                    ),
                    title: Text(user.name),
                    onTap: () => setState(() => _selectedUser = user),
                  ),
                );
              },
            ),
          ),
        if (widget.isCancelable) ...[
          SizedBox(height: isShort ? 4 : 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ],
    );
  }

  Widget _buildPinEntry(bool isShort, bool isNarrow) {
    final double keySize = isShort ? 48.0 : 70.0;
    final double keySpacing = isShort ? 6.0 : 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: isShort ? 20 : 24,
              padding: EdgeInsets.zero,
              constraints: isShort
                  ? const BoxConstraints(minWidth: 32, minHeight: 32)
                  : null,
              onPressed: () => setState(() {
                _selectedUser = null;
                _enteredPin = "";
                _isError = false;
              }),
            ),
            Expanded(
              child: Text(
                'Bonjour, ${_selectedUser!.name}',
                style: isShort
                    ? Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)
                    : Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: isShort ? 32 : 48), // Spacer for centering
          ],
        ),
        SizedBox(height: isShort ? 4 : 8),
        Text(
          'Entrez votre PIN',
          style: TextStyle(
            color: Colors.grey,
            fontSize: isShort ? 12 : 14,
          ),
        ),
        SizedBox(height: isShort ? 12 : 24),
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final bool isFilled = index < _enteredPin.length;
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: isShort ? 8 : 12),
                    width: isShort ? 12 : 20,
                    height: isShort ? 12 : 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? (_isError
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary)
                          : Colors.grey.shade300,
                      border: _isError && isFilled
                          ? Border.all(color: Colors.red.shade900, width: 2)
                          : null,
                    ),
                  );
                }),
              ),
            );
          },
        ),
        SizedBox(height: isShort ? 16 : 32),
        _buildNumericKeypad(keySize, keySpacing),
      ],
    );
  }

  Widget _buildNumericKeypad(double keySize, double keySpacing) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9']
        ])
          Padding(
            padding: EdgeInsets.only(bottom: keySpacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row
                  .map((digit) => _buildKeypadButton(digit, keySize))
                  .toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('⌫', keySize,
                isAction: true, onTap: _onBackspace),
            _buildKeypadButton('0', keySize),
            _buildKeypadButton('✓', keySize,
                isAction: true, onTap: _verifyPin, color: Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String label, double keySize,
      {bool isAction = false, VoidCallback? onTap, Color? color}) {
    return InkWell(
      onTap: onTap ?? () => _onDigitTap(label),
      borderRadius: BorderRadius.circular(keySize / 2),
      child: Container(
        width: keySize,
        height: keySize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color?.withValues(alpha: 0.1) ??
              (isAction ? Colors.grey.shade100 : null),
          border: Border.all(
              color: color?.withValues(alpha: 0.5) ?? Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: keySize * 0.35,
              fontWeight: FontWeight.bold,
              color: color ?? (isAction ? Colors.grey.shade700 : null),
            ),
          ),
        ),
      ),
    );
  }
}
