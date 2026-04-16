import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:zimdoctors/models/diagnosis_response.dart';

class DiseaseApiService {
  DiseaseApiService({required Uri baseUrl, http.Client? client})
    : _baseUrl = baseUrl,
      _client = client ?? http.Client();

  factory DiseaseApiService.fromEnv({http.Client? client}) {
    String? baseUrl;
    try {
      baseUrl = dotenv.env['DISEASE_API_BASE_URL']?.trim();
    } on NotInitializedError {
      baseUrl = null;
    }

    if (baseUrl != null &&
        baseUrl.length >= 2 &&
        ((baseUrl.startsWith('"') && baseUrl.endsWith('"')) ||
            (baseUrl.startsWith("'") && baseUrl.endsWith("'")))) {
      baseUrl = baseUrl.substring(1, baseUrl.length - 1).trim();
    }

    final fallback = Platform.isAndroid
        ? 'http://10.0.2.2:8000'
        : 'http://localhost:8000';

    final chosen = (baseUrl == null || baseUrl.isEmpty) ? fallback : baseUrl;
    final uri = _normalizeBaseUriForPlatform(Uri.parse(_ensureScheme(chosen)));

    return DiseaseApiService(baseUrl: uri, client: client);
  }

  final Uri _baseUrl;
  final http.Client _client;

  String? _sessionId;
  String? _language;

  static String _ensureScheme(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.contains('://')) return trimmed;
    return 'http://$trimmed';
  }

  static Uri _normalizeBaseUriForPlatform(Uri uri) {
    if (!Platform.isAndroid) return uri;
    final host = uri.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1' && host != '::1') {
      return uri;
    }
    // On Android emulators, "localhost" points at the emulator/device itself.
    return uri.replace(host: '10.0.2.2');
  }

  Uri _endpointUri(String endpointPath) {
    final basePath = _baseUrl.path;
    final normalizedBasePath = (basePath.endsWith('/') && basePath.length > 1)
        ? basePath.substring(0, basePath.length - 1)
        : (basePath == '/' ? '' : basePath);
    final path = '$normalizedBasePath/$endpointPath';
    return _baseUrl.replace(path: path);
  }

  Future<void> startSession(String language) async {
    final uri = _endpointUri('session/start');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'language': language}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend /session/start failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected /session/start response shape');
    }
    final sessionId = data['session_id'];
    final lang = data['language'];
    if (sessionId is! String || lang is! String) {
      throw const FormatException(
        'Unexpected /session/start response (missing session_id or language)',
      );
    }
    _sessionId = sessionId;
    _language = lang;
  }

  String? get currentLanguage => _language;
  String? get sessionId => _sessionId;

  void resetSession() {
    _sessionId = null;
    _language = null;
  }

  Future<dynamic> reply(String message) async {
    if (_sessionId == null) {
      // Try to auto-start session if not already started
      await startSession('english');
    }
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(message, 'message', 'Must not be empty');
    }

    final isQuestion =
        trimmed.endsWith('?') ||
        RegExp(
          r'^(what|how|why|when|where|is|are|can|should|do|does|did|will)\b',
          caseSensitive: false,
        ).hasMatch(trimmed);

    if (isQuestion) {
      return _askThenPredictFallback(trimmed);
    }
    return _predictThenAskFallback(trimmed);
  }

  Future<dynamic> _askThenPredictFallback(String question) async {
    late Object askError;
    try {
      final answer = await ask(question);
      if (!_looksLikeUnknownAnswer(answer)) {
        return answer;
      }
      final fallbackDiagnosis = await predictFromText(question);
      if (!_looksLikeUnknownDiagnosis(fallbackDiagnosis)) {
        return fallbackDiagnosis;
      }
      return answer;
    } catch (e) {
      askError = e;
      try {
        return await predictFromText(question);
      } catch (predictError) {
        throw Exception(
          'Both /ask and /predict/text failed. ask: $askError; predict: $predictError',
        );
      }
    }
  }

  Future<dynamic> _predictThenAskFallback(String text) async {
    late Object predictError;
    try {
      final diagnosis = await predictFromText(text);
      if (!_looksLikeUnknownDiagnosis(diagnosis)) {
        return diagnosis;
      }
      final fallbackAnswer = await ask(text);
      if (!_looksLikeUnknownAnswer(fallbackAnswer)) {
        return fallbackAnswer;
      }
      return diagnosis;
    } catch (e) {
      predictError = e;
      try {
        return await ask(text);
      } catch (askError) {
        throw Exception(
          'Both /predict/text and /ask failed. predict: $predictError; ask: $askError',
        );
      }
    }
  }

  bool _looksLikeUnknownAnswer(String answer) {
    final normalized = answer.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unknown') {
      return true;
    }
    final unknownPatterns = [
      'i don\'t know',
      'i do not know',
      'i am not sure',
      'im not sure',
      'not sure',
      'cannot answer',
      'unable to answer',
      'no idea',
      'unknown',
      'sorry',
      'can\'t answer',
    ];
    return unknownPatterns.any(normalized.contains);
  }

  bool _looksLikeUnknownDiagnosis(DiagnosisResponse response) {
    final predicted = response.predictedDisease.trim().toLowerCase();
    if (predicted.isEmpty || predicted == 'unknown') {
      return true;
    }
    if (predicted.contains('unknown') ||
        predicted.contains('not sure') ||
        predicted.contains('cannot determine')) {
      return true;
    }
    if (response.confidence < 10.0) {
      return true;
    }
    return false;
  }

  Future<String> ask(String question) async {
    final uri = _endpointUri('ask');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'question': question, 'session_id': _sessionId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend /ask failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected /ask response shape');
    }
    final answer = data['answer'];
    if (answer is! String) {
      throw const FormatException(
        'Unexpected /ask response (missing "answer")',
      );
    }
    return answer.trim();
  }

  Future<DiagnosisResponse> predictFromText(String text) async {
    final uri = _endpointUri('predict/text');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text, 'session_id': _sessionId}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend /predict/text failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected /predict/text response shape');
    }

    return DiagnosisResponse.fromJson(data);
  }

  Future<Map<String, dynamic>> predictDoctor(String text) async {
    final uri = _endpointUri('predict/doctor');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text, 'session_id': _sessionId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend /predict/doctor failed (${response.statusCode}): ${response.body}',
      );
    }

    return jsonDecode(response.body);
  }
}
