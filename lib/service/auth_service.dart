import 'package:shared_preferences/shared_preferences.dart';

enum AuthMode { off, session, perOrder }

class AuthService {
  /// How each mode is stored in SharedPreferences.
  ///
  /// P47: ONE spelling for writing AND reading. The old writer produced
  /// `perOrder` (the Dart enum name) while the reader looked for
  /// `per_order` — so a saved "PIN par vente" always came back as OFF.
  /// The settings screen always wrote `per_order`, so that is the value.
  static const Map<AuthMode, String> _storageValues = {
    AuthMode.off: 'off',
    AuthMode.session: 'session',
    AuthMode.perOrder: 'per_order',
  };

  static Future<AuthMode> getAuthMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('auth_mode') ?? 'off';
    switch (mode) {
      case 'session':
        return AuthMode.session;
      // Both spellings accepted: `per_order` is what is written today,
      // `perOrder` is what the old writer left behind in shop settings.
      case 'per_order':
      case 'perOrder':
        return AuthMode.perOrder;
      default:
        return AuthMode.off;
    }
  }

  static Future<void> setAuthMode(AuthMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    // P47: write the SAME value getAuthMode reads (was
    // mode.toString().split('.').last → 'perOrder', silently OFF on read).
    await prefs.setString('auth_mode', _storageValues[mode]!);
  }
}
