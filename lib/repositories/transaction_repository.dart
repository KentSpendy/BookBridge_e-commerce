import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:bookbridgev1/models/transaction.dart';

class TransactionRepository {
  final firestore.FirebaseFirestore _firestore;

  TransactionRepository({firestore.FirebaseFirestore? firestoreInstance})
      : _firestore = firestoreInstance ?? firestore.FirebaseFirestore.instance;

  Future<String> createTransaction(Transaction transaction) async {
    final docRef = await _firestore
        .collection('transactions')
        .add(transaction.toMap());
    return docRef.id;
  }

  Future<void> updateStatus(String transactionId, String newStatus) async {
    await _firestore
        .collection('transactions')
        .doc(transactionId)
        .update({'status': newStatus});
  }

  Future<void> updateTransaction(
      String transactionId, Map<String, dynamic> updates) async {
    await _firestore
        .collection('transactions')
        .doc(transactionId)
        .update(updates);
  }

  Stream<List<Transaction>> getUserTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('buyerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList());
  }
}
