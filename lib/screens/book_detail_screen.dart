import 'package:bookbridgev1/screens/messaging_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bookbridgev1/models/book_post.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:intl/intl.dart';
import 'package:bookbridgev1/screens/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookbridgev1/models/user_profile.dart';
import 'package:bookbridgev1/screens/purchase_screen.dart';
import '../service/chat_service.dart';

class BookDetailScreen extends StatefulWidget {
  final BookPost book;
  final ChatService chatService;

  const BookDetailScreen({
    super.key, 
    required this.book,
    required this.chatService,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isOpeningChat = false;
  bool _isAddingToWishlist = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // ✅ Only allow favorite checking if current user is the one viewing their own data
  if (user.uid != widget.book.sellerId) return;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.book.id)
        .get();

    if (mounted) {
      setState(() {
        _isFavorite = doc.exists;
      });
    }
  } catch (e) {
    print('Error checking favorite status: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(FeatherIcons.share2),
            onPressed: () => _shareBook(context),
            tooltip: 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80), // Space for bottom bar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookHeader(context),
            _buildActionButtons(context),
            const Divider(height: 32, thickness: 1),
            _buildBookMetadata(),
            _buildDescriptionSection(context),
            _buildSellerInfo(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(context),
    );
  }

  Widget _buildBookHeader(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: 'book-cover-${widget.book.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: widget.book.imageUrl,
              width: 120,
              height: 180,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.book, size: 40)),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.book, size: 40),
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
                widget.book.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'by ${widget.book.author}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.book.isForTrade
                      ? Colors.blue[50]
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.book.isForTrade
                        ? Colors.blue[100]!
                        : Colors.green[100]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.book.isForTrade
                      ? 'FOR TRADE'
                      : (widget.book.price != null &&
                              widget.book.price!.isNotEmpty
                          ? '₱${widget.book.price}'
                          : 'PRICE NOT SET'),
                  style: TextStyle(
                    color: widget.book.isForTrade
                        ? Colors.blue[800]
                        : Colors.green[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


  Widget _buildActionButtons(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: _isOpeningChat
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.message_outlined, size: 20),
            label: Text(
              _isOpeningChat ? 'Opening...' : 'Message Seller',
              style: const TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _isOpeningChat ? null : () => _contactSeller(context),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: _isAddingToWishlist
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : null,
                ),
          onPressed: _isAddingToWishlist ? null : _toggleWishlist,
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey[100],
            padding: const EdgeInsets.all(12),
            side: BorderSide(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
        ),
      ],
    ),
  );
}


  Widget _buildBookMetadata() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (widget.book.condition.isNotEmpty)
            _buildMetadataChip(
              icon: FeatherIcons.book,
              text: widget.book.condition,
            ),
          if (widget.book.categories.isNotEmpty)
            for (final category in widget.book.categories.take(2))
              _buildMetadataChip(
                icon: FeatherIcons.tag,
                text: category,
              ),
          if (widget.book.location.isNotEmpty)
            _buildMetadataChip(
              icon: FeatherIcons.mapPin,
              text: widget.book.location,
            ),
          _buildMetadataChip(
            icon: FeatherIcons.clock,
            text: _formatDate(widget.book.uploadTime),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip({required IconData icon, required String text}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.grey[700]),
      label: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
      ),
      backgroundColor: Colors.grey[50],
      side: BorderSide(color: Colors.grey[200]!),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              widget.book.description.isNotEmpty 
                  ? widget.book.description 
                  : 'No description provided',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seller Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[200],
                child: Icon(Icons.person, color: Colors.grey[600]),
              ),
              title: Text(
                widget.book.sellerName.isNotEmpty 
                    ? widget.book.sellerName 
                    : 'Unknown Seller',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                widget.book.memberSince != null 
                    ? 'Member since ${widget.book.memberSince!.year}'
                    : 'Member since unknown',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  'View Profile',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                onPressed: widget.book.sellerId.isNotEmpty 
                    ? () => _viewSellerProfile(context)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            widget.book.isForTrade ? 'Request Trade' : 'Buy Now',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => _initiatePurchase(context),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  void _shareBook(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing book...')),
    );
  }

  Future<void> _contactSeller(BuildContext context) async {
    setState(() => _isOpeningChat = true);
    
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to message the seller')),
          );
        }
        return;
      }

      if (currentUserId == widget.book.sellerId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You cannot message yourself')),
          );
        }
        return;
      }

      if (widget.book.sellerId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seller information not available')),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessagingScreen(
              otherUserId: widget.book.sellerId,
              currentUserId: currentUserId,
              productId: widget.book.id,
              chatService: widget.chatService,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error contacting seller: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  Future<void> _toggleWishlist() async {
    setState(() => _isAddingToWishlist = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to manage favorites')),
          );
        }
        return;
      }

      final userFavoritesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites');

      if (_isFavorite) {
        await userFavoritesRef.doc(widget.book.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from favorites')),
          );
        }
      } else {
        await userFavoritesRef.doc(widget.book.id).set({
          'id': widget.book.id,
          'title': widget.book.title,
          'author': widget.book.author,
          'imageUrl': widget.book.imageUrl,
          'isForTrade': widget.book.isForTrade,
          'price': widget.book.price,
          'uploadTime': widget.book.uploadTime.toIso8601String(),
          'location': widget.book.location,
          'condition': widget.book.condition,
          'categories': widget.book.categories,
          'sellerId': widget.book.sellerId,
          'sellerName': widget.book.sellerName,
          'memberSince': widget.book.memberSince?.toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to favorites')),
          );
        }
      }

      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorites: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToWishlist = false);
    }
  }

  Future<void> _viewSellerProfile(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.book.sellerId)
          .get();

      if (!doc.exists) throw Exception('Seller profile not found');

      final sellerProfile = UserProfile(
        uid: widget.book.sellerId,
        email: doc['email'] ?? '',
        displayName: doc['displayName'] ?? widget.book.sellerName,
        profilePictureId: doc['photoUrl'],
        phoneNumber: doc['phoneNumber'],
        location: doc['location'],
        bio: doc['bio'],
      );

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userProfile: sellerProfile),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _initiatePurchase(BuildContext context) {
    if (widget.book.isForTrade) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchaseScreen(book: widget.book),
        ),
      );
      return;
    }

    if (widget.book.price == null || widget.book.price!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid book price')),
      );
      return;
    }

    if (widget.book.sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller information missing')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseScreen(book: widget.book),
      ),
    );
  }
}