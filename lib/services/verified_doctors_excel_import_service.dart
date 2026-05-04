import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:zimdoctors/models/mdpcz_registry_entry.dart';
import 'package:zimdoctors/services/mdpcz_registry_sync_service.dart';

class VerifiedDoctorsExcelImportResult {
  final int rowsRead;
  final int entriesUpserted;
  final DateTime startedAt;
  final DateTime finishedAt;

  VerifiedDoctorsExcelImportResult({
    required this.rowsRead,
    required this.entriesUpserted,
    required this.startedAt,
    required this.finishedAt,
  });
}

class VerifiedDoctorsExcelImportService {
  final FirebaseFirestore? _firestore;
  final String collectionName;
  final String assetPath;

  VerifiedDoctorsExcelImportService({
    FirebaseFirestore? firestore,
    this.collectionName = 'mdpcz_registry',
    this.assetPath = 'assets/verifiedDoctors.xlsx',
  }) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<VerifiedDoctorsExcelImportResult> importIntoFirestore() async {
    final startedAt = DateTime.now();

    final bytes = await rootBundle.load(assetPath);
    final data = bytes.buffer.asUint8List();

    final excel = Excel.decodeBytes(data);
    final sheetName = excel.tables.keys.isNotEmpty
        ? excel.tables.keys.first
        : null;
    if (sheetName == null) {
      throw Exception('Excel file has no sheets.');
    }

    final sheet = excel.tables[sheetName];
    if (sheet == null) {
      throw Exception('Failed to read Excel sheet: $sheetName');
    }

    final now = DateTime.now();
    final out = <MdpczRegistryEntry>[];
    var rowsRead = 0;

    final headerMap = _inferHeaderMap(sheet.rows);

    for (final row in sheet.rows) {
      final values = row.map(_cellToString).toList();
      if (values.every((v) => v.trim().isEmpty)) continue;

      // Skip header row if it looks like one.
      if (_looksLikeHeader(values)) continue;

      rowsRead += 1;

      final fullName = _valueByHeader(
        values,
        headerMap,
        keys: const ['name', 'full name', 'full_name', 'doctor', 'doctor name'],
        fallbackIndex: 0,
      );
      if (fullName.trim().isEmpty) continue;

      final registrationNumber = _valueByHeader(
        values,
        headerMap,
        keys: const ['reg', 'reg no', 'reg number', 'registration', 'registration number'],
        fallbackIndex: 1,
      );

      final specialty = _valueByHeader(
        values,
        headerMap,
        keys: const ['specialty', 'speciality', 'category', 'profession'],
        fallbackIndex: 2,
      );

      final regNormalized = registrationNumber.trim().isEmpty
          ? 'NAME_${MdpczRegistrySyncService.normalizeFullName(fullName).replaceAll(' ', '_')}'
          : MdpczRegistrySyncService.normalizeRegistrationNumber(registrationNumber);

      final nameNormalized = MdpczRegistrySyncService.normalizeFullName(fullName);

      out.add(
        MdpczRegistryEntry(
          registrationNumber: registrationNumber.trim(),
          registrationNumberNormalized: regNormalized,
          fullName: fullName.trim(),
          fullNameNormalized: nameNormalized,
          nameTokens: MdpczRegistrySyncService.tokenizeName(nameNormalized),
          gender: '',
          qualification: '',
          specialty: specialty.trim(),
          sourcePage: 0,
          sourceUrl: assetPath,
          scrapedAt: now,
        ),
      );
    }

    final written = await _upsertEntries(out);
    final finishedAt = DateTime.now();
    return VerifiedDoctorsExcelImportResult(
      rowsRead: rowsRead,
      entriesUpserted: written,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
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
      final docId = entry.registrationNumberNormalized.trim();
      if (docId.isEmpty) continue;
      batch.set(coll.doc(docId), entry.toMap(), SetOptions(merge: true));
      written += 1;
      ops += 1;
      if (ops >= 450) await commitBatch();
    }

    await commitBatch();
    return written;
  }

  static String _cellToString(Data? cell) {
    if (cell == null) return '';
    final v = cell.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  static bool _looksLikeHeader(List<String> rowValues) {
    final joined = rowValues.map((e) => e.toLowerCase()).join(' | ');
    return joined.contains('name') &&
        (joined.contains('reg') || joined.contains('registration'));
  }

  static Map<String, int> _inferHeaderMap(List<List<Data?>> rows) {
    for (final row in rows) {
      final values = row.map(_cellToString).toList();
      if (!_looksLikeHeader(values)) continue;
      final map = <String, int>{};
      for (var i = 0; i < values.length; i++) {
        final key = values[i].toLowerCase().trim();
        if (key.isEmpty) continue;
        map[key] = i;
      }
      return map;
    }
    return const <String, int>{};
  }

  static String _valueByHeader(
    List<String> values,
    Map<String, int> headerMap, {
    required List<String> keys,
    required int fallbackIndex,
  }) {
    for (final key in keys) {
      final idx = headerMap[key];
      if (idx != null && idx >= 0 && idx < values.length) {
        final v = values[idx].trim();
        if (v.isNotEmpty) return v;
      }
    }
    if (fallbackIndex >= 0 && fallbackIndex < values.length) {
      return values[fallbackIndex].trim();
    }
    return '';
  }
}

