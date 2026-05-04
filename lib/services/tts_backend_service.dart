import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TtsBackendService {
  final String baseUrl;
  final http.Client _client;

  TtsBackendService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _ttsUri() {
    final base = Uri.parse(baseUrl.trim());

    // Join paths safely to avoid accidental double slashes like `//tts`
    // (which can cause 404s on some backends/proxies).
    final basePath = base.path;
    final joinedPath = basePath.endsWith('/')
        ? '${basePath}tts'
        : (basePath.isEmpty ? '/tts' : '$basePath/tts');

    return base.replace(path: joinedPath);
  }

  /// Generates speech for Shona text using the backend TTS endpoint.
  /// Returns the file path to the generated WAV audio file.
  Future<String> generateSpeech(String text) async {
    if (text.trim().isEmpty) {
      throw Exception('Text cannot be empty');
    }

    try {
      final uri = _ttsUri();
      
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
          'TTS endpoint returned status ${response.statusCode}: ${response.body}',
        );
      }

      // Save the audio to a temporary file
      final audioBytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/shona_tts_$timestamp.wav';
      final file = File(filePath);
      await file.writeAsBytes(audioBytes);

      return filePath;
    } on SocketException catch (e) {
      throw Exception(
        'Failed to connect to TTS backend at $baseUrl: ${e.message}',
      );
    } catch (e) {
      throw Exception('Error generating speech: $e');
    }
  }
}
