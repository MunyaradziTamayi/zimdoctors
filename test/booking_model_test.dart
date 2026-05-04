import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zimdoctors/models/booking.dart';

void main() {
  test('Booking.fromMap defaults missing fields', () {
    final booking = Booking.fromMap(
      {
        'doctorId': 'd1',
        'patientId': 'p1',
        'patientName': 'Pat',
        'reason': 'Checkup',
        'date': '2026-04-30',
        'time': '10:00',
        'amount': 25,
        // intentionally omit status/paymentStatus/transactionRef/createdAt
      },
      'b1',
    );

    expect(booking.id, 'b1');
    expect(booking.status, 'pending');
    expect(booking.paymentStatus, 'unpaid');
    expect(booking.transactionRef, isNull);
    expect(booking.amount, 25.0);
    expect(booking.createdAt, isA<DateTime>());
  });

  test('Booking.fromMap converts Timestamp to DateTime', () {
    final ts = Timestamp.fromMillisecondsSinceEpoch(1713000000000);
    final booking = Booking.fromMap(
      {
        'doctorId': 'd1',
        'patientId': 'p1',
        'patientName': 'Pat',
        'reason': 'Checkup',
        'date': '2026-04-30',
        'time': '10:00',
        'status': 'confirmed',
        'paymentStatus': 'paid',
        'transactionRef': 'ref',
        'amount': 25.5,
        'createdAt': ts,
      },
      'b1',
    );

    expect(booking.createdAt, ts.toDate());
  });

  test('Booking.toMap preserves important fields', () {
    final createdAt = DateTime(2026, 4, 22, 10, 11, 12);
    final booking = Booking(
      id: 'b1',
      doctorId: 'd1',
      patientId: 'p1',
      patientName: 'Pat',
      reason: 'Checkup',
      date: '2026-04-30',
      time: '10:00',
      status: 'pending',
      paymentStatus: 'paid',
      transactionRef: 'tx',
      amount: 25.0,
      createdAt: createdAt,
    );

    final map = booking.toMap();
    expect(map['doctorId'], 'd1');
    expect(map['patientId'], 'p1');
    expect(map['paymentStatus'], 'paid');
    expect(map['transactionRef'], 'tx');
    expect(map['createdAt'], createdAt);
  });
}

