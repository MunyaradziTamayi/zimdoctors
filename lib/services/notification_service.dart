import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zimdoctors/models/notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send a notification
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    final notification = SystemNotification(
      id: '',
      userId: userId,
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
    );

    await _firestore.collection('notifications').add(notification.toMap());
  }

  // Get active notifications for a user
  Stream<List<SystemNotification>> getActiveNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SystemNotification.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  // Get notification history for a user
  Stream<List<SystemNotification>> getNotificationHistory(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'history')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SystemNotification.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  // Move a notification to history
  Future<void> moveToHistory(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'status': 'history', 'isRead': true});
  }

  // Mark all as read
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
