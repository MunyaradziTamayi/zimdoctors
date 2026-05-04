import 'package:flutter_test/flutter_test.dart';
import 'package:zimdoctors/models/mdpcz_registry_entry.dart';
import 'package:zimdoctors/services/doctor_verification_service.dart';

void main() {
  test('Akhtar Maida / M 357818 matches normalized registry entry', () {
    final regNormalized =
        DoctorVerificationService.normalizeRegistrationNumberForVerification(
      'M 357818',
    );
    expect(regNormalized, 'M357818');

    final entry = MdpczRegistryEntry(
      registrationNumber: 'M 357818',
      registrationNumberNormalized: regNormalized,
      fullName: 'Akhtar Maida',
      fullNameNormalized: 'akhtar maida',
      nameTokens: const ['akhtar', 'maida'],
      gender: '',
      qualification: '',
      specialty: 'Medical Practitioner',
      sourcePage: 1,
      sourceUrl: 'https://mdpcz.co.zw/public_register?page=1',
      scrapedAt: DateTime(2026, 1, 1),
    );

    expect(
      DoctorVerificationService.matchesRegistryNameForVerification(
        'Akhtar Maida',
        entry,
      ),
      isTrue,
    );
  });
}

