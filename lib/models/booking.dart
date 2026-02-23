import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String date;
  final String time;
  final String status; // 'pending', 'confirmed', 'cancelled'
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.time,
    required this.status,
    required this.createdAt,
  });

  factory Booking.fromMap(Map<String, dynamic> map, String documentId) {
    return Booking(
      id: documentId,
      doctorId: map['doctorId'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'date': date,
      'time': time,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
