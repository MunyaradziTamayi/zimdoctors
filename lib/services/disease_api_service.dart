import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:zimdoctors/models/diagnosis_response.dart';
import 'package:zimdoctors/services/backend_config.dart';

class DiseaseApiService {
  DiseaseApiService({required Uri baseUrl, http.Client? client})
    : _baseUrl = baseUrl,
      _client = client ?? http.Client();

  factory DiseaseApiService.fromEnv({http.Client? client}) {
    return DiseaseApiService(
      baseUrl: BackendConfig.diseaseApiBaseUri(),
      client: client,
    );
  }

  final Uri _baseUrl;
  final http.Client _client;

  String? _sessionId;
  String? _language;

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
    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'language': language}),
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      throw SocketException(
        'Failed to reach Disease API at $_baseUrl (SocketException: ${e.message}). '
        'Check that the backend is reachable and that DISEASE_API_BASE_URL is set correctly '
        '(default: https://lunchbox-blabber-unworn.ngrok-free.dev).',
        osError: e.osError,
        address: e.address,
        port: e.port,
      );
    } on HttpException catch (e) {
      throw HttpException(
        'Failed to reach Disease API at $_baseUrl: ${e.message}',
      );
    } on FormatException catch (e) {
      throw FormatException(
        'Failed to reach Disease API at $_baseUrl: ${e.message}',
        e.source,
        e.offset,
      );
    } on Exception catch (e) {
      throw Exception('Failed to reach Disease API at $_baseUrl: $e');
    }

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
      final fallbackDiagnosis = await recommendDoctor(question);
      if (!_looksLikeUnknownDiagnosis(fallbackDiagnosis)) {
        return fallbackDiagnosis;
      }
      return answer;
    } catch (e) {
      askError = e;
      try {
        return await recommendDoctor(question);
      } catch (predictError) {
        throw Exception(
          'Both /ask and /recommend failed. ask: $askError; recommend: $predictError',
        );
      }
    }
  }

  Future<dynamic> _predictThenAskFallback(String text) async {
    late Object predictError;
    try {
      final diagnosis = await recommendDoctor(text);
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
          'Both /recommend and /ask failed. recommend: $predictError; ask: $askError',
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
      'didn\'t recognise',
      'didn\'t recognize',
      'try asking about',
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
        predicted.contains('cannot determine') ||
        predicted.contains('unable to make a confident prediction')) {
      return true;
    }
    // If it's a generic info request and confidence is low, it might be unknown
    if (predicted == 'information request' && response.confidence < 1.0) {
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
          body: jsonEncode({
            'question': question,
            'session_id': _sessionId,
            'language': _language,
          }),
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

  Future<DiagnosisResponse> recommendDoctor(String text) async {
    final uri = _endpointUri('recommend');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'session_id': _sessionId,
            'language': _language,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend /recommend failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected /recommend response shape');
    }

    return DiagnosisResponse.fromJson(data);
  }

  Future<DiagnosisResponse> predictFromText(String text) async {
    final uri = _endpointUri('predict/text');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'session_id': _sessionId,
            'language': _language,
          }),
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
}
