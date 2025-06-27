import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookbridgev1/models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendNotification(NotificationModel notification) async {
    await _firestore
        .collection('notifications')
        .add(notification.toMap());
  }

  // Optional: Fetch notifications for a user (for a notification screen)
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return NotificationModel.fromMap(doc.id, doc.data());
            }).toList());
  }
}
