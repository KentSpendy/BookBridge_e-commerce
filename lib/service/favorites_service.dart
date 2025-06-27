import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book_post.dart';

class FavoritesService {
  static Future<void> addToFavorites(BookPost book) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final favoritesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(book.id);

    await favoritesRef.set({
      'title': book.title,
      'author': book.author,
      'imageUrl': book.imageUrl,
      'price': book.price,
      'condition': book.condition,
      'sellerId': book.sellerId,
      'sellerName': book.sellerName,
      'location': book.location,
      'uploadTime': Timestamp.fromDate(book.uploadTime ?? DateTime.now()),
      'categories': book.categories,
      'isForTrade': book.isForTrade,
      'description': book.description,
      'memberSince': Timestamp.fromDate(book.memberSince ?? DateTime.now()),
      'gcashNumber': book.gcashNumber,
    });
  }
}
