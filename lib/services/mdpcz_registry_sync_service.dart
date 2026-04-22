import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:zimdoctors/models/mdpcz_registry_entry.dart';

class MdpczRegistryScrapeException implements Exception {
  final String message;
  MdpczRegistryScrapeException(this.message);
  @override
  String toString() => message;
}

class MdpczRegistryPageResult {
  final int page;
  final int? lastPage;
  final List<MdpczRegistryEntry> entries;

  MdpczRegistryPageResult({
    required this.page,
    required this.lastPage,
    required this.entries,
  });
}

class MdpczRegistrySyncResult {
  final int pagesFetched;
  final int entriesUpserted;
  final DateTime startedAt;
  final DateTime finishedAt;

  MdpczRegistrySyncResult({
    required this.pagesFetched,
    required this.entriesUpserted,
    required this.startedAt,
    required this.finishedAt,
  });
}

typedef MdpczProgress = void Function({
  required int page,
  required int? lastPage,
  required int entriesFetched,
  required int entriesUpsertedSoFar,
});

class MdpczRegistrySyncService {
  static const String _baseUrl = 'https://mdpcz.co.zw/public_register';

  final FirebaseFirestore? _firestore;
  final http.Client _client;
  final String collectionName;
  final Duration pageTimeout;
  final Duration politeDelay;

  MdpczRegistrySyncService({
    FirebaseFirestore? firestore,
    http.Client? client,
    this.collectionName = 'mdpcz_registry',
    this.pageTimeout = const Duration(seconds: 30),
    this.politeDelay = const Duration(milliseconds: 250),
  }) : _firestore = firestore,
       _client = client ?? http.Client();

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<MdpczRegistrySyncResult> syncAll({
    int startPage = 1,
    int? endPage,
    MdpczProgress? onProgress,
  }) async {
    final startedAt = DateTime.now();

    var pagesFetched = 0;
    var entriesUpserted = 0;

    final first = await fetchPage(startPage);
    pagesFetched += 1;

    final computedLastPage = endPage ??
        (first.lastPage == null || first.lastPage! < startPage
            ? startPage
            : first.lastPage!);

    entriesUpserted += await _upsertEntries(first.entries);
    onProgress?.call(
      page: startPage,
      lastPage: computedLastPage,
      entriesFetched: first.entries.length,
      entriesUpsertedSoFar: entriesUpserted,
    );

    for (var page = startPage + 1; page <= computedLastPage; page++) {
      if (politeDelay > Duration.zero) {
        await Future<void>.delayed(politeDelay);
      }

      final res = await fetchPage(page);
      pagesFetched += 1;
      entriesUpserted += await _upsertEntries(res.entries);

      onProgress?.call(
        page: page,
        lastPage: computedLastPage,
        entriesFetched: res.entries.length,
        entriesUpsertedSoFar: entriesUpserted,
      );
    }

    final finishedAt = DateTime.now();
    return MdpczRegistrySyncResult(
      pagesFetched: pagesFetched,
      entriesUpserted: entriesUpserted,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }

  Future<MdpczRegistryPageResult> fetchPage(int page) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {'page': '$page'});
    final res = await _client
        .get(
          uri,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
          },
        )
        .timeout(pageTimeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MdpczRegistryScrapeException(
        'MDPCZ register request failed (${res.statusCode})',
      );
    }

    final html = res.body;
    final doc = html_parser.parse(html);

    final tbody = doc.querySelector('table tbody');
    if (tbody == null) {
      throw MdpczRegistryScrapeException(
        'MDPCZ register page structure changed (missing table body)',
      );
    }

    final now = DateTime.now();
    final out = <MdpczRegistryEntry>[];
    for (final row in tbody.querySelectorAll('tr')) {
      final cols = row.querySelectorAll('td').map((e) => e.text.trim()).toList();
      if (cols.length < 3) continue;

      final fullName = cols.elementAtOrNull(0) ?? '';
      final gender = cols.elementAtOrNull(1) ?? '';
      final reg = cols.elementAtOrNull(2) ?? '';
      final qualification = cols.length >= 4 ? cols[3] : '';
      final specialty = cols.length >= 5 ? cols[4] : '';

      if (fullName.trim().isEmpty || reg.trim().isEmpty) continue;

      final regNormalized = normalizeRegistrationNumber(reg);
      final nameNormalized = normalizeFullName(fullName);

      out.add(
        MdpczRegistryEntry(
          registrationNumber: reg.trim(),
          registrationNumberNormalized: regNormalized,
          fullName: fullName.trim(),
          fullNameNormalized: nameNormalized,
          nameTokens: tokenizeName(nameNormalized),
          gender: gender,
          qualification: qualification,
          specialty: specialty,
          sourcePage: page,
          sourceUrl: uri.toString(),
          scrapedAt: now,
        ),
      );
    }

    final lastPage = _extractLastPage(html);

    return MdpczRegistryPageResult(page: page, lastPage: lastPage, entries: out);
  }

  Future<int> _upsertEntries(List<MdpczRegistryEntry> entries) async {
    if (entries.isEmpty) return 0;

    final coll = firestore.collection(collectionName);

    var written = 0;
    var batch = firestore.batch();
    var ops = 0;

    Future<void> commitBatch() async {
      if (ops == 0) return;
      await batch.commit();
      batch = firestore.batch();
      ops = 0;
    }

    for (final entry in entries) {
      final docId = entry.registrationNumberNormalized;
      if (docId.trim().isEmpty) continue;
      final ref = coll.doc(docId);
      batch.set(ref, entry.toMap(), SetOptions(merge: true));
      ops += 1;
      written += 1;

      if (ops >= 450) {
        await commitBatch();
      }
    }

    await commitBatch();
    return written;
  }

  static String normalizeRegistrationNumber(String value) {
    final upper = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return upper.replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
  }

  static String normalizeFullName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> tokenizeName(String normalizedFullName) {
    return normalizedFullName
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.length >= 2)
        .toList();
  }

  static int? _extractLastPage(String html) {
    final matches = RegExp(r"gotoPage\((\d+),\s*'page'\)")
        .allMatches(html)
        .map((m) => int.tryParse(m.group(1) ?? ''))
        .whereType<int>()
        .toList();

    if (matches.isEmpty) return null;
    matches.sort();
    return matches.last;
  }
}

extension _ListSafeX<T> on List<T> {
  T? elementAtOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
}
