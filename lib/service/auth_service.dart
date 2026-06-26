import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../objectbox.dart';
// import 'package:objectbox/objectbox.dart';

enum AuthMode { off, session, perOrder }

class AuthService {
  static Future<AuthMode> getAuthMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('auth_mode') ?? 'off';
    switch (mode) {
      case 'session':
        return AuthMode.session;
      case 'per_order':
        return AuthMode.perOrder;
      default:
        return AuthMode.off;
    }
  }

  static Future<void> setAuthMode(AuthMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_mode', mode.toString().split('.').last);
  }

  static bool verifyPin(AppUser user, String rawPin) {
    return user.verifyPin(rawPin);
  }

  static List<AppUser> getUsers(ObjectBox objectbox) {
    return objectbox.userBox.getAll();
  }
}
