import 'package:objectbox/objectbox.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

@Entity()
class AppUser {
  @Id()
  int id;

  String name;
  String? pin; // SHA-256 hashed with salt
  String? pinSalt; // Random salt for PIN hashing
  bool isAdmin;
  DateTime createdAt;

  AppUser({
    this.id = 0,
    required this.name,
    this.pin,
    this.pinSalt,
    this.isAdmin = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Generate a random 16-byte salt.
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  /// Hash a raw PIN with the given salt using SHA-256.
  static String _hashWithSalt(String rawPin, String salt) {
    final combined = '$salt:$rawPin';
    final bytes = utf8.encode(combined);
    return sha256.convert(bytes).toString();
  }

  /// Create a hashed PIN with a fresh salt. Returns (hash, salt).
  static (String hash, String salt) hashPin(String rawPin) {
    final salt = _generateSalt();
    final hash = _hashWithSalt(rawPin, salt);
    return (hash, salt);
  }

  /// Legacy hash (no salt) – used to verify PINs created before the salt upgrade.
  static String _hashLegacy(String rawPin) {
    return sha256.convert(utf8.encode(rawPin)).toString();
  }

  /// Verify a raw PIN against the stored hash.
  /// Supports both new salted hashes and legacy (unsalted) hashes so that
  /// existing users are not locked out after the security upgrade.
  bool verifyPin(String rawPin) {
    if (pin == null) return false;
    if (pinSalt != null) {
      // New salted verification
      return pin == _hashWithSalt(rawPin, pinSalt!);
    }
    // Legacy fallback – plain SHA-256 (no salt)
    return pin == _hashLegacy(rawPin);
  }

  /// Returns `true` when the PIN is stored with the legacy (unsalted) format
  /// and should be re-hashed at the next opportunity.
  bool get needsPinUpgrade => pin != null && pinSalt == null;
}
