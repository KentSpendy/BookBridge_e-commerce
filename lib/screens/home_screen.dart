import 'package:bookbridgev1/auth/auth%20service/auth_service.dart';
import 'package:bookbridgev1/models/book_post.dart';
import 'package:bookbridgev1/provider/favorite_provider.dart';
import 'package:bookbridgev1/repositories/book_repository.dart';
import 'package:bookbridgev1/repositories/user_repository.dart';
import 'package:bookbridgev1/screens/book_detail_screen.dart';
import 'package:bookbridgev1/screens/chat_entry.dart';
import 'package:bookbridgev1/screens/favorite_screen.dart';
import 'package:bookbridgev1/screens/my_sales_screen.dart';
import 'package:bookbridgev1/screens/notification_screen.dart';
import 'package:bookbridgev1/screens/profile_screen.dart';
import 'package:bookbridgev1/screens/upload_book_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bookbridgev1/auth/login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../service/chat_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Set<String> confirmedBookIds = {};
  final BookRepository _bookRepository = BookRepository();
  late Stream<List<BookPost>> _bookPostsStream;
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _updateBookPostsStream();
    _searchController.addListener(_updateBookPostsStream);
  }

  Future<void> _loadConfirmedBookIds() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('transactions')
        .where('status', isEqualTo: 'confirmed')
        .get();

    final bookIds = querySnapshot.docs
        .map((doc) => doc['bookId'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    setState(() {
      confirmedBookIds = bookIds;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateBookPostsStream() {
    setState(() {
      _bookPostsStream = _bookRepository.getBookPosts().map((books) {
        // First filter out sold books
        var filteredBooks = books.where((book) => !book.sold).toList();
        
        // Then apply category filter if selected
        filteredBooks = _selectedCategory != null
            ? filteredBooks.where((book) => 
                book.categories != null && 
                book.categories.contains(_selectedCategory))
                .toList()
            : filteredBooks;
        
        // Finally apply search filter
        if (_searchController.text.isNotEmpty) {
          filteredBooks = filteredBooks.where((book) =>
            (book.title?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false) ||
            (book.author?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false)
          ).toList();
        }
        
        return filteredBooks;
      });
    });
  }

  String _formatTimeDifference(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  Widget _buildHomeContent() {
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search books by title or author...',
            prefixIcon: const Icon(FeatherIcons.search, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ),
      
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _CategoryChip(
              label: 'All',
              isSelected: _selectedCategory == null,
              onSelected: (selected) => setState(() {
                _selectedCategory = null;
                _updateBookPostsStream();
              }),
            ),
            const SizedBox(width: 8),
            _CategoryChip(
              label: 'Fiction',
              isSelected: _selectedCategory == 'Fiction',
              onSelected: (selected) => setState(() {
                _selectedCategory = selected ? 'Fiction' : null;
                _updateBookPostsStream();
              }),
            ),
            const SizedBox(width: 8),
            _CategoryChip(
              label: 'Non-Fiction',
              isSelected: _selectedCategory == 'Non-Fiction',
              onSelected: (selected) => setState(() {
                _selectedCategory = selected ? 'Non-Fiction' : null;
                _updateBookPostsStream();
              }),
            ),
            const SizedBox(width: 8),
            _CategoryChip(
              label: 'Textbook',
              isSelected: _selectedCategory == 'Textbook',
              onSelected: (selected) => setState(() {
                _selectedCategory = selected ? 'Textbook' : null;
                _updateBookPostsStream();
              }),
            ),
            const SizedBox(width: 8),
            _CategoryChip(
              label: 'Fantasy',
              isSelected: _selectedCategory == 'Fantasy',
              onSelected: (selected) => setState(() {
                _selectedCategory = selected ? 'Fantasy' : null;
                _updateBookPostsStream();
              }),
            ),
            const SizedBox(width: 8),
            _CategoryChip(
              label: 'Mystery',
              isSelected: _selectedCategory == 'Mystery',
              onSelected: (selected) => setState(() {
                _selectedCategory = selected ? 'Mystery' : null;
                _updateBookPostsStream();
              }),
            ),
            const SizedBox(width: 8),
            _CategoryChip(
              label: 'Sci-Fi',
              isSelected: _selectedCategory == 'Sci-Fi',
              onSelected: (selected) => setState(() {
                _selectedCategory = selected ? 'Sci-Fi' : null;
                _updateBookPostsStream();
              }),
            ),
            const SizedBox(width: 8),
            _CategoryChip(
              label: 'Romance',
              isSelected: _selectedCategory == 'Romance',
              onSelected: (selected) => setState(() {
                _selectedCategory = selected ? 'Romance' : null;
                _updateBookPostsStream();
              }),
            ),
          ],
        ),
      ),
      
      Expanded(
        child: StreamBuilder<List<BookPost>>(
          stream: _bookPostsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, 
                        color: Theme.of(context).colorScheme.error, 
                        size: 48),
                    const SizedBox(height: 16),
                    Text('Error loading books',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );
            }

            final bookPosts = snapshot.data ?? [];
            if (bookPosts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FeatherIcons.book, 
                        size: 48, 
                        color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      _searchController.text.isEmpty
                        ? 'No books available yet!'
                        : 'No books found for "${_searchController.text}"',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchController.text.isEmpty
                        ? 'Be the first to upload a book'
                        : 'Try a different search term',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: bookPosts.length,
              itemBuilder: (context, index) {
                final post = bookPosts[index];
                return _BookPostCard(
                  post: post,
                  timeAgo: _formatTimeDifference(post.uploadTime),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

  Widget _buildBottomNavigation(User? user) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                FeatherIcons.home,
                size: 24,
                color: _currentIndex == 0 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  _currentIndex = 0;
                });
              },
            ),
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                size: 24,
                color: Colors.grey[600],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificationsScreen()),
                );
              },
            ),
            const SizedBox(width: 32), // Space for the center button
            IconButton(
              icon: Icon(
                FeatherIcons.heart,
                size: 24,
                color: Colors.grey[600],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(
                FeatherIcons.user,
                size: 24,
                color: _currentIndex == 2 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey[600],
              ),
              onPressed: () async {
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please log in to view profile')),
                  );
                  return;
                }

                try {
                  final userProfile = await UserRepository().getUserProfile(user.uid);
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userProfile: userProfile),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to load profile')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final User? user = authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('BookBridge', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          )),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(FeatherIcons.messageSquare, 
              color: Colors.grey[800]),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatEntry()),
              );
            },
          ),
          IconButton(
            icon: Icon(FeatherIcons.list, 
              color: Colors.grey[800]),
            tooltip: 'My Sales',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MySalesScreen()),
              );
            },
          ),
        ],
      ),
      body: _buildHomeContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (user != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UploadBookScreen()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please log in to upload a book')),
            );
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(FeatherIcons.plus, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigation(user),
    );
  }
}

class _BookPostCard extends StatelessWidget {
  final BookPost post;
  final String timeAgo;

  const _BookPostCard({
    required this.post,
    required this.timeAgo,
  });

  void _showPurchaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          post.isForTrade ? 'Initiate Trade' : 'Purchase Book',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          post.isForTrade
              ? 'Would you like to propose a trade for "${post.title}"?'
              : 'Would you like to buy "${post.title}" for ${post.price ?? 'N/A'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(post.isForTrade
                      ? 'Trade request sent for ${post.title}'
                      : 'Purchase initiated for ${post.title}'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            child: Text(
              post.isForTrade ? 'Propose Trade' : 'Confirm Purchase',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookDetailScreen(
                book: post,
                chatService: chatService,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      width: 90,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 90,
                        height: 120,
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(
                            FeatherIcons.book, 
                            size: 40, 
                            color: Colors.grey[400]),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 90,
                        height: 120,
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(
                            FeatherIcons.book, 
                            size: 40, 
                            color: Colors.grey[400]),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title ?? 'Untitled Book',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 4),
                        
                        Text(
                          post.author ?? 'Unknown Author',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (post.condition != null && post.condition!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.green[100]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  post.condition!,
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (post.categories != null && post.categories!.isNotEmpty)
                              ...post.categories!.map((category) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.blue[100]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )).toList(),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Icon(FeatherIcons.mapPin, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              post.location ?? 'Location not specified',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Text(
                    post.isForTrade 
                      ? 'For Trade' 
                      : post.price != null && post.price!.isNotEmpty
                        ? '₱${post.price}'
                        : 'Price not set',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _showPurchaseDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 1.5,
                        ),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    child: Text(
                      post.isForTrade ? 'Trade' : 'Buy Now',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.grey[100],
      selectedColor: Theme.of(context).primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}