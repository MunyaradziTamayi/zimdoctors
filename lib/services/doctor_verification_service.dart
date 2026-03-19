import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zimdoctors/services/doctor_registry_verification_service.dart';

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

  DoctorVerificationService({
    FirebaseFirestore? firestore,
    DoctorRegistryVerificationService? registryVerificationService,
    this.cacheTtl = const Duration(days: 3650), // 10 years by default
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _registryVerificationService =
           registryVerificationService ?? DoctorRegistryVerificationService();

  Future<DoctorVerificationOutcome> verifyDoctor({
    required String username,
    required String registrationNumber,
  }) async {
    final usernameNormalized = _normalizeUsername(username);
    final regNormalized = _normalizeRegistrationNumber(registrationNumber);
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

    final registryUrl = _registryVerificationService.buildRegistryUrl(
      username: username,
      registrationNumber: registrationNumber,
    );
    final verified = await _registryVerificationService.verifyDoctor(
      username: username,
      registrationNumber: registrationNumber,
    );

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

  String _normalizeUsername(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\\s+'), ' ');
  }

  String _normalizeRegistrationNumber(String value) {
    final upper = value.trim().toUpperCase().replaceAll(RegExp(r'\\s+'), '');
    // Firestore doc IDs can't contain forward slashes. Keep it predictable.
    return upper.replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
  }

  DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
