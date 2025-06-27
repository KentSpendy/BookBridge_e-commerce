// Cleaned messaging_screen.dart without gallery save feature

import 'dart:convert';
import 'dart:io';

import 'package:bookbridgev1/screens/full_image_viewer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../service/chat_service.dart';
import '../service/notification_service.dart';

class MessagingScreen extends StatefulWidget {
  final String otherUserId;
  final String currentUserId;
  final String? productId;
  final ChatService chatService;

  const MessagingScreen({
    required this.otherUserId,
    required this.currentUserId,
    this.productId,
    required this.chatService,
    Key? key,
  }) : super(key: key);

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _chatId;
  Stream<QuerySnapshot>? _messagesStream;
  bool _isInitializing = true;
  String? _errorMessage;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _setupFCMListeners();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    final imageUrl = await _uploadImageToCloudinary(imageFile);

    if (imageUrl != null && _chatId != null) {
      await widget.chatService.sendMessage(
        chatId: _chatId!,
        senderId: widget.currentUserId,
        text: '',
        productId: widget.productId,
        imageUrl: imageUrl,
      );
      _scrollToBottom();
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    const cloudName = 'doijokxxj';
    const uploadPreset = 'bookbridge_present';

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$cloudName/image/upload',
      {'upload_preset': uploadPreset},
    );

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    final jsonResponse = jsonDecode(await response.stream.bytesToString());

    return jsonResponse['secure_url'] as String?;
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['chatId'] == _chatId) {
        _initializeChat();
      }
      NotificationService.showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['chatId'] == _chatId) {
        _initializeChat();
      }
    });
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        if (widget.currentUserId.isEmpty || widget.otherUserId.isEmpty) {
          throw Exception('Invalid user IDs');
        }

        final chatId = await widget.chatService.getOrCreateChat(
          currentUserId: widget.currentUserId,
          otherUserId: widget.otherUserId,
          productId: widget.productId,
        );

        if (!mounted) return;

        setState(() {
          _chatId = chatId;
          _messagesStream = widget.chatService.getMessagesStream(_chatId!);
        });

        if (_chatId != null) {
          await widget.chatService.markMessagesAsRead(
            widget.currentUserId,
            _chatId!,
          );
          _scrollToBottom();

          try {
            await _fcm.subscribeToTopic('chat_$_chatId');
          } catch (e) {
            debugPrint('Failed to subscribe to FCM topic: $e');
          }
        }

        break;
      } catch (e) {
        debugPrint('Chat initialization error: $e');

        if (e is FirebaseException && e.code == 'unavailable') {
          retries++;
          await Future.delayed(Duration(seconds: 2 * retries));
          continue;
        }

        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to initialize chat. Please try again.';
          if (e is FirebaseException && e.code == 'permission-denied') {
            _errorMessage = 'Permission denied. Please check your authentication.';
          }
        });
        break;
      }
    }

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _chatId == null) return;

    try {
      await widget.chatService.sendMessage(
        chatId: _chatId!,
        senderId: widget.currentUserId,
        text: _messageController.text.trim(),
        productId: widget.productId,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    if (_chatId != null) {
      _fcm.unsubscribeFromTopic('chat_$_chatId');
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_chatId != null) _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isInitializing) return _buildLoading();
    if (_errorMessage != null) return _buildError();
    if (_messagesStream == null) return _buildEmpty();

    return StreamBuilder<QuerySnapshot>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        final messages = snapshot.data?.docs ?? [];
        if (messages.isEmpty) return _buildEmpty();

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: messages.length,
          itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
        );
      },
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot message) {
    final data = message.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == widget.currentUserId;

    final deletedFor = List<String>.from(data['deletedFor'] ?? []);
    final isDeletedForCurrentUser = deletedFor.contains(widget.currentUserId);

    if (isDeletedForCurrentUser) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isMe ? 'You unsent this message.' : 'This message was deleted.',
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.black54,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showDeleteOptions(
        context: context,
        chatId: _chatId ?? '',
        messageId: message.id,
        senderId: data['senderId'],
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data['imageUrl'] != null)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FullImageViewer(imageUrl: data['imageUrl']),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      data['imageUrl'],
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (data['text'] != null && data['imageUrl'] == null)
                Text(
                  data['text'] ?? '',
                  style: TextStyle(color: isMe ? Colors.white : Colors.black),
                ),
              const SizedBox(height: 4),
              Text(
                DateFormat('h:mm a').format(
                  (data['timestamp'] != null
                      ? (data['timestamp'] as Timestamp).toDate()
                      : DateTime.now()),
                ),
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.black54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: _pickAndSendImage,
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator());

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage ?? 'Error loading chat'),
            ElevatedButton(
              onPressed: _initializeChat,
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => const Center(
        child: Text('No messages yet. Start the conversation!'),
      );

  void _showDeleteOptions({
    required BuildContext context,
    required String chatId,
    required String messageId,
    required String senderId,
  }) {
    final currentUserId = widget.currentUserId;
    final isSender = currentUserId == senderId;

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for Me'),
                onTap: () async {
                  Navigator.pop(context);
                  await widget.chatService.deleteMessageForMe(
                    chatId: chatId,
                    messageId: messageId,
                    userId: currentUserId,
                  );
                },
              ),
              if (isSender)
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text('Delete for Everyone'),
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.chatService.deleteMessageForEveryone(
                      chatId: chatId,
                      messageId: messageId,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
