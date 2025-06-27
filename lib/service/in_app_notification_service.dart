import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class InAppNotificationService {
  final CollectionReference _notificationRef =
      FirebaseFirestore.instance.collection('notifications');

  /// Get a stream of all notifications for a user
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _notificationRef
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ))
            .toList());
  }

  /// Mark a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notificationRef.doc(notificationId).update({'isRead': true});
  }

  /// 🔔 Stream only the most recent notification for the current user
 Stream<NotificationModel> notificationStream(String userId) {
  return _notificationRef
      .where('userId', isEqualTo: userId)
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          return NotificationModel.fromMap(
            snapshot.docs.first.id,
            snapshot.docs.first.data() as Map<String, dynamic>,
          );
        } else {
          return NotificationModel.empty(); // ✅ Safe fallback
        }
      });
}


}
