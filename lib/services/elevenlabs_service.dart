import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

class ElevenLabsService {
  ElevenLabsService({
    required String apiKey,
    String? voiceId,
    String? ttsModelId,
    String? sttModelId,
    http.Client? client,
  })  : _apiKey = apiKey,
        _voiceId = (voiceId == null || voiceId.trim().isEmpty)
            ? _defaultVoiceId
            : voiceId.trim(),
        _ttsModelId = (ttsModelId == null || ttsModelId.trim().isEmpty)
            ? _defaultTtsModelId
            : ttsModelId.trim(),
        _sttModelId = (sttModelId == null || sttModelId.trim().isEmpty)
            ? _defaultSttModelId
            : sttModelId.trim(),
        _client = client ?? http.Client();

  factory ElevenLabsService.fromEnv({http.Client? client}) {
    String? apiKey;
    try {
      apiKey = dotenv.env['ELEVENLABS_API_KEY']?.trim();
    } on NotInitializedError {
      throw StateError(
        'DotEnv not initialized. Ensure `.env` exists and is included in '
        '`pubspec.yaml` under `flutter/assets`, then restart the app.',
      );
    }

    if (apiKey != null &&
        apiKey.length >= 2 &&
        ((apiKey.startsWith('"') && apiKey.endsWith('"')) ||
            (apiKey.startsWith("'") && apiKey.endsWith("'")))) {
      apiKey = apiKey.substring(1, apiKey.length - 1).trim();
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'Missing ELEVENLABS_API_KEY. Add it to `.env` at the project root.',
      );
    }

    return ElevenLabsService(
      apiKey: apiKey,
      voiceId: dotenv.env['ELEVENLABS_VOICE_ID'],
      ttsModelId: dotenv.env['ELEVENLABS_TTS_MODEL_ID'],
      sttModelId: dotenv.env['ELEVENLABS_STT_MODEL_ID'],
      client: client,
    );
  }

  static const _baseUrl = 'https://api.elevenlabs.io/v1';
  static const _defaultVoiceId = '21m00Tcm4TlvDq8ikWAM';
  static const _defaultTtsModelId = 'eleven_multilingual_v2';
  static const _defaultSttModelId = 'scribe_v2';

  final String _apiKey;
  final String _voiceId;
  final String _ttsModelId;
  final String _sttModelId;
  final http.Client _client;

  Future<File> textToSpeechToFile(
    String text, {
    String? voiceId,
    bool enableLogging = true,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Must not be empty');
    }

    final uri = Uri.parse('$_baseUrl/text-to-speech/${voiceId ?? _voiceId}')
        .replace(queryParameters: {
      'enable_logging': enableLogging.toString(),
    });

    final response = await _client
        .post(
          uri,
          headers: {
            'xi-api-key': _apiKey,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': trimmed,
            'model_id': _ttsModelId,
            'voice_settings': {
              'stability': 0.5,
              'similarity_boost': 0.8,
              'use_speaker_boost': true,
            },
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'ElevenLabs TTS failed (${response.statusCode}): ${response.body}',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final output = File(
      '${tempDir.path}/elevenlabs_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await output.writeAsBytes(response.bodyBytes, flush: true);
    return output;
  }

  Future<String> speechToText(
    File audioFile, {
    bool enableLogging = true,
  }) async {
    if (!await audioFile.exists()) {
      throw ArgumentError.value(audioFile.path, 'audioFile', 'File not found');
    }

    final uri = Uri.parse('$_baseUrl/speech-to-text').replace(
      queryParameters: {'enable_logging': enableLogging.toString()},
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers['xi-api-key'] = _apiKey
      ..fields['model_id'] = _sttModelId;

    final contentType = _guessAudioMediaType(audioFile.path);
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
        contentType: contentType,
      ),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'ElevenLabs STT failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final text = (data is Map<String, dynamic>) ? data['text'] : null;
    if (text is! String) {
      throw FormatException(
        'Unexpected STT response shape (missing "text"): ${response.body}',
      );
    }
    return text.trim();
  }

  MediaType _guessAudioMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
      return MediaType('audio', 'mp4');
    }
    if (lower.endsWith('.wav')) {
      return MediaType('audio', 'wav');
    }
    if (lower.endsWith('.mp3')) {
      return MediaType('audio', 'mpeg');
    }
    if (lower.endsWith('.webm')) {
      return MediaType('audio', 'webm');
    }
    return MediaType('application', 'octet-stream');
  }
}
