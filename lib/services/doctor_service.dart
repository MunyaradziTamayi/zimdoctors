import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Add sample doctor (helper for testing)
  Future<void> addDoctor(Doctor doctor) async {
    await _firestore.collection(_collectionName).add(doctor.toMap());
  }
}
