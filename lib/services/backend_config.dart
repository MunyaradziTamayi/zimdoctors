import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendConfig {
  static const String _defaultNgrokBaseUrl =
      'https://lunchbox-blabber-unworn.ngrok-free.dev';
  static const String _defaultTtsBaseUrl = '';

  static Uri diseaseApiBaseUri() {
    final defineBaseUrl = const String.fromEnvironment(
      'DISEASE_API_BASE_URL',
      defaultValue: '',
    ).trim();

    String? envBaseUrl;
    try {
      envBaseUrl = dotenv.env['DISEASE_API_BASE_URL']?.trim();
    } on NotInitializedError {
      envBaseUrl = null;
    }

    final chosenRaw = defineBaseUrl.isNotEmpty
        ? defineBaseUrl
        : ((envBaseUrl == null || envBaseUrl.isEmpty)
              ? _fallbackBaseUrl()
              : envBaseUrl);

    final chosenUnquoted = _stripWrappingQuotes(chosenRaw);
    final chosenWithScheme = _ensureScheme(chosenUnquoted);
    return Uri.parse(chosenWithScheme);
  }

  static Uri ttsApiBaseUri() {
    final defineTtsUrl = const String.fromEnvironment(
      'TTS_API_BASE_URL',
      defaultValue: '',
    ).trim();

    String? envTtsUrl;
    try {
      envTtsUrl = dotenv.env['TTS_API_BASE_URL']?.trim();
    } on NotInitializedError {
      envTtsUrl = null;
    }

    // If TTS URL is not configured, use the disease API base URL by default
    final chosenRaw = defineTtsUrl.isNotEmpty
        ? defineTtsUrl
        : (envTtsUrl != null && envTtsUrl.isNotEmpty
              ? envTtsUrl
              : diseaseApiBaseUri().toString());

    final chosenUnquoted = _stripWrappingQuotes(chosenRaw);
    final chosenWithScheme = _ensureScheme(chosenUnquoted);
    return Uri.parse(chosenWithScheme);
  }

  static String _fallbackBaseUrl() {
    return _defaultNgrokBaseUrl;
  }

  static String _stripWrappingQuotes(String input) {
    var value = input.trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1).trim();
    }
    return value;
  }

  static String _ensureScheme(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.contains('://')) return trimmed;
    return 'http://$trimmed';
  }
}
