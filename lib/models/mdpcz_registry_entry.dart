class MdpczRegistryEntry {
  final String registrationNumber;
  final String registrationNumberNormalized;
  final String fullName;
  final String fullNameNormalized;
  final List<String> nameTokens;
  final String gender;
  final String qualification;
  final String specialty;
  final int sourcePage;
  final String sourceUrl;
  final DateTime scrapedAt;

  MdpczRegistryEntry({
    required this.registrationNumber,
    required this.registrationNumberNormalized,
    required this.fullName,
    required this.fullNameNormalized,
    required this.nameTokens,
    required this.gender,
    required this.qualification,
    required this.specialty,
    required this.sourcePage,
    required this.sourceUrl,
    required this.scrapedAt,
  });

  factory MdpczRegistryEntry.fromMap(Map<String, dynamic> map, String docId) {
    return MdpczRegistryEntry(
      registrationNumber: (map['registrationNumber'] as String?)?.trim() ?? '',
      registrationNumberNormalized:
          (map['registrationNumberNormalized'] as String?)?.trim() ?? docId,
      fullName: (map['fullName'] as String?)?.trim() ?? '',
      fullNameNormalized: (map['fullNameNormalized'] as String?)?.trim() ?? '',
      nameTokens: List<String>.from(map['nameTokens'] ?? const <String>[]),
      gender: (map['gender'] as String?)?.trim() ?? '',
      qualification: (map['qualification'] as String?)?.trim() ?? '',
      specialty: (map['specialty'] as String?)?.trim() ?? '',
      sourcePage: (map['sourcePage'] as num?)?.toInt() ?? 0,
      sourceUrl: (map['sourceUrl'] as String?)?.trim() ?? '',
      scrapedAt: _mapToDateTime(map['scrapedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'registrationNumber': registrationNumber,
      'registrationNumberNormalized': registrationNumberNormalized,
      'fullName': fullName,
      'fullNameNormalized': fullNameNormalized,
      'nameTokens': nameTokens,
      'gender': gender,
      'qualification': qualification,
      'specialty': specialty,
      'sourcePage': sourcePage,
      'sourceUrl': sourceUrl,
      'scrapedAt': scrapedAt,
    };
  }

  static DateTime? _mapToDateTime(dynamic value) {
    if (value == null) return null;
    try {
      final dynamic toDate = (value as dynamic).toDate;
      if (toDate is Function) {
        final d = toDate.call();
        if (d is DateTime) return d;
      }
    } catch (_) {}
    return value is DateTime ? value : null;
  }
}

