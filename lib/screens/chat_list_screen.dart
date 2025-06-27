import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../service/chat_service.dart';
import 'messaging_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String currentUserId;
  final ChatService chatService;

  const ChatListScreen({
    required this.currentUserId,
    required this.chatService,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final Map<String, String> _userCache = {};
  final Map<String, String> _userImageCache = {};

  Future<String> _getUserName(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId]!;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final name = doc.get('displayName') ?? doc.get('name') ?? 'User';
      _userCache[userId] = name;
      return name;
    } catch (e) {
      return 'User';
    }
  }

  Future<String?> _getUserImage(String userId) async {
    if (_userImageCache.containsKey(userId)) return _userImageCache[userId];
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final imageUrl = doc.get('photoUrl');
      if (imageUrl != null) _userImageCache[userId] = imageUrl;
      return imageUrl;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.chatService.getUserChatsStream(widget.currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading chats',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${snapshot.error}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No chats yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation by messaging a seller',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              return _ChatListItem(
                chatData: chat,
                currentUserId: widget.currentUserId,
                chatService: widget.chatService,
                getUserName: _getUserName,
                getUserImage: _getUserImage,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final Map<String, dynamic> chatData;
  final String currentUserId;
  final ChatService chatService;
  final Future<String> Function(String) getUserName;
  final Future<String?> Function(String) getUserImage;

  const _ChatListItem({
    required this.chatData,
    required this.currentUserId,
    required this.chatService,
    required this.getUserName,
    required this.getUserImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
    final timeString = lastMessageTime != null
        ? DateFormat(lastMessageTime.toDate().year == DateTime.now().year
            ? 'MMM d'
            : 'MMM d, y')
            .format(lastMessageTime.toDate())
        : '';
        
    final unreadCount = chatData['unreadCount'] as int? ?? 0;
    final otherUserId = chatData['otherUserId'] as String? ?? '';
    final lastMessage = chatData['lastMessage']?.toString() ?? 'No messages yet';
    final isUnread = unreadCount > 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessagingScreen(
              otherUserId: otherUserId,
              currentUserId: currentUserId,
              productId: chatData['productId']?.toString(),
              chatService: chatService,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            FutureBuilder<String?>(
              future: getUserImage(otherUserId),
              builder: (context, snapshot) {
                final imageUrl = snapshot.data;
                return CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  backgroundImage: imageUrl != null
                      ? CachedNetworkImageProvider(imageUrl)
                      : null,
                  child: imageUrl == null
                      ? const Icon(Icons.person, size: 24)
                      : null,
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<String>(
                          future: getUserName(otherUserId),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.data ?? 'User',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: isUnread 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      Text(
                        timeString,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isUnread
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: isUnread 
                                ? FontWeight.w500 
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}