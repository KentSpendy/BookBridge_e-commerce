import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/foundation.dart';

class BookPost {
  final String id;
  final String title;
  final String author;
  final String price;
  final String condition;
  final String sellerId;
  final String sellerName;
  final String imageUrl;
  final String location;
  final DateTime uploadTime;
  final List<String> categories;
  final bool isForTrade;
  final String description;
  final DateTime memberSince;
  final String? gcashNumber;
  final String? buyerId;
  final bool sold; // NEW: Added sold field

  // Main constructor with default values
  BookPost({
    String? id,
    required String title,
    required String author,
    required String price,
    String? condition,
    required String sellerId,
    String? sellerName,
    required String imageUrl,
    String? location,
    DateTime? uploadTime,
    List<String>? categories,
    required bool isForTrade,
    String? description,
    DateTime? memberSince,
    this.gcashNumber,
    this.buyerId,
    this.sold = false, // NEW: Default to false
  })  : id = id ?? '',
        title = title.isNotEmpty ? title : 'Untitled Book',
        author = author.isNotEmpty ? author : 'Unknown Author',
        price = _validatePrice(price, isForTrade),
        condition = condition?.isNotEmpty ?? false ? condition! : 'Good',
        sellerId = sellerId,
        sellerName = sellerName?.isNotEmpty ?? false ? sellerName! : 'Anonymous',
        imageUrl = imageUrl,
        location = location?.isNotEmpty ?? false ? location! : 'Unknown Location',
        uploadTime = uploadTime ?? DateTime.now(),
        categories = categories ?? [],
        isForTrade = isForTrade,
        description = description?.isNotEmpty ?? false ? description! : 'No description available',
        memberSince = memberSince ?? DateTime.now();

  // Helper method for price validation
  static String _validatePrice(String price, bool isForTrade) {
    if (isForTrade) return 'For Trade';
    if (price.isEmpty) return '0';
    return double.tryParse(price)?.toString() ?? '0';
  }

  // fromFirestore factory
  factory BookPost.fromFirestore(firestore.DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};

      return BookPost(
        id: doc.id,
        title: data['title']?.toString() ?? '',
        author: data['author']?.toString() ?? '',
        price: data['price']?.toString() ?? '0',
        condition: data['condition']?.toString(),
        sellerId: data['sellerId']?.toString() ?? '',
        sellerName: data['sellerName']?.toString(),
        imageUrl: data['imageUrl']?.toString() ?? '',
        location: data['location']?.toString(),
        uploadTime: (data['uploadTime'] as firestore.Timestamp?)?.toDate(),
        categories: (data['categories'] as List<dynamic>?)?.cast<String>() ?? [],
        isForTrade: data['isForTrade'] as bool? ?? false,
        description: data['description']?.toString(),
        memberSince: (data['memberSince'] as firestore.Timestamp?)?.toDate(),
        gcashNumber: data['gcashNumber']?.toString(),
        buyerId: data['buyerId']?.toString(),
        sold: data['sold'] as bool? ?? false, // NEW: Added sold field
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing BookPost ${doc.id}: $e');
      debugPrint(stackTrace.toString());

      return BookPost(
        title: 'Invalid Book',
        author: 'System',
        price: '0',
        sellerId: 'error',
        imageUrl: '',
        isForTrade: false,
        description: 'This book failed to load properly',
      );
    }
  }

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'author': author,
      'price': price,
      'condition': condition,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'imageUrl': imageUrl,
      'location': location,
      'uploadTime': firestore.Timestamp.fromDate(uploadTime),
      'categories': categories,
      'isForTrade': isForTrade,
      'description': description,
      'memberSince': firestore.Timestamp.fromDate(memberSince),
      if (gcashNumber != null) 'gcashNumber': gcashNumber,
      if (buyerId != null) 'buyerId': buyerId,
      'sold': sold, // NEW: Added sold field
    };
  }

  Map<String, dynamic> toJson() => toFirestore();

  bool get isValid =>
      title.isNotEmpty &&
      author.isNotEmpty &&
      sellerId.isNotEmpty &&
      imageUrl.isNotEmpty;

  double get numericPrice => isForTrade ? 0 : double.tryParse(price) ?? 0;

  BookPost copyWith({
    String? id,
    String? title,
    String? author,
    String? price,
    String? condition,
    String? sellerId,
    String? sellerName,
    String? imageUrl,
    String? location,
    DateTime? uploadTime,
    List<String>? categories,
    bool? isForTrade,
    String? description,
    DateTime? memberSince,
    String? gcashNumber,
    String? buyerId,
    bool? sold, // NEW: Added sold field
  }) {
    return BookPost(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      price: price ?? this.price,
      condition: condition ?? this.condition,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      uploadTime: uploadTime ?? this.uploadTime,
      categories: categories ?? this.categories,
      isForTrade: isForTrade ?? this.isForTrade,
      description: description ?? this.description,
      memberSince: memberSince ?? this.memberSince,
      gcashNumber: gcashNumber ?? this.gcashNumber,
      buyerId: buyerId ?? this.buyerId,
      sold: sold ?? this.sold, // NEW: Added sold field
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookPost &&
        other.id == id &&
        other.title == title &&
        other.author == author &&
        other.price == price &&
        other.sellerId == sellerId &&
        other.sold == sold; // NEW: Added sold field to equality check
  }

  @override
  int get hashCode => Object.hash(id, title, author, price, sellerId, sold); // NEW: Added sold field to hash

  @override
  String toString() {
    return 'BookPost(id: $id, title: "$title", price: $price, seller: "$sellerName", sold: $sold)'; // NEW: Added sold to toString
  }
}