import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:zimdoctors/models/doctor.dart';

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
}
