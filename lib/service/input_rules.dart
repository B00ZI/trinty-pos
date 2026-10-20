import 'money_parser.dart';

/// P30: the few "is this value allowed?" rules of the app, as pure functions
/// so they can be unit-tested without widgets.
///
/// Owner's calls (2026-10-20): a price of **0 is allowed** (free products are
/// real), a **negative price never** (it would subtract money on every sale),
/// and **the same name never twice** (products, categories, users).
class InputRules {
  /// Case-, space- and accent-insensitive comparison key: "Café  Noir" and
  /// "cafe noir" are the same name, "Youssef" and "YOUSSEF" too.
  static String normalizeName(String raw) {
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
      'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
      'ç': 'c', 'ñ': 'n', 'ÿ': 'y',
    };
    final lower = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(accents[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Price validation: parses with the shared [MoneyParser] (French comma
  /// accepted) and refuses negatives. `0` is fine.
  static String? nonNegativePrice(String raw) {
    final value = MoneyParser.parse(raw);
    if (value == null) return 'Prix valide requis';
    if (value < 0) return 'Le prix ne peut pas être négatif';
    return null;
  }

  /// Uniqueness validation for product / category / user names.
  ///
  /// [excluding] is the name of the record being edited (editing a product
  /// must not collide with itself). Returns `null` when allowed, or the
  /// French error to show in the field.
  static String? uniqueName(String? raw, Iterable<String> existing,
      {String? excluding}) {
    final name = (raw ?? '').trim();
    if (name.isEmpty) return null; // "required" stays the caller's check
    final target = normalizeName(name);
    final own = excluding == null ? null : normalizeName(excluding);
    for (final other in existing) {
      final otherKey = normalizeName(other);
      if (otherKey == target && otherKey != own) return 'Ce nom existe déjà';
    }
    return null;
  }
}
