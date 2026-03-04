import 'package:cloud_firestore/cloud_firestore.dart';

class SystemNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final String status; // 'active', 'history'

  SystemNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.status = 'active',
  });

  factory SystemNotification.fromMap(Map<String, dynamic> map, String id) {
    return SystemNotification(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      status: map['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'status': status,
    };
  }
}
