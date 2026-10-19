/// One parser for every money amount typed in the app (P17 comma, P18).
///
/// Accepts what people actually type here: `12,5` (French comma), `12.5`
/// and stray spaces. Returns `null` for empty or unparseable input so
/// callers can refuse to save and show a message instead of silently
/// writing 0.00.
class MoneyParser {
  static final RegExp _number = RegExp(r'^-?\d+(\.\d+)?$');

  static double? parse(String raw) {
    final cleaned = raw.trim().replaceAll(' ', '');
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.replaceAll(',', '.');
    // Strict shape check: plain numbers only — no "12e5", no "NaN".
    if (!_number.hasMatch(normalized)) return null;
    final value = double.tryParse(normalized);
    if (value == null || !value.isFinite) return null;
    return value;
  }
}
