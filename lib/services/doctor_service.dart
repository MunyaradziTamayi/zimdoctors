import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/models/booking.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zimdoctors/services/notification_service.dart';
import 'package:zimdoctors/services/disease_api_service.dart';

class DoctorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'doctors';
  final NotificationService _notificationService = NotificationService();
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'zimdoctors-1021d.firebasestorage.app',
  );
  final DiseaseApiService _apiService = DiseaseApiService.fromEnv();

  // Get stream of all doctors
  Stream<List<Doctor>> getDoctors() {
    return _firestore.collection(_collectionName).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Doctor.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get single doctor
  Future<Doctor?> getDoctorById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_collectionName)
          .doc(id)
          .get();
      if (doc.exists) {
        return Doctor.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting doctor: $e');
      return null;
    }
  }


 
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    print('Starting doctor image upload for $userId');
    if (!await imageFile.exists()) {
      print('Error: Image file does not exist at path: ${imageFile.path}');
      throw Exception('Image file not found');
    }

    try {
      final Reference ref = _storage.ref().child('doctor_images/$userId.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final UploadTask uploadTask = ref.putFile(imageFile, metadata);

      final TaskSnapshot snapshot = await uploadTask;
      if (snapshot.state == TaskState.success) {
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        print('Doctor image uploaded successfully: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }
    } catch (e) {
      print('Error uploading doctor image: $e');
      rethrow;
    }
  }

  
  Future<void> createDoctor(Doctor doctor) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(doctor.id)
          .set(doctor.toMap());
    } catch (e) {
      print('Error creating doctor: $e');
      throw e;
    }
  }

 
  Future<void> addDoctor(Doctor doctor) async {
    await _firestore.collection(_collectionName).add(doctor.toMap());
  }

 
  Future<void> updateDoctor(Doctor doctor) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(doctor.id)
          .update(doctor.toMap());
    } catch (e) {
      print('Error updating doctor: $e');
      throw e;
    }
  }

  
  Future<void> createBooking(Booking booking) async {
    try {
      final docRef = await _firestore.collection('bookings').add(booking.toMap());
      await _notificationService.sendNotification(
        userId: booking.doctorId,
        title: 'New Appointment',
        body: 'You have a new booking from ${booking.patientName} on ${booking.date} at ${booking.time}. Reason: ${booking.reason}',
        type: 'booking',
        data: {
          'bookingId': docRef.id,
          'doctorId': booking.doctorId,
          'patientId': booking.patientId,
          'date': booking.date,
          'time': booking.time,
          'reason': booking.reason,
        },
      );
    } catch (e) {
      print('Error creating booking: $e');
      throw e;
    }
  }

  Future<void> createBookingAtomic(Booking booking) async {
    late DocumentReference<Map<String, dynamic>> docRef;
    await _firestore.runTransaction((transaction) async {
      
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('doctorId', isEqualTo: booking.doctorId)
          .where('date', isEqualTo: booking.date)
          .where('time', isEqualTo: booking.time)
          .where('status', isNotEqualTo: 'cancelled')
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        throw Exception('This slot has already been booked by another patient.');
      }

      docRef = _firestore.collection('bookings').doc();
      transaction.set(docRef, booking.toMap());
    });

    
    await _notificationService.sendNotification(
      userId: booking.doctorId,
      title: 'New Appointment',
      body: 'You have a new booking from ${booking.patientName} on ${booking.date} at ${booking.time}. Reason: ${booking.reason}',
      type: 'booking',
      data: {
        'bookingId': docRef.id,
        'doctorId': booking.doctorId,
        'patientId': booking.patientId,
        'date': booking.date,
        'time': booking.time,
        'reason': booking.reason,
      },
    );
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': status,
    });
  }

  Future<void> rescheduleBookingAtomic({
    required String bookingId,
    required String newDate,
    required String newTime,
  }) async {
    String doctorId = '';
    String patientName = 'Patient';
    String oldDate = '';
    String oldTime = '';

    await _firestore.runTransaction((transaction) async {
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) {
        throw Exception('Booking not found.');
      }

      final data = bookingSnap.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'pending') as String;
      final paymentStatus = (data['paymentStatus'] ?? 'unpaid') as String;

      if (status == 'cancelled') {
        throw Exception('This booking has been cancelled.');
      }
      if (paymentStatus != 'paid') {
        throw Exception('Only paid bookings can be rescheduled.');
      }

      doctorId = (data['doctorId'] ?? '') as String;
      patientName = (data['patientName'] ?? 'Patient') as String;
      oldDate = (data['date'] ?? '') as String;
      oldTime = (data['time'] ?? '') as String;

      if (doctorId.isEmpty) {
        throw Exception('Booking is missing doctorId.');
      }

      final existing = await _firestore
          .collection('bookings')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: newDate)
          .where('time', isEqualTo: newTime)
          .where('status', isNotEqualTo: 'cancelled')
          .get();

      final conflict = existing.docs.any((d) => d.id != bookingId);
      if (conflict) {
        throw Exception('That slot is already booked.');
      }

      transaction.update(bookingRef, {
        'date': newDate,
        'time': newTime,
        'status': 'pending',
        'rescheduledAt': FieldValue.serverTimestamp(),
        'rescheduledFrom': {'date': oldDate, 'time': oldTime},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _notificationService.sendNotification(
      userId: doctorId,
      title: 'Appointment Rescheduled',
      body:
          '$patientName requested to reschedule: $oldDate $oldTime → $newDate $newTime. Please confirm the new slot.',
      type: 'booking_reschedule',
      data: {
        'bookingId': bookingId,
        'doctorId': doctorId,
        'date': newDate,
        'time': newTime,
        'oldDate': oldDate,
        'oldTime': oldTime,
      },
    );
  }

  Stream<List<Booking>> getBookingsForDoctor(String doctorId) {
    return _firestore
        .collection('bookings')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs.map((doc) {
            return Booking.fromMap(doc.data(), doc.id);
          }).toList();
       
          bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return bookings;
        });
  }

 
  Future<Doctor?> getCurrentDoctor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return getDoctorById(user.uid);
    }
    return null;
  }

  
  Future<bool> isSlotBooked(String doctorId, String date, String time) async {
    try {
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('time', isEqualTo: time)
          .where('status', isNotEqualTo: 'cancelled')
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking slot: $e');
      return false;
    }
  }

  /// AI-Powered Doctor Match
  /// Uses symptoms to find the best specialist and returns matching doctors from Firestore.
  Future<List<Doctor>> findDoctorMatch(String symptoms) async {
    try {
      // 1. Get specialist recommendation from AI
      final diagnosis = await _apiService.predictFromText(symptoms);
      final specialist = diagnosis.suggestedSpecialist;

      if (specialist == null || specialist == 'General Practitioner') {
        // If no specific specialist, return top rated or all
        final snapshot = await _firestore.collection(_collectionName).limit(10).get();
        return snapshot.docs.map((doc) => Doctor.fromMap(doc.data(), doc.id)).toList();
      }

      // 2. Search Firestore for doctors with that specialty
      // Note: This assumes the 'specialization' field in Firestore matches the specialist string
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('specialization', isEqualTo: specialist)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Fallback to keyword search if exact match fails
        final allDocs = await _firestore.collection(_collectionName).get();
        return allDocs.docs
            .map((doc) => Doctor.fromMap(doc.data(), doc.id))
            .where((doc) => doc.specialization.toLowerCase().contains(specialist.toLowerCase()))
            .toList();
      }

      return querySnapshot.docs.map((doc) => Doctor.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      print('Error in doctor matching: $e');
      return [];
    }
  }
}
