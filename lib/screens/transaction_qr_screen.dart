import 'package:flutter/material.dart';
import '../models/transaction.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TransactionQrScreen extends StatelessWidget {
  final Transaction transaction;
  
  const TransactionQrScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction QR Code'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Code Display
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    QrImageView(
                      data: transaction.id, // Using transaction ID as QR data
                      version: QrVersions.auto,
                      size: 200,
                      gapless: true,
                      embeddedImage: const AssetImage('assets/images/app_logo_bookbridge.png'), // Optional
                      embeddedImageStyle: QrEmbeddedImageStyle(
                        size: const Size(40, 40),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Transaction #${transaction.id.substring(0, 8)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Transaction Details
            _buildDetailRow(
              context,
              icon: Icons.book,
              label: 'Book ID:',
              value: transaction.bookId.substring(0, 8),
            ),
            _buildDetailRow(
              context,
              icon: Icons.person,
              label: 'Seller ID:',
              value: transaction.sellerId.substring(0, 8),
            ),
            _buildDetailRow(
              context,
              icon: Icons.attach_money,
              label: 'Amount:',
              value: '₱${transaction.amount}',
            ),
            _buildDetailRow(
              context,
              icon: Icons.delivery_dining,
              label: 'Delivery:',
              value: transaction.deliveryMethod == 'pickup' 
                  ? 'Pickup' 
                  : 'Delivery',
            ),
            _buildDetailRow(
              context,
              icon: Icons.payment,
              label: 'Payment:',
              value: transaction.paymentMethod == 'gcash' 
                  ? 'GCash' 
                  : 'Cash',
            ),

            const SizedBox(height: 40),

            // Instructions
            const Text(
              'Show this QR code to the seller\nwhen you meet for pickup/delivery',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share QR'),
                    onPressed: () => _shareQrCode(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.done),
                    label: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _shareQrCode(BuildContext context) {
    // Implement your sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR code sharing functionality')),
    );  
  }
}