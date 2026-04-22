import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'zimdoctors-1021d.firebasestorage.app',
  );
  final String _collectionName = 'users';

  // Create or update user profile
  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String email,
    required String photoUrl,
    String role = 'patient',
  }) async {
    await _firestore.collection(_collectionName).doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection(_collectionName).doc(uid).get();
    return doc.data();
  }

  // Upload user profile image
  Future<String> uploadUserProfileImage(File imageFile, String userId) async {
    if (!await imageFile.exists()) {
      throw Exception('Image file not found at ${imageFile.path}');
    }
    try {
      final Reference ref = _storage.ref().child('user_images/$userId.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final UploadTask uploadTask = ref.putFile(imageFile, metadata);
      final TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        return await snapshot.ref.getDownloadURL();
      } else {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }
    } catch (e) {
      print('Error uploading user image: $e');
      rethrow;
    }
  }

  // Register a new user
  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    // This would typically use Firebase Auth to create the user
    // For now, return a mock response
    return {
      'id': 'user_${DateTime.now().millisecondsSinceEpoch}',
      'verified': true,
    };
  }

  // Register a new doctor user
  Future<Map<String, dynamic>> registerDoctorUser({
    required String email,
    required String name,
    required String specialty,
    required String licenseNumber,
  }) async {
    // This would typically use Firebase Auth to create the user
    // For now, return a mock response
    return {
      'id': 'doctor_${DateTime.now().millisecondsSinceEpoch}',
      'verified': false,
      'status': 'pending_verification',
    };
  }

  // Add doctor to user favorites
  Future<void> addDoctorToFavorites({
    required String userId,
    required String doctorId,
  }) async {
    // This would add to user's favorites in Firestore
    // For now, do nothing
  }
}
