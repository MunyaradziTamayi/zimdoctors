import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zimdoctors/services/doctor_registry_verification_service.dart';
import 'package:zimdoctors/models/mdpcz_registry_entry.dart';
import 'package:flutter/foundation.dart';

class DoctorVerificationOutcome {
  final bool isVerified;
  final bool fromCache;
  final DateTime? verifiedAt;
  final String verificationProvider;
  final String verificationUrl;

  DoctorVerificationOutcome({
    required this.isVerified,
    required this.fromCache,
    required this.verifiedAt,
    required this.verificationProvider,
    required this.verificationUrl,
  });
}

class DoctorVerificationService {
  final FirebaseFirestore _firestore;
  final DoctorRegistryVerificationService _registryVerificationService;
  final Duration cacheTtl;
  final String mdpczRegistryCollection;

  DoctorVerificationService({
    FirebaseFirestore? firestore,
    DoctorRegistryVerificationService? registryVerificationService,
    this.cacheTtl = const Duration(days: 3650), // 10 years by default
    this.mdpczRegistryCollection = 'mdpcz_registry',
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _registryVerificationService =
           registryVerificationService ?? DoctorRegistryVerificationService();

  Future<DoctorVerificationOutcome> verifyDoctor({
    required String username,
    required String registrationNumber,
  }) async {
    final usernameNormalized = _normalizeUsername(username);
    final regNormalized = _normalizeRegistrationNumber(registrationNumber);

    if (regNormalized.trim().isEmpty) {
      final nameOnlyOutcome = await _verifyAgainstMdpczRegistryByName(
        usernameNormalized: usernameNormalized,
      );
      if (nameOnlyOutcome != null) return nameOnlyOutcome;
    }

    final docRef = _firestore.collection('doctor_verifications').doc(regNormalized);

    final cached = await docRef.get();
    if (cached.exists) {
      final data = cached.data();
      if (data != null && (data['isVerified'] == true)) {
        final cachedUsername = (data['usernameNormalized'] as String?)?.trim();
        final verifiedAt = _toDateTime(data['verifiedAt']);
        final cacheValid = verifiedAt == null
            ? false
            : DateTime.now().difference(verifiedAt) <= cacheTtl;

        if (cachedUsername == usernameNormalized && cacheValid) {
          return DoctorVerificationOutcome(
            isVerified: true,
            fromCache: true,
            verifiedAt: verifiedAt,
            verificationProvider: (data['verificationProvider'] as String?)?.trim() ??
                'firecrawl',
            verificationUrl: (data['verificationUrl'] as String?)?.trim() ?? '',
          );
        }
      }
    }

    final registryOutcome = await _verifyAgainstMdpczRegistry(
      usernameNormalized: usernameNormalized,
      registrationNumberNormalized: regNormalized,
    );
    if (registryOutcome != null && registryOutcome.isVerified) {
      await docRef.set(
        <String, Object?>{
          'isVerified': true,
          'usernameNormalized': usernameNormalized,
          'registrationNumberNormalized': regNormalized,
          'verifiedAt': Timestamp.fromDate(registryOutcome.verifiedAt!),
          'verificationProvider': registryOutcome.verificationProvider,
          'verificationUrl': registryOutcome.verificationUrl,
        },
        SetOptions(merge: true),
      );
      return DoctorVerificationOutcome(
        isVerified: true,
        fromCache: false,
        verifiedAt: registryOutcome.verifiedAt,
        verificationProvider: registryOutcome.verificationProvider,
        verificationUrl: registryOutcome.verificationUrl,
      );
    }
    if (registryOutcome != null && !registryOutcome.isVerified) {
      return registryOutcome;
    }

    String registryUrl = '';
    bool verified = false;
    try {
      registryUrl = _registryVerificationService.buildRegistryUrl(
        username: username,
        registrationNumber: registrationNumber,
      );
      verified = await _registryVerificationService.verifyDoctor(
        username: username,
        registrationNumber: registrationNumber,
      );
    } on DoctorRegistryConfigException {
      // Firecrawl verification is optional. If it's not configured, treat as not verified.
      return DoctorVerificationOutcome(
        isVerified: false,
        fromCache: false,
        verifiedAt: null,
        verificationProvider: 'mdpcz_registry',
        verificationUrl: '',
      );
    }

    final now = DateTime.now();
    if (verified) {
      await docRef.set(
        <String, Object?>{
          'isVerified': true,
          'usernameNormalized': usernameNormalized,
          'registrationNumberNormalized': regNormalized,
          'verifiedAt': Timestamp.fromDate(now),
          'verificationProvider': 'firecrawl',
          'verificationUrl': registryUrl,
        },
        SetOptions(merge: true),
      );
    }

    return DoctorVerificationOutcome(
      isVerified: verified,
      fromCache: false,
      verifiedAt: verified ? now : null,
      verificationProvider: 'firecrawl',
      verificationUrl: registryUrl,
    );
  }

  Future<DoctorVerificationOutcome?> _verifyAgainstMdpczRegistry({
    required String usernameNormalized,
    required String registrationNumberNormalized,
  }) async {
    if (registrationNumberNormalized.trim().isEmpty) return null;
    final doc = await _firestore
        .collection(mdpczRegistryCollection)
        .doc(registrationNumberNormalized)
        .get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final entry = MdpczRegistryEntry.fromMap(data, doc.id);
    if (!_matchesRegistryName(usernameNormalized, entry)) {
      return DoctorVerificationOutcome(
        isVerified: false,
        fromCache: false,
        verifiedAt: null,
        verificationProvider: 'mdpcz_registry',
        verificationUrl: entry.sourceUrl,
      );
    }

    final now = DateTime.now();
    return DoctorVerificationOutcome(
      isVerified: true,
      fromCache: false,
      verifiedAt: now,
      verificationProvider: 'mdpcz_registry',
      verificationUrl: entry.sourceUrl,
    );
  }

  Future<DoctorVerificationOutcome?> _verifyAgainstMdpczRegistryByName({
    required String usernameNormalized,
  }) async {
    // Prefer an exact normalized full-name hit (Excel import + registry scrape both write this).
    final exactSnapshot = await _firestore
        .collection(mdpczRegistryCollection)
        .where('fullNameNormalized', isEqualTo: usernameNormalized)
        .limit(5)
        .get();

    if (exactSnapshot.docs.isNotEmpty) {
      final now = DateTime.now();
      return DoctorVerificationOutcome(
        isVerified: true,
        fromCache: false,
        verifiedAt: now,
        verificationProvider: 'mdpcz_registry',
        verificationUrl: '',
      );
    }

    final userTokens = usernameNormalized
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.length >= 2)
        .toList();
    if (userTokens.isEmpty) return null;

    // Firestore only supports "arrayContains" on one value, so query by the first
    // token and filter candidates client-side.
    final snapshot = await _firestore
        .collection(mdpczRegistryCollection)
        .where('nameTokens', arrayContains: userTokens.first)
        .limit(50)
        .get();
    if (snapshot.docs.isEmpty) return null;

    final matches = <MdpczRegistryEntry>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final entry = MdpczRegistryEntry.fromMap(data, doc.id);
      if (_matchesRegistryName(usernameNormalized, entry)) {
        matches.add(entry);
      }
    }

    if (matches.isEmpty) {
      return DoctorVerificationOutcome(
        isVerified: false,
        fromCache: false,
        verifiedAt: null,
        verificationProvider: 'mdpcz_registry',
        verificationUrl: '',
      );
    }

    // If multiple doctors match the same name tokens, require registration number.
    if (matches.length > 1) {
      return DoctorVerificationOutcome(
        isVerified: false,
        fromCache: false,
        verifiedAt: null,
        verificationProvider: 'mdpcz_registry',
        verificationUrl: '',
      );
    }

    final now = DateTime.now();
    return DoctorVerificationOutcome(
      isVerified: true,
      fromCache: false,
      verifiedAt: now,
      verificationProvider: 'mdpcz_registry',
      verificationUrl: matches.single.sourceUrl,
    );
  }

  bool _matchesRegistryName(String usernameNormalized, MdpczRegistryEntry entry) {
    final userTokens =
        usernameNormalized.split(' ').map((t) => t.trim()).where((t) => t.length >= 2).toList();
    if (userTokens.isEmpty) return false;

    final registryTokens =
        entry.nameTokens.isNotEmpty ? entry.nameTokens : entry.fullNameNormalized.split(' ').toList();

    final first = userTokens.first;
    final last = userTokens.length >= 2 ? userTokens.last : '';

    if (!registryTokens.contains(first)) return false;
    if (last.isNotEmpty && !registryTokens.contains(last)) return false;

    // Require at least 2 overlaps when possible (first + last), otherwise 1 overlap for single-token names.
    final overlaps = userTokens.where(registryTokens.contains).length;
    return userTokens.length == 1 ? overlaps >= 1 : overlaps >= 2;
  }

  @visibleForTesting
  static String normalizeUsernameForVerification(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  @visibleForTesting
  static String normalizeRegistrationNumberForVerification(String value) {
    final upper = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return upper.replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
  }

  @visibleForTesting
  static bool matchesRegistryNameForVerification(
    String username,
    MdpczRegistryEntry entry,
  ) {
    final usernameNormalized = normalizeUsernameForVerification(username);
    final userTokens = usernameNormalized
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.length >= 2)
        .toList();
    if (userTokens.isEmpty) return false;

    final registryTokens =
        entry.nameTokens.isNotEmpty ? entry.nameTokens : entry.fullNameNormalized.split(' ').toList();

    final first = userTokens.first;
    final last = userTokens.length >= 2 ? userTokens.last : '';

    if (!registryTokens.contains(first)) return false;
    if (last.isNotEmpty && !registryTokens.contains(last)) return false;

    final overlaps = userTokens.where(registryTokens.contains).length;
    return userTokens.length == 1 ? overlaps >= 1 : overlaps >= 2;
  }

  String _normalizeUsername(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeRegistrationNumber(String value) {
    final upper = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    // Firestore doc IDs can't contain forward slashes. Keep it predictable.
    return upper.replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
  }

  DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
