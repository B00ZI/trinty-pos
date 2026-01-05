import 'dart:convert';
import 'dart:io';
import 'package:crypton/crypton.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ActivationService {
  static const _storage = FlutterSecureStorage();
  static const _activationKey = 'app_activation_key';

  static const String _publicKeyString =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqqI90Pduu4Sou6sPOjZv'
      'B5gb4L2NZTfd7GX9mpRdx4T81QgIdDsQljIIi2Gh/i8bqBHjyfl98aEcz+mxYEtV'
      'PeWyQln1cHsMjJ2l2gjqEnmZSqD6lJW+4DXZ5EhYCMzBp97upfwRq4mSFk92089u'
      '3frUynTy522zULBdvwcC4wqjJ7tWAexruiRT2I1YObmh571fJ261aSA7sJLlOr+p'
      'Az/nqWODsqX+gYgITdNTNZBgvqh034WKxKvbKiQbfoCGza1uYz2ZrYL35q3xUXyZ'
      'ONxQowKUAMUo0zZL6p/be/8Wbhbg1Y57KlpxrXoXXs9ioiK85VuCKnq927NnUNsJ'
      'lQIDAQAB';

  /// Checks if the app is already activated by verifying the stored key.
  static Future<bool> isActivated() async {
    final storedKey = await _storage.read(key: _activationKey);
    if (storedKey == null) return false;

    return verifyActivationKey(storedKey);
  }

  /// Retrieves the unique Android ID.
  static Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // This is the hardware ID
    }
    return "unsupported_platform";
  }

  /// Verifies a structured activation key: Base64(androidId|expiry|type|signature)
  static Future<bool> verifyActivationKey(String fullKeyBase64) async {
    try {
      final decoded = utf8.decode(base64.decode(fullKeyBase64));
      final parts = decoded.split('|');
      if (parts.length != 4) {
        print("Key split error: ${parts.length} parts");
        return false;
      }

      final keyAndroidId = parts[0];
      final expiryStr = parts[1];
      final type = parts[2];
      final signatureBase64 = parts[3];

      final metadata = "$keyAndroidId|$expiryStr|$type";

      final rsaPublicKey = RSAPublicKey.fromString(_publicKeyString);
      final isSignatureValid = rsaPublicKey.verifySHA256Signature(
        utf8.encode(metadata),
        base64.decode(signatureBase64),
      );

      if (!isSignatureValid) {
        print("Signature invalid");
        return false;
      }

      final deviceAndroidId = await getAndroidId();
      if (keyAndroidId != deviceAndroidId) {
        print("Android ID mismatch: key=$keyAndroidId device=$deviceAndroidId");
        return false;
      }

      if (expiryStr != "never") {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry == null || DateTime.now().isAfter(expiry)) {
          print("Expiry invalid or expired");
          return false;
        }
      }

      return true;
    } catch (e) {
      print("Exception: $e");
      return false;
    }
  }

  /// Saves the activation key to secure storage.
  static Future<void> saveActivationKey(String key) async {
    await _storage.write(key: _activationKey, value: key);
  }
}
