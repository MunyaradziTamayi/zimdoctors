import 'package:zimdoctors/models/doctor.dart';

class DoctorRecommendation {
  final String specialty;
  final String urgency;
  final List<Doctor> doctors;

  DoctorRecommendation({
    required this.specialty,
    required this.urgency,
    required this.doctors,
  });
}
