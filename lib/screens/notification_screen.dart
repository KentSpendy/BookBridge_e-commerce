import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../service/in_app_notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  final InAppNotificationService _notificationService = InAppNotificationService();

  NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('Please log in to view notifications.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getUserNotifications(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];

              return ListTile(
                title: Text(notif.title),
                subtitle: Text(notif.body),
                trailing: notif.isRead
                    ? null
                    : const Icon(Icons.mark_email_unread, color: Colors.blue),
                onTap: () async {
                  if (!notif.isRead) {
                    await _notificationService.markAsRead(notif.id!);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
