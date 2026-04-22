import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class DoctorRegistryConfigException implements Exception {
  final String message;
  DoctorRegistryConfigException(this.message);

  @override
  String toString() => message;
}

class DoctorRegistryVerificationException implements Exception {
  final String message;
  DoctorRegistryVerificationException(this.message);

  @override
  String toString() => message;
}

class DoctorRegistryVerificationService {
  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  DoctorRegistryVerificationService({
    http.Client? client,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? dotenv.env['FIRECRAWL_API_BASE_URL'] ?? '')
           .trim()
           .isEmpty
           ? 'https://api.firecrawl.dev'
           : (baseUrl ?? dotenv.env['FIRECRAWL_API_BASE_URL']!).trim(),
       _timeout = timeout;

  String buildRegistryUrl({
    required String username,
    required String registrationNumber,
  }) {
    final registryUrlTemplate = dotenv.env['DOCTOR_REGISTRY_SEARCH_URL']?.trim();
    if (registryUrlTemplate == null || registryUrlTemplate.isEmpty) {
      throw DoctorRegistryConfigException(
        'DOCTOR_REGISTRY_SEARCH_URL not configured',
      );
    }

    return _interpolateRegistryUrl(
      registryUrlTemplate,
      username: username,
      registrationNumber: registrationNumber,
    );
  }

  Future<bool> verifyDoctor({
    required String username,
    required String registrationNumber,
  }) async {
    final apiKey = dotenv.env['FIRECRAWL_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw DoctorRegistryConfigException('FIRECRAWL_API_KEY not configured');
    }

    final registryUrl = buildRegistryUrl(
      username: username,
      registrationNumber: registrationNumber,
    );

    final uri = Uri.parse('$_baseUrl/v1/scrape');
    final payload = <String, Object?>{
      'url': registryUrl,
      'formats': const ['markdown', 'html'],
      'onlyMainContent': true,
    };

    final res = await _client
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DoctorRegistryVerificationException(
        'Firecrawl failed (${res.statusCode})',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw DoctorRegistryVerificationException('Unexpected Firecrawl response');
    }

    if (decoded['success'] == false) {
      throw DoctorRegistryVerificationException('Firecrawl returned success=false');
    }

    final text = _collectAllStrings(decoded).join('\n').toLowerCase();
    if (text.trim().isEmpty) {
      throw DoctorRegistryVerificationException(
        'No content returned from registry page',
      );
    }

    return _matches(text, username: username, registrationNumber: registrationNumber);
  }

  String _interpolateRegistryUrl(
    String template, {
    required String username,
    required String registrationNumber,
  }) {
    return template
        .replaceAll('{username}', Uri.encodeComponent(username))
        .replaceAll(
          '{registrationNumber}',
          Uri.encodeComponent(registrationNumber),
        );
  }

  bool _matches(
    String text, {
    required String username,
    required String registrationNumber,
  }) {
    final regNeedle = registrationNumber.trim().toLowerCase();
    if (regNeedle.isEmpty || !text.contains(regNeedle)) return false;

    final tokens = username
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 2)
        .toList();
    if (tokens.isEmpty) return false;

    return tokens.every(text.contains);
  }

  List<String> _collectAllStrings(Object? value) {
    final out = <String>[];

    void walk(Object? node) {
      if (node == null) return;
      if (node is String) {
        out.add(node);
        return;
      }
      if (node is num || node is bool) return;
      if (node is List) {
        for (final e in node) {
          walk(e);
        }
        return;
      }
      if (node is Map) {
        for (final e in node.values) {
          walk(e);
        }
        return;
      }
    }

    walk(value);

    if (kDebugMode) {
      debugPrint('DoctorRegistryVerificationService: collected ${out.length} strings');
    }
    return out;
  }
}
