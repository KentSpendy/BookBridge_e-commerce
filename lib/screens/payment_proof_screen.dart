import 'dart:io';
import 'package:bookbridgev1/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:bookbridgev1/repositories/transaction_repository.dart';

class PaymentProofScreen extends StatefulWidget {
  final String transactionId;
  final String sellerGcashNumber;
  final double amount;
  
  const PaymentProofScreen({
    required this.transactionId,
    required this.sellerGcashNumber,
    required this.amount,
    Key? key,
  }) : super(key: key);

  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  XFile? _imageFile;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  String _referenceNumber = '';

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() => _imageFile = image);
      }
    } catch (e) {
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _uploadPaymentProof() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      _showError('Please upload payment proof');
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Generate unique filename
      final fileName = 'payment_${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref()
        .child('payment_proofs/${widget.transactionId}/$fileName');
      
      await storageRef.putFile(File(_imageFile!.path));
      final downloadUrl = await storageRef.getDownloadURL();

      // Update transaction with payment proof and reference
      await Provider.of<TransactionRepository>(context, listen: false)
          .updateTransaction(
            widget.transactionId, 
            {
              'paymentProofUrl': downloadUrl,
              'referenceId': _referenceNumber,
              'status': Transaction.pendingVerification,
              'updatedAt': DateTime.now(),
            }
          );

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      _showError('Upload failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Payment Proof'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Instructions
              _buildPaymentInstructions(),

              const SizedBox(height: 24),

              // Reference Number Input
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Reference Number',
                  hintText: 'Enter GCash transaction reference',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter reference number';
                  }
                  return null;
                },
                onChanged: (value) => _referenceNumber = value.trim(),
              ),

              const SizedBox(height: 24),

              // Upload Section
              _buildUploadSection(),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  onPressed: _isUploading ? null : _uploadPaymentProof,
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Payment Proof',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentInstructions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              number: 1,
              title: 'Send Payment via GCash',
              content: 'Send ₱${widget.amount.toStringAsFixed(2)} to:',
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    widget.sellerGcashNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Name: [Seller Name]',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              number: 2,
              title: 'Enter Reference Number',
              content: 'Save the transaction reference from GCash',
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              number: 3,
              title: 'Upload Payment Proof',
              content: 'Take a screenshot of the transaction and upload below',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required int number,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            number.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Proof',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: _imageFile == null ? Colors.grey : Colors.green,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: _imageFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cloud_upload, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Tap to upload receipt',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_imageFile!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
          ),
        ),
        if (_imageFile != null) ...[
          const SizedBox(height: 8),
          Text(
            path.basename(_imageFile!.path),
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _pickImage,
            child: const Text('Change Image'),
          ),
        ],
      ],
    );
  }
}