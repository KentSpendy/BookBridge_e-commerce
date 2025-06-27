import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/book_post.dart';

class BookRepository extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  BookRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get all book posts sorted by upload time (newest first)
  Stream<List<BookPost>> getBookPosts() {
    try {
      return _firestore
          .collection('bookPosts')
          .orderBy('uploadTime', descending: true)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) {
              debugPrint('No books found in collection');
            }
            return snapshot.docs
                .map((doc) => BookPost.fromFirestore(doc))
                .toList();
          });
    } catch (e, stack) {
      debugPrint('Book loading failed: $e\n$stack');
      rethrow;
    }
  }

  // Get a single book post by ID
  Future<BookPost> getBookPost(String bookId) async {
    try {
      final doc = await _firestore.collection('bookPosts').doc(bookId).get();
      if (!doc.exists) {
        throw Exception('Book not found');
      }
      return BookPost.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting book post: $e');
      rethrow;
    }
  }

  // Add a new book post
  Future<String> addBookPost(BookPost post) async {
    try {
      final docRef = await _firestore
          .collection('bookPosts')
          .add(post.toFirestore());
      notifyListeners();
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding book post: $e');
      throw Exception('Failed to add book. Please try again.');
    }
  }

  // Update an existing book post
  Future<void> updateBookPost(BookPost post) async {
    try {
      await _firestore
          .collection('bookPosts')
          .doc(post.id)
          .update(post.toFirestore());
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating book post: $e');
      throw Exception('Failed to update book. Please try again.');
    }
  }

  // ✅ NEW: Mark a book as sold by setting the buyerId
  Future<void> markBookAsSold(String bookId, String buyerId) async {
    try {
      await _firestore.collection('bookPosts').doc(bookId).update({
        'buyerId': buyerId,
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking book as sold: $e');
      throw Exception('Failed to mark book as sold. Please try again.');
    }
  }

  // Delete a book post
  Future<void> deleteBookPost(String postId) async {
    try {
      await _firestore.collection('bookPosts').doc(postId).delete();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting book post: $e');
      throw Exception('Failed to delete book. Please try again.');
    }
  }

  // Get books by category
  Stream<List<BookPost>> getBookPostsByCategory(String category) {
    return _firestore
        .collection('bookPosts')
        .where('categories', arrayContains: category)
        .orderBy('uploadTime', descending: true)
        .snapshots()
        .handleError((error) {
          debugPrint('Error fetching books by category: $error');
          throw Exception('Failed to load books in this category.');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => BookPost.fromFirestore(doc))
            .toList());
  }

  // Get books by seller ID
  Stream<List<BookPost>> getBooksBySeller(String sellerId) {
  try {
    return _firestore
        .collection('bookPosts')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('uploadTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BookPost.fromFirestore(doc))
              .toList();
        });
  } catch (e, stack) {
    debugPrint('Book loading by seller failed: $e\n$stack');
    rethrow;
  }
}


  // Search books by title or author
  Stream<List<BookPost>> searchBooks(String query) {
    final searchQuery = query.toLowerCase();
    return _firestore
        .collection('bookPosts')
        .orderBy('title')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookPost.fromFirestore(doc))
            .where((book) =>
                book.title.toLowerCase().contains(searchQuery) ||
                book.author.toLowerCase().contains(searchQuery))
            .toList());
  }

  // Get books for trade
  Stream<List<BookPost>> getBooksForTrade() {
    return _firestore
        .collection('bookPosts')
        .where('isForTrade', isEqualTo: true)
        .orderBy('uploadTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookPost.fromFirestore(doc))
            .toList());
  }

  // Get books for sale
  Stream<List<BookPost>> getBooksForSale() {
    return _firestore
        .collection('bookPosts')
        .where('isForTrade', isEqualTo: false)
        .orderBy('uploadTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookPost.fromFirestore(doc))
            .toList());
  }
}
