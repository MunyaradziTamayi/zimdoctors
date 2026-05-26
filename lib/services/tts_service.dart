import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class TtsService {
  final AudioPlayer _player = AudioPlayer();
  final String baseUrl; // e.g. 'https://your-api.com'
  final http.Client _client;

  TtsService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _ttsUri() {
    final base = Uri.parse(baseUrl.trim());

    final basePath = base.path;
    final joinedPath = basePath.endsWith('/')
        ? '${basePath}tts'
        : (basePath.isEmpty ? '/tts' : '$basePath/tts');

    return base.replace(path: joinedPath);
  }

  /// Fetches WAV bytes from your endpoint and plays them immediately.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    final response = await _client
        .post(
          _ttsUri(),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'audio/wav',
          },
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw Exception(
          'TTS endpoint not found (404). Expected POST ${_ttsUri()} '
          '(check your server is running and ngrok is pointing to it).',
        );
      }
      throw Exception('TTS failed: ${response.statusCode} ${response.body}');
    }

    final Uint8List wavBytes = response.bodyBytes;
    if (wavBytes.isEmpty) {
      throw Exception('TTS failed: empty audio payload');
    }

    // Feed raw bytes directly to just_audio — no temp file needed
    final source = AudioSource.uri(
      Uri.dataFromBytes(wavBytes, mimeType: 'audio/wav'),
    );

    await _player.stop();
    await _player.setAudioSource(source);
    await _player.play();
  }

  Future<void> stop() => _player.stop();

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  void dispose() {
    _client.close();
    _player.dispose();
  }
}
