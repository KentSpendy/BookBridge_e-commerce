import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class Transaction {
  final String id;
  final String bookId;
  final String buyerId;
  final String sellerId;
  final String amount;
  final String status; // Consider using enum: TransactionStatus.pending
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String deliveryMethod; // Could also be enum
  final String paymentMethod;  // Could also be enum
  final String? deliveryAddress;
  final String? contactNumber;
  final String? gcashNumber;
  final String? paymentProofUrl;
  final bool paymentVerified;
  final String? referenceId;
  final DateTime? paymentVerifiedAt;

  Transaction({
    this.id = '',
    required this.bookId,
    required this.buyerId,
    required this.sellerId,
    required this.amount,
    this.status = 'pending_payment',
    DateTime? createdAt,
    this.updatedAt,
    required this.deliveryMethod,
    required this.paymentMethod,
    this.deliveryAddress,
    this.contactNumber,
    this.gcashNumber,
    this.paymentProofUrl,
    this.paymentVerified = false,
    this.referenceId,
    this.paymentVerifiedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Status constants
  static const String pendingPayment = 'pending_payment';
  static const String pendingVerification = 'pending_verification';
  static const String paid = 'paid';
  static const String cancelled = 'cancelled';
  static const String completed = 'completed';

  factory Transaction.fromFirestore(firestore.DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>? ?? {};

  return Transaction(
    id: doc.id,
    bookId: data['bookId']?.toString() ?? '',
    buyerId: data['buyerId']?.toString() ?? '',
    sellerId: data['sellerId']?.toString() ?? '',
    amount: data['amount']?.toString() ?? '0',
    status: data['status']?.toString() ?? 'pending_payment',
    createdAt: (data['createdAt'] as firestore.Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (data['updatedAt'] as firestore.Timestamp?)?.toDate(),
    deliveryMethod: data['deliveryMethod']?.toString() ?? 'pickup',
    paymentMethod: data['paymentMethod']?.toString() ?? 'cash',
    deliveryAddress: data['deliveryAddress']?.toString(),
    contactNumber: data['contactNumber']?.toString(),
    gcashNumber: data['gcashNumber']?.toString(),
    paymentProofUrl: data['paymentProofUrl']?.toString(),
    paymentVerified: data['paymentVerified'] ?? false,
    referenceId: data['referenceId']?.toString(),
    paymentVerifiedAt: (data['paymentVerifiedAt'] as firestore.Timestamp?)?.toDate(),
  );
}


  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'amount': amount,
      'status': status,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null 
          ? firestore.Timestamp.fromDate(updatedAt!) 
          : null,
      'deliveryMethod': deliveryMethod,
      'paymentMethod': paymentMethod,
      'deliveryAddress': deliveryAddress,
      'contactNumber': contactNumber,
      'gcashNumber': gcashNumber,
      'paymentProofUrl': paymentProofUrl,
      'paymentVerified': paymentVerified,
      'referenceId': referenceId,
      'paymentVerifiedAt': paymentVerifiedAt != null
          ? firestore.Timestamp.fromDate(paymentVerifiedAt!)
          : null,
    };
  }

  Transaction copyWith({
    String? id,
    String? bookId,
    String? buyerId,
    String? sellerId,
    String? amount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deliveryMethod,
    String? paymentMethod,
    String? deliveryAddress,
    String? contactNumber,
    String? gcashNumber,
    String? paymentProofUrl,
    bool? paymentVerified,
    String? referenceId,
    DateTime? paymentVerifiedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      contactNumber: contactNumber ?? this.contactNumber,
      gcashNumber: gcashNumber ?? this.gcashNumber,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      paymentVerified: paymentVerified ?? this.paymentVerified,
      referenceId: referenceId ?? this.referenceId,
      paymentVerifiedAt: paymentVerifiedAt ?? this.paymentVerifiedAt,
    );
  }
}