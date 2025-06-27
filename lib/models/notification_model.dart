import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String? id;
  final String userId;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  /// ✅ Empty notification model
  factory NotificationModel.empty() {
    return NotificationModel(
      id: '',
      userId: '', // ✅ add this to fix the error
      title: 'No Notifications',
      body: '',
      timestamp: DateTime.now(),
      isRead: true,
    );
  }

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
  DateTime parsedTimestamp;

  final rawTimestamp = map['timestamp'];

  if (rawTimestamp is Timestamp) {
    parsedTimestamp = rawTimestamp.toDate();
  } else if (rawTimestamp is String) {
    parsedTimestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
  } else {
    parsedTimestamp = DateTime.now();
  }

  return NotificationModel(
    id: id,
    userId: map['userId'] ?? '',
    title: map['title'] ?? '',
    body: map['body'] ?? '',
    timestamp: parsedTimestamp,
    isRead: map['isRead'] ?? false,
  );
}

}
