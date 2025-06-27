import 'package:bookbridgev1/models/notification_model.dart';
import 'package:bookbridgev1/repositories/notification_repository.dart';
import 'package:bookbridgev1/repositories/transaction_repository.dart';
import 'package:bookbridgev1/screens/payment_proof_screen.dart';
import 'package:bookbridgev1/screens/transaction_qr_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bookbridgev1/models/book_post.dart';
import 'package:bookbridgev1/models/transaction.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For currency formatting

class PurchaseScreen extends StatefulWidget {
  final BookPost book;
  
  const PurchaseScreen({super.key, required this.book});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  String _deliveryMethod = 'pickup';
  String _paymentMethod = 'cash';
  bool _isProcessing = false;
  bool _termsAccepted = false;
  TextEditingController _deliveryAddressController = TextEditingController();
  TextEditingController _contactNumberController = TextEditingController();
  TextEditingController _gcashNumberController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    _contactNumberController.dispose();
    _gcashNumberController.dispose();
    super.dispose();
  }

  Future<void> _confirmPurchase() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and conditions')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');
      if (userId == widget.book.sellerId) {
        throw Exception('You cannot purchase your own book');
      }

      // Validate price format
      if (double.tryParse(widget.book.price) == null) {
        throw Exception('Invalid book price format');
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Purchase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to complete this purchase?'),
              if (_paymentMethod == 'gcash') ...[
                const SizedBox(height: 16),
                Text(
                  'You will need to upload payment proof after confirmation',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isProcessing = false);
        return;
      }

      // Create transaction with proper status
      final initialStatus = _paymentMethod == 'gcash' 
          ? Transaction.pendingVerification 
          : Transaction.pendingPayment;
      
      final transaction = Transaction(
        bookId: widget.book.id,
        buyerId: userId,
        sellerId: widget.book.sellerId,
        amount: widget.book.price,
        deliveryMethod: _deliveryMethod,
        paymentMethod: _paymentMethod,
        deliveryAddress: _deliveryMethod == 'delivery' 
            ? _deliveryAddressController.text 
            : null,
        contactNumber: _contactNumberController.text,
        gcashNumber: _paymentMethod == 'gcash' 
            ? _gcashNumberController.text 
            : null,
        status: initialStatus,
        createdAt: DateTime.now(),
      );

      // Create transaction and get ID
      final transactionId = await Provider.of<TransactionRepository>(
        context, 
        listen: false,
      ).createTransaction(transaction);

      // Update book with buyer ID notification
      final notification = NotificationModel(
        userId: widget.book.sellerId,
        title: 'Your book was purchased!',
        body: '${widget.book.title} has been bought. Please prepare for delivery or meetup.',
        timestamp: DateTime.now(),
      );

      await Provider.of<NotificationRepository>(
        context,
        listen: false,
      ).sendNotification(notification);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase successful!'),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate based on payment method
        if (_paymentMethod == 'gcash') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentProofScreen(
                transactionId: transactionId,
                sellerGcashNumber: widget.book.gcashNumber ?? 'Not provided',
                amount: double.parse(widget.book.price),
              ),
            ),
          );
        } else {
          // For cash payments, show QR code (if you implement this)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionQrScreen(
                transaction: transaction.copyWith(id: transactionId),
              ),
            ),
          );
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildBookSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.book.imageUrl,
                width: 80,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 120,
                  color: Colors.grey[200],
                  child: const Icon(Icons.book, size: 40, color: Colors.grey),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'by ${widget.book.author}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currencyFormat.format(double.parse(widget.book.price)),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            'DELIVERY METHOD',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                RadioListTile(
                  title: const Text('Meetup/Pickup'),
                  subtitle: const Text('Arrange meetup location with seller'),
                  value: 'pickup',
                  groupValue: _deliveryMethod,
                  onChanged: (value) => setState(() => _deliveryMethod = value!),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile(
                  title: const Text('Delivery'),
                  subtitle: const Text('Buyer pays shipping fee'),
                  value: 'delivery',
                  groupValue: _deliveryMethod,
                  onChanged: (value) => setState(() => _deliveryMethod = value!),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_deliveryMethod == 'delivery') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _deliveryAddressController,
            decoration: InputDecoration(
              labelText: 'Delivery Address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (_deliveryMethod == 'delivery' && (value == null || value.isEmpty)) {
                return 'Please enter delivery address';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactNumberController,
          decoration: InputDecoration(
            labelText: 'Contact Number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            prefixIcon: const Icon(Icons.phone, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your contact number';
            }
            if (value.length < 10) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            'PAYMENT METHOD',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                RadioListTile(
                  title: const Text('Cash on Delivery/Pickup'),
                  subtitle: const Text('Pay in cash when you receive the book'),
                  value: 'cash',
                  groupValue: _paymentMethod,
                  onChanged: (value) => setState(() => _paymentMethod = value!),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile(
                  title: const Text('GCash'),
                  subtitle: const Text('Pay via GCash mobile payment'),
                  value: 'gcash',
                  groupValue: _paymentMethod,
                  onChanged: (value) => setState(() => _paymentMethod = value!),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_paymentMethod == 'gcash') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _gcashNumberController,
            decoration: InputDecoration(
              labelText: 'GCash Number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (_paymentMethod == 'gcash' && (value == null || value.isEmpty)) {
                return 'Please enter your GCash number';
              }
              if (_paymentMethod == 'gcash' && (value?.length ?? 0) < 10) {
                return 'Please enter a valid GCash number';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTermsAndConditions() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: _termsAccepted,
                onChanged: (value) => setState(() => _termsAccepted = value ?? false),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Terms and Conditions'),
                    content: SingleChildScrollView(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'By completing this purchase, you agree to:\n\n',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(
                              text: '1. Arranging meetup/delivery details with the seller\n',
                            ),
                            const TextSpan(
                              text: '2. Paying the agreed amount for the book\n',
                            ),
                            const TextSpan(
                              text: '3. Following up with the seller for transaction completion\n\n',
                            ),
                            TextSpan(
                              text: 'BookBridge acts only as a platform and is not responsible for transactions between users.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                child: RichText(
                  text: const TextSpan(
                    text: 'I agree to the ',
                    style: TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: 'terms and conditions',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Purchase'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Book Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildBookSummary(),
              const SizedBox(height: 24),
              _buildDeliverySection(),
              const SizedBox(height: 24),
              _buildPaymentSection(),
              const SizedBox(height: 24),
              _buildTermsAndConditions(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmPurchase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'CONFIRM PURCHASE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}