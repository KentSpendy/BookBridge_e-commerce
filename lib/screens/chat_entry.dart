import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/chat_service.dart';
import 'chat_list_screen.dart';

class ChatEntry extends StatelessWidget {
  const ChatEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('User not signed in')),
      );
    }

    final chatService = ChatService();

    return ChatListScreen(
      currentUserId: currentUserId,
      chatService: chatService,
    );
  }
}
