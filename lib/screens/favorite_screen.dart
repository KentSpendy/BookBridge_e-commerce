import 'package:bookbridgev1/service/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_post.dart';
import 'book_detail_screen.dart'; // import your detail screen

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<BookPost?> _fetchBookById(String bookId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('bookPosts').doc(bookId).get();
      if (doc.exists) {
        return BookPost.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error fetching book with ID $bookId: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view favorites')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Favorites')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No favorite books yet.'));
          }

          final favoriteDocs = snapshot.data!.docs;
          final bookIds = favoriteDocs.map((doc) => doc.id).toList();

          return FutureBuilder<List<BookPost?>>(
            future: Future.wait(bookIds.map(_fetchBookById)),
            builder: (context, booksSnapshot) {
              if (booksSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final books = booksSnapshot.data!.whereType<BookPost>().toList();

              if (books.isEmpty) {
                return const Center(child: Text('No valid books found.'));
              }

              return ListView.builder(
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(book: book, chatService: ChatService()),
                        ),
                      );
                    },
                    leading: book.imageUrl.isNotEmpty
                        ? Image.network(book.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.book, size: 50),
                    title: Text(book.title),
                    subtitle: Text(book.author),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
