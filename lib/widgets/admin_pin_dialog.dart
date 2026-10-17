import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_user.dart';
import '../objectbox.dart';
import '../theme/app_colors.dart';

class AdminPinDialog extends StatefulWidget {
  final ObjectBox objectbox;

  const AdminPinDialog({super.key, required this.objectbox});

  /// Helper method to show the dialog and verify admin PIN
  static Future<bool> verify(BuildContext context, ObjectBox objectbox) async {
    final userBox = objectbox.userBox;
    final adminUsers = userBox.getAll().where((u) => u.isAdmin).toList();

    if (adminUsers.isEmpty) {
      // If no admin exists, we can't verify (should not happen with seeding)
      return false;
    }

    final enteredPin = await showDialog<String>(
      context: context,
      builder: (context) => AdminPinDialog(objectbox: objectbox),
    );

    if (enteredPin == null) return false;

    for (final admin in adminUsers) {
      if (admin.verifyPin(enteredPin)) {
        // Transparently upgrade legacy (unsalted) PINs to salted hashes
        if (admin.needsPinUpgrade) {
          final (hash, salt) = AppUser.hashPin(enteredPin);
          admin.pin = hash;
          admin.pinSalt = salt;
          objectbox.userBox.put(admin);
        }
        return true;
      }
    }
    return false;
  }

  /// Helper to show the dialog and check the entered code against a
  /// fixed value instead of a stored admin PIN (used to gate the hidden
  /// dev panel — PROBLEMS.md P03).
  static Future<bool> verifyFixedCode(
      BuildContext context, ObjectBox objectbox, String expectedCode) async {
    final enteredPin = await showDialog<String>(
      context: context,
      builder: (context) => AdminPinDialog(objectbox: objectbox),
    );
    if (enteredPin == null) return false;
    return enteredPin == expectedCode;
  }

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
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
      });
      if (_enteredPin.length == 4) {
        Navigator.pop(context, _enteredPin);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
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
    final double keySize = isShort ? 44.0 : 64.0;
    final double keySpacing = isShort ? 6.0 : 12.0;
    final double headerIconSize = isShort ? 30.0 : 40.0;
    final double titleFontSize = isShort ? 16.0 : 20.0;
    final double subTitleFontSize = isShort ? 11.0 : 13.0;

    final double dialogWidth = isNarrow ? (screenWidth * 0.85) : 320.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: dialogWidth,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: AppColors.surface0,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink0.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isShort ? 10 : 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.admin_panel_settings,
                size: headerIconSize,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: isShort ? 10 : 20),
            Text(
              'Accès Administrateur',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: isShort ? 4 : 8),
            Text(
              'Veuillez entrer le code administrateur',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink3, fontSize: subTitleFontSize),
            ),
            SizedBox(height: isShort ? 12 : 32),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool isFilled = index < _enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: isShort ? 10 : 14,
                        height: isShort ? 10 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.surface3,
                          boxShadow: isFilled
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            SizedBox(height: isShort ? 16 : 40),
            _buildKeypad(keySize, keySpacing),
            SizedBox(height: isShort ? 12 : 24),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink3,
                padding: EdgeInsets.symmetric(
                    horizontal: 32, vertical: isShort ? 8 : 12),
              ),
              child: const Text('ANNULER',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad(double keySize, double keySpacing) {
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
              children: row.map((d) => _buildKey(d, keySize)).toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(width: keySize),
            _buildKey('0', keySize),
            _buildKey('⌫', keySize, isIcon: true, onTap: _onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String label, double keySize,
      {bool isIcon = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => _onDigitTap(label),
      borderRadius: BorderRadius.circular(keySize / 2),
      child: Container(
        width: keySize,
        height: keySize,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isIcon
              ? Icon(Icons.backspace_outlined,
                  size: keySize * 0.35, color: AppColors.ink0)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: keySize * 0.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
