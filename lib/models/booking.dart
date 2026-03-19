import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String reason;
  final String date;
  final String time;
  final String status; // 'pending', 'confirmed', 'cancelled'
  final String paymentStatus; // 'unpaid', 'paid', 'pending'
  final String? transactionRef;
  final double amount;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.reason,
    required this.date,
    required this.time,
    required this.status,
    required this.paymentStatus,
    this.transactionRef,
    required this.amount,
    required this.createdAt,
  });

  factory Booking.fromMap(Map<String, dynamic> map, String documentId) {
    return Booking(
      id: documentId,
      doctorId: map['doctorId'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      reason: map['reason'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      status: map['status'] ?? 'pending',
      paymentStatus: map['paymentStatus'] ?? 'unpaid',
      transactionRef: map['transactionRef'],
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
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
      'reason': reason,
      'date': date,
      'time': time,
      'status': status,
      'paymentStatus': paymentStatus,
      'transactionRef': transactionRef,
      'amount': amount,
      'createdAt': createdAt,
    };
  }
}
