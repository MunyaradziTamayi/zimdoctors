class Doctor {
  final String id;
  final String name;
  final String registrationNumber;
  final String specialty;
  final double rating;
  final String image;
  final String location;
  final String surgeryLocation;
  final String phoneNumber;
  final String experience;
  final int patients;
  final int fee;
  final int followUp;
  final String code;
  final String joined;
  final String description;
  final List<String> availableDates;
  final Map<String, List<String>> availabilitySlots;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String verificationProvider;
  final String verificationUrl;

  Doctor({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.specialty,
    required this.rating,
    required this.image,
    required this.experience,
    required this.patients,
    required this.fee,
    required this.followUp,
    required this.code,
    required this.joined,
    required this.location,
    this.surgeryLocation = '',
    required this.phoneNumber,
    required this.description,
    required this.availableDates,
    required this.availabilitySlots,
    this.isVerified = false,
    this.verifiedAt,
    this.verificationProvider = '',
    this.verificationUrl = '',
  });

  factory Doctor.fromMap(Map<String, dynamic> map, String documentId) {
    Map<String, List<String>> slots = {};
    if (map['availabilitySlots'] != null) {
      (map['availabilitySlots'] as Map<String, dynamic>).forEach((key, value) {
        slots[key] = List<String>.from(value);
      });
    }

    return Doctor(
      id: documentId,
      name: map['name'] ?? '',
      registrationNumber: map['registrationNumber'] ?? '',
      specialty: map['specialty'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      image: map['image'] ?? '',
      location: map['location'] ?? '',
      surgeryLocation: map['surgeryLocation'] ?? map['workplace'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      experience: map['experience'] ?? '',
      patients: map['patients'] ?? 0,
      fee: map['fee'] ?? 0,
      followUp: map['followUp'] ?? 0,
      code: map['code'] ?? '',
      joined: map['joined'] ?? '',
      description: map['description'] ?? '',
      availableDates: List<String>.from(map['availableDates'] ?? []),
      availabilitySlots: slots,
      isVerified: map['isVerified'] ?? false,
      verifiedAt: _mapToDateTime(map['verifiedAt']),
      verificationProvider: map['verificationProvider'] ?? '',
      verificationUrl: map['verificationUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'registrationNumber': registrationNumber,
      'specialty': specialty,
      'rating': rating,
      'image': image,
      'location': location,
      'surgeryLocation': surgeryLocation,
      'phoneNumber': phoneNumber,
      'experience': experience,
      'patients': patients,
      'fee': fee,
      'followUp': followUp,
      'code': code,
      'joined': joined,
      'description': description,
      'availableDates': availableDates,
      'availabilitySlots': availabilitySlots,
      'isVerified': isVerified,
      'verifiedAt': verifiedAt,
      'verificationProvider': verificationProvider,
      'verificationUrl': verificationUrl,
    };
  }

  static DateTime? _mapToDateTime(dynamic value) {
    if (value == null) return null;
    // Firestore Timestamp has a `toDate()` method, but we avoid importing it here.
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
