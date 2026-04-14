class WhatsAppUtils {
  /// Normalizes common Zimbabwe phone formats to a `wa.me` compatible number.
  /// Example: `0771234567` -> `263771234567`, `+263 77 123 4567` -> `263771234567`.
  static String normalizeWaMeNumber(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    // Common local format: 0XXXXXXXXX
    if (digits.startsWith('0') && digits.length >= 9) {
      digits = '263${digits.substring(1)}';
    }

    // If user pasted with leading country code already, keep it.
    if (digits.startsWith('263')) return digits;

    // Fallback: return digits as-is (caller can decide if it is usable).
    return digits;
  }
}

