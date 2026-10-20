import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// P42: nothing fails silently.
///
/// Any uncaught error — framework (build/layout) or async (a button handler
/// that threw) — is shown to the shop as a short French message instead of
/// the button "doing nothing", and is written to the console in debug
/// builds only (P49: release/tablet builds log nothing).
class ErrorReporter {
  ErrorReporter(this._messengerKey);

  final GlobalKey<ScaffoldMessengerState> _messengerKey;
  DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);

  /// Shows the message and returns true — or false when the rate limit
  /// swallows it (an error loop must not flood the shop screen).
  bool report(Object error, [StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('=== Uncaught error ===\n$error\n${stack ?? StackTrace.current}');
    }
    final now = DateTime.now();
    // An action failing in a loop must not flood the screen with messages:
    // one message per few seconds is enough to see it happening.
    if (now.difference(_lastShown) < const Duration(seconds: 4)) return false;
    _lastShown = now;
    _messengerKey.currentState?.showSnackBar(SnackBar(
      content: const Text('Une erreur est survenue — réessayez'),
      backgroundColor: AppColors.danger,
      duration: const Duration(seconds: 4),
    ));
    return true;
  }
}
