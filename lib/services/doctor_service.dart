import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/models/booking.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'doctors';

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

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload profile image to Firebase Storage
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      final Reference ref = _storage.ref().child('doctor_images/$userId.jpg');
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }

  // Create a new doctor in Firestore
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

  // Add sample doctor (helper for testing)
  Future<void> addDoctor(Doctor doctor) async {
    await _firestore.collection(_collectionName).add(doctor.toMap());
  }

  // Update doctor profile
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

  // Bookings
  Future<void> createBooking(Booking booking) async {
    try {
      await _firestore.collection('bookings').add(booking.toMap());
    } catch (e) {
      print('Error creating booking: $e');
      throw e;
    }
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
          // Sort manually to avoid index requirement
          bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return bookings;
        });
  }

  // Get current doctor info if logged in
  Future<Doctor?> getCurrentDoctor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return getDoctorById(user.uid);
    }
    return null;
  }

  // Check if a slot is already booked
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
}
