import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Get or create a chat between two users
  Future<String?> getOrCreateChat({
  required String currentUserId,
  required String otherUserId,
  String? productId,
}) async {
  try {
    // Validate inputs
    if (currentUserId.isEmpty || otherUserId.isEmpty) {
      throw Exception('Invalid user IDs');
    }

    // Check if both users exist
    final users = await Future.wait([
      _firestore.collection('users').doc(currentUserId).get(),
      _firestore.collection('users').doc(otherUserId).get(),
    ]);

    if (!users[0].exists || !users[1].exists) {
      throw Exception('One or both users do not exist');
    }

    final participants = [currentUserId, otherUserId]..sort();
    final chatId = productId != null
        ? '${productId}_${participants.join('_')}'
        : participants.join('_');

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      final batch = _firestore.batch();
      
      // Create chat document
      batch.set(_firestore.collection('chats').doc(chatId), {
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {
          currentUserId: 0,
          otherUserId: 0,
        },
        if (productId != null) 'productId': productId,
      });

      // Create user chat entries
      await Future.wait([
        _createUserChatEntry(
          userId: currentUserId,
          otherUserId: otherUserId,
          chatId: chatId,
          productId: productId,
        ),
        _createUserChatEntry(
          userId: otherUserId,
          otherUserId: currentUserId,
          chatId: chatId,
          productId: productId,
        ),
      ]);

      await batch.commit();
    }

    return chatId;
  } catch (e) {
    debugPrint('Failed to create chat: $e');
    throw Exception('Failed to create chat: ${e.toString()}');
  }
}

  Future<void> _createUserChatEntry({
    required String userId,
    required String otherUserId,
    required String chatId,
    String? productId,
  }) async {
    await _firestore
        .collection('userChats')
        .doc(userId)
        .collection('chats')
        .doc(chatId)
        .set({
      'chatId': chatId,
      'otherUserId': otherUserId,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': 0,
      if (productId != null) 'productId': productId,
    });
  }

  // Send a message with FCM notification
  Future<void> sendMessage({
  required String chatId,
  required String senderId,
  required String text,
  String? productId,
  String? imageUrl, // ← Add this
}) async {

    try {
      // Validate inputs
      if (chatId.isEmpty || senderId.isEmpty || (text.isEmpty && (imageUrl == null || imageUrl.isEmpty))) {
  throw Exception('Invalid message parameters');
}
      if (text.length > 1000) {
        throw Exception('Message text exceeds maximum length');
      }

      final timestamp = FieldValue.serverTimestamp();
      final batch = _firestore.batch();

      // Create new message
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'text': text,
        'senderId': senderId,
        'timestamp': timestamp,
        'productId': productId ?? '',
        'status': 'sent',
        'readBy': [senderId],
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      });

      // Update chat document
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'lastMessage': text,
        'lastMessageTime': timestamp,
        'unreadCount.$senderId': 0,
        'unreadCount.${await _getOtherUserId(chatRef, senderId)}': FieldValue.increment(1),
      });

      // Update user chats for both participants
      final participants = await _getChatParticipants(chatId);
      for (final userId in participants) {
        final userChatRef = _firestore
            .collection('userChats')
            .doc(userId)
            .collection('chats')
            .doc(chatId);

        batch.set(userChatRef, {
          'lastMessage': text,
          'lastMessageTime': timestamp,
          'unreadCount': userId == senderId ? 0 : FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      // Send push notification
      await _sendPushNotification(
        chatId: chatId,
        senderId: senderId,
        text: text,
        participants: participants,
      );
    } catch (e) {
      debugPrint('Failed to send message: $e');
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  Future<void> _sendPushNotification({
    required String chatId,
    required String senderId,
    required String text,
    required List<String> participants,
  }) async {
    try {
      final otherUserId = participants.firstWhere((id) => id != senderId);
      final tokens = await _getUserFCMTokens(otherUserId);

      if (tokens.isEmpty) return;

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=${await _getServerKey()}',
        },
        body: jsonEncode({
          'notification': {
            'title': 'New message',
            'body': text.length > 30 ? '${text.substring(0, 30)}...' : text,
            'sound': 'default',
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'chatId': chatId,
            'senderId': senderId,
            'type': 'message',
          },
          'registration_ids': tokens,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('FCM error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  Future<List<String>> _getUserFCMTokens(String userId) async {
    final snapshot = await _firestore
        .collection('fcm_tokens')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) => doc['token'] as String).toList();
  }

  Future<String> _getServerKey() async {
    final doc = await _firestore.collection('config').doc('fcm').get();
    return doc['serverKey'] as String;
  }

  Future<List<String>> _getChatParticipants(String chatId) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    return List<String>.from(chatDoc['participants'] ?? []);
  }

  Future<String> _getOtherUserId(DocumentReference chatRef, String currentUserId) async {
    try {
      final chatDoc = await chatRef.get();
      final participants = List<String>.from(chatDoc['participants'] ?? []);
      return participants.firstWhere((id) => id != currentUserId);
    } catch (e) {
      throw Exception('Could not find other participant');
    }
  }

  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Stream<QuerySnapshot> getUserChatsStream(String userId) {
    return _firestore
        .collection('userChats')
        .doc(userId)
        .collection('chats')
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Future<void> markMessagesAsRead(String userId, String chatId) async {
    try {
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      final batch = _firestore.batch();
      for (final message in messages.docs) {
        batch.update(message.reference, {
          'status': 'read',
          'readBy': FieldValue.arrayUnion([userId]),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
      throw Exception('Failed to mark messages as read: ${e.toString()}');
    }
  }


  //Delete messages
  Future<void> deleteMessageForMe({
  required String chatId,
  required String messageId,
  required String userId,
}) async {
  final ref = _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc(messageId);
      

  await ref.update({
    'deletedFor': FieldValue.arrayUnion([userId]),
  });
}

Future<void> deleteMessageForEveryone({
  required String chatId,
  required String messageId,
}) async {
  final ref = _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc(messageId);

  await ref.delete();
}

}