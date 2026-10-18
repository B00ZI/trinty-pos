import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:objectbox/objectbox.dart';

import '../models/store_config.dart';

/// The Wi-Fi password lives in platform secure storage — Windows DPAPI /
/// Android Keystore, the same mechanism the activation key already uses —
/// instead of plaintext inside the database file (PROBLEMS.md P07).
class WifiPasswordStore {
  WifiPasswordStore._();

  static const String _key = 'wifi_password';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Returns the stored password, or '' when unavailable.
  static Future<String> read() async {
    try {
      return await _storage.read(key: _key) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> write(String value) async {
    if (value.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: value);
    }
  }

  /// One-time move of the legacy plaintext value out of the database.
  /// Safe to call at every startup: a no-op once the field is cleared.
  static Future<void> migrateFromConfigs(Box<StoreConfig> box) async {
    final configs = box.getAll();
    if (configs.isEmpty) return;
    final config = configs.first;
    final legacy = config.wifiPassword;
    if (legacy == null || legacy.isEmpty) return;
    if ((await read()).isEmpty) {
      await write(legacy);
    }
    config.wifiPassword = null;
    box.put(config);
  }
}
