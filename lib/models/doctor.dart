class Doctor {
  final String id;
  final String name;
  final String specialty;
  final double rating;
  final String image;
  final String location;
  final String phoneNumber;
  final String experience;
  final int patients;
  final int fee;
  final int followUp;
  final String code;
  final String joined;
  final String description;

  Doctor({
    required this.id,
    required this.name,
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
    required this.phoneNumber,
    required this.description,
  });

  factory Doctor.fromMap(Map<String, dynamic> map, String documentId) {
    return Doctor(
      id: documentId,
      name: map['name'] ?? '',
      specialty: map['specialty'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      image: map['image'] ?? '',
      location: map['location'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      experience: map['experience'] ?? '',
      patients: map['patients'] ?? 0,
      fee: map['fee'] ?? 0,
      followUp: map['followUp'] ?? 0,
      code: map['code'] ?? '',
      joined: map['joined'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'specialty': specialty,
      'rating': rating,
      'image': image,
      'location': location,
      'phoneNumber': phoneNumber,
      'experience': experience,
      'patients': patients,
      'fee': fee,
      'followUp': followUp,
      'code': code,
      'joined': joined,
      'description': description,
    };
  }
}
