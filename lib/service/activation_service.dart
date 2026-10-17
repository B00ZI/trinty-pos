import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypton/crypton.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/pointycastle.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart' as pc_api;

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

  static const String _privateKeyPem = '''
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAqqI90Pduu4Sou6sPOjZvB5gb4L2NZTfd7GX9mpRdx4T81QgI
dDsQljIIi2Gh/i8bqBHjyfl98aEcz+mxYEtVPeWyQln1cHsMjJ2l2gjqEnmZSqD6
lJW+4DXZ5EhYCMzBp97upfwRq4mSFk92089u3frUynTy522zULBdvwcC4wqjJ7tW
AexruiRT2I1YObmh571fJ261aSA7sJLlOr+pAz/nqWODsqX+gYgITdNTNZBgvqh0
34WKxKvbKiQbfoCGza1uYz2ZrYL35q3xUXyZONxQowKUAMUo0zZL6p/be/8Wbhbg
1Y57KlpxrXoXXs9ioiK85VuCKnq927NnUNsJlQIDAQABAoIBADnF6/MsS7g+7th3
zxSRKJ+kH1BFLbInK8MmNysW7/elbet9KEueUfvgneb/XBdRgOYzhHI2wK9Gsxgs
Uku9xfNKqcPwbHs0lmen2udLXGF7/Wx4u88CMpn8cbVqzy/PkAQUJa5afescDbPz
HNMTaUDMdC7GURYNnQiFZoBO0enn+vAA1QGDRYh3Zjo/pC4CojovQfoqPh2afypx
8/lRpZve7lrHdVm3+h8BEFZHlDdziujNlR3ig3oAvTiiGuz6CRZ8Y8au8hItlop9
YsmuSQhpHd4+iI4nHPM4eQhw5wAbh4rYqKEJ3aFjnwkoweJLFCchMa5gr81BkjOr
LnFjEuMCgYEA2q6P+kTu0319g2c3dAjXzJliEez1ufZA3tGl7NrVUw5j08eqQci7
58eUs8ymbprGAKhTciKGO1dIWit8zaC2GXiEPCsfwpnHCnLrQG27UpGmhoiv+Grl
YHA81YrBHBWk/tneQ4MqRA1CfoLw8lZ5+bTdYWnduljMM1XNv1lWMqMCgYEAx8Cg
WV0IxgNQReYqlRR/X7M7AIOb2XrWZrTt/f7tpFas8kuN+xGdfCph0N6OhN7QvVYz
cGFi56hdAA2VmxIp0GxxXN7gGlAvop9Urr42eNY4u+QPQdNV5Di1qBafXTbTMDky
oItNsXFy+MgL/axstZ3XLO+CQTwoe1ZseeA1TmcCgYAgwBnx+lbmN5oPjurAJv7i
tmn4k0tt0VJ/zFgUM+XU7YfH1NRLy9tQaBR+JP0b/XP/7zWoF0GRK447at3jEdmT
0PfE5xR3mX40s2dGG+j9AbE13syz4JZ/re9+b6xiH1+5hzmBVOiEjpPRzJx3Pro/
ynWJPEinutrCKWyJ5sBBDwKBgQC7ZvfI/ySVCVTNT0QR+1oIwdEQCWk03y64yvQh
AIOZU4wMAWBh9UPH0sdUOwiAlb5Gc9HslCFDb0xZGWWLR74dATBVze94IFSggFTl
YCUgtvIhLLQ3sHr7k0yyNw8qV55IttDNmAO6/tG7n4rIYnTW6w+N4+JTK4pbNFiu
+u9n7wKBgQC6yb0I57f3WFFuC+TvKQ8SQuAcr9gX4m5XUD8f9mKOghFRjnTyVBKT
k47se6n6oPDk4OxJNzBkxJO8Zdn4ACbDmgwOaM9+5rkh2LNvPtZumAyhiqLWqWYD
d277L8iSfpacBpQzZ1rhAvlZm7Xp3IRr9gGCsZiuZj7pYMsGL9CMpw==
-----END RSA PRIVATE KEY-----
''';

  /// Checks if the app is already activated by verifying the stored key.
  static Future<bool> isActivated() async {
    final storedKey = await _storage.read(key: _activationKey);
    if (storedKey == null) return false;

    // Try verifying as Long Key (Base64) first
    if (await verifyActivationKey(storedKey)) return true;

    // Try verifying as Short Key (XXXX-XXXX)
    return await verifyShortKey(storedKey);
  }

  /// Retrieves the unique device ID used for activation.
  /// Android: the standard Android ID (unchanged behavior).
  /// Windows: a SHA-256 fingerprint of stable machine properties
  /// (ProductId + DigitalProductId) so the app can run on desktop for
  /// development/testing. Keep in sync with tool/generate_activation_key.dart.
  static Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      final raw =
          '${windowsInfo.productId}|${windowsInfo.digitalProductId.join(',')}';
      final id = sha256.convert(utf8.encode(raw)).toString();
      // ignore: avoid_print
      print('Windows device fingerprint: $id'); // Used by tool/generate_activation_key.dart
      return id;
    }
    return "unsupported_platform";
  }

  /// Verifies a Short Activation Key (XXXX-XXXX) using the Private Key logic.
  static Future<bool> verifyShortKey(String inputKey) async {
    try {
      final androidId = await getAndroidId();
      if (androidId == "unsupported_platform") return false;

      // Reconstruct the expected Short Key for this device
      final expectedKey = _generateExpectedShortKey(androidId);
      
      // Compare (case-insensitive and ignore dashes)
      final cleanInput = inputKey.replaceAll('-', '').toUpperCase();
      final cleanExpected = expectedKey.replaceAll('-', '').toUpperCase();

      if (cleanInput == cleanExpected) {
        print("Short Key verification successful");
        return true;
      } else {
        print("Short Key mismatch: input=$cleanInput expected=$cleanExpected");
        return false;
      }
    } catch (e) {
      print("Short Key verification exception: $e");
      return false;
    }
  }

  /// Internal logic to generate the expected short key for a given androidId.
  /// Matches the output of the generator app.
  static String _generateExpectedShortKey(String androidId) {
    try {
      final parser = encrypt.RSAKeyParser();
      final privateKey = parser.parse(_privateKeyPem) as pc_api.RSAPrivateKey;

      const expiry = "never";
      const licenseType = "PRO";
      final data = "$androidId|$expiry|$licenseType";

      final signer = pc.Signer('SHA-256/RSA')
        ..init(true, pc.PrivateKeyParameter<pc_api.RSAPrivateKey>(privateKey));
      
      final sig = signer.generateSignature(Uint8List.fromList(utf8.encode(data))) as pc.RSASignature;
      final signatureBytes = sig.bytes;

      final hash = sha256.convert(signatureBytes).toString().toUpperCase();
      return "${hash.substring(0, 4)}-${hash.substring(4, 8)}";
    } catch (e) {
      print("Error generating expected short key: $e");
      return "ERROR";
    }
  }

  /// Unified verification for both Long and Short Activation Keys.
  static Future<bool> verifyKey(String key) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return false;

    // Try Long Key first (usually much longer)
    if (cleanKey.length > 20) {
      if (await verifyActivationKey(cleanKey)) return true;
    }

    // Fallback to Short Key logic
    return await verifyShortKey(cleanKey);
  }

  /// Verifies a structured Long Activation Key: Base64(androidId|expiry|type|signature)
  static Future<bool> verifyActivationKey(String fullKeyBase64) async {
    try {
      if (fullKeyBase64.length < 20) return false; // Too short for a Long Key

      final String decoded;
      try {
        decoded = utf8.decode(base64.decode(fullKeyBase64.trim()));
      } catch (e) {
        return false;
      }

      final parts = decoded.split('|');
      if (parts.length < 4) return false;

      final keyAndroidId = parts[0];
      final expiryStr = parts[1];
      // final type = parts[2]; // Unused but part of metadata
      final signatureBase64 = parts.last;
      final metadata = parts.sublist(0, parts.length - 1).join('|');

      final rsaPublicKey = RSAPublicKey.fromString(_publicKeyString);
      final isSignatureValid = rsaPublicKey.verifySHA256Signature(
        utf8.encode(metadata),
        base64.decode(signatureBase64),
      );

      if (!isSignatureValid) return false;

      final deviceAndroidId = await getAndroidId();
      if (keyAndroidId != deviceAndroidId) return false;

      if (expiryStr != "never") {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry == null || DateTime.now().isAfter(expiry)) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Derives the Short Key from a valid Long Key for UI display.
  static String deriveShortKey(String fullKeyBase64) {
    try {
      final decoded = utf8.decode(base64.decode(fullKeyBase64.trim()));
      final parts = decoded.split('|');
      if (parts.length < 4) return "INVALID";

      final signatureBase64 = parts.last;
      final signatureBytes = base64.decode(signatureBase64);

      final hash = sha256.convert(signatureBytes).toString().toUpperCase();
      return "${hash.substring(0, 4)}-${hash.substring(4, 8)}";
    } catch (e) {
      return "ERROR";
    }
  }

  /// Saves the activation key to secure storage.
  static Future<void> saveActivationKey(String key) async {
    await _storage.write(key: _activationKey, value: key);
  }
}
