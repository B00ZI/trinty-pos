import 'package:objectbox/objectbox.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

@Entity()
class AppUser {
  @Id()
  int id;

  String name;
  String? pin; // SHA-256 hashed
  bool isAdmin;
  DateTime createdAt;

  AppUser({
    this.id = 0,
    required this.name,
    this.pin,
    this.isAdmin = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static String hashPin(String rawPin) {
    final bytes = utf8.encode(rawPin);
    return sha256.convert(bytes).toString();
  }

  bool verifyPin(String rawPin) => pin == hashPin(rawPin);
}
