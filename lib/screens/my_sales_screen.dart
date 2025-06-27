import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MySalesScreen extends StatelessWidget {
  const MySalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("My Book Sales")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('sellerId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No sales yet."));
          }

          final sales = snapshot.data!.docs;

          return ListView.builder(
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index];
              final data = sale.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text("Status: ${data['status']}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Payment Method: ${data['paymentMethod']}"),
                      Text("Delivery Method: ${data['deliveryMethod']}"),
                      Text("Contact: ${data['contactNumber']}"),
                    ],
                  ),
                  trailing: data['status'] == 'pending_payment'
                      ? ElevatedButton(
                          onPressed: () async {
                            final transactionId = sale.id;
                            final buyerId = data['buyerId'];
                            final bookTitle = data['bookTitle'] ?? 'a book';
                            final bookId = data['bookId'];
                              await FirebaseFirestore.instance
                                  .collection('bookPosts')
                                  .doc(bookId)
                                  .update({'sold': true});

                            // 1. Update status
                            await FirebaseFirestore.instance
                                .collection('transactions')
                                .doc(transactionId)
                                .update({'status': 'accepted'});

                            // 2. Create a notification for the buyer
                            await FirebaseFirestore.instance.collection('notifications').add({
                              'userId': buyerId,
                              'title': 'Purchase Confirmed!',
                              'body': 'Your purchase for "$bookTitle" has been confirmed by the seller.',
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          },
                          child: const Text("Confirm"),
                        )
                      : const Icon(Icons.check, color: Colors.green),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
