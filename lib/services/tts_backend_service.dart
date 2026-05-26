import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TtsBackendService {
  final String baseUrl;
  final http.Client _client;
  bool _isWarmedUp = false;

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
      
      // First request can be slower due to backend cold-start/model load.
      final headersTimeout = _isWarmedUp
          ? const Duration(seconds: 30)
          : const Duration(seconds: 60);

      // Allow extra time for the server to finish sending the WAV bytes,
      // especially if it's doing on-the-fly synthesis.
      final bodyTimeout = _isWarmedUp
          ? const Duration(seconds: 45)
          : const Duration(seconds: 90);

      final request = http.Request('POST', uri)
        ..headers.addAll(const {
          'Content-Type': 'application/json',
          'Accept': 'audio/wav',
          // If the backend incorrectly keeps the connection open (chunked
          // transfer without completing), this encourages it to close after
          // sending the bytes.
          'Connection': 'close',
        })
        ..body = jsonEncode({'text': text});

      final streamed = await _client.send(request).timeout(headersTimeout);
      final statusCode = streamed.statusCode;
      final audioBytes = await streamed.stream.toBytes().timeout(bodyTimeout);

      if (statusCode != 200) {
        final bodyText = utf8.decode(audioBytes, allowMalformed: true);
        throw Exception(
          'TTS endpoint returned status $statusCode: $bodyText',
        );
      }
      if (audioBytes.isEmpty) {
        throw Exception('TTS endpoint returned an empty audio payload.');
      }

      _isWarmedUp = true;
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/shona_tts_$timestamp.wav';
      final file = File(filePath);
      await file.writeAsBytes(audioBytes, flush: true);

      return filePath;
    } on SocketException catch (e) {
      throw Exception(
        'Failed to connect to TTS backend at $baseUrl: ${e.message}',
      );
    } on TimeoutException catch (e) {
      throw Exception(
        'TTS backend timed out. If you see 200 responses but timeouts, '
        'the server may not be completing/closing the response body. '
        'Details: $e',
      );
    } catch (e) {
      throw Exception('Error generating speech: $e');
    }
  }
}
