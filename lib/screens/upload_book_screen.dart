import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bookbridgev1/models/book_post.dart';
import 'package:bookbridgev1/repositories/book_repository.dart';
import 'package:provider/provider.dart';
import 'package:bookbridgev1/auth/auth%20service/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key});

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _priceController = TextEditingController();
  final _conditionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _gcashController = TextEditingController();

  // Cloudinary configuration
  static const _cloudName = 'doijokxxj';
  static const _uploadPreset = 'bookbridge_present';

  String? _selectedCategory;
  bool _isForTrade = false;
  File? _imageFile;
  Uint8List? _webImage;
  bool _isUploading = false;
  String? _uploadError;
  double? _uploadProgress;

  final List<String> _categories = [
    'Fiction', 'Non-Fiction', 'Textbook',
    'Fantasy', 'Mystery', 'Sci-Fi', 'Romance'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _priceController.dispose();
    _conditionController.dispose();
    _descriptionController.dispose();
    _gcashController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        if (kIsWeb) {
          // For web platform
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImage = bytes;
            _uploadError = null;
          });
        } else {
          // For mobile platform
          setState(() {
            _imageFile = File(pickedFile.path);
            _uploadError = null;
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar('Failed to select image: ${e.toString()}');
    }
  }

  Future<String?> _uploadImageToCloudinary() async {
    if (kIsWeb) {
      if (_webImage == null) return null;
    } else {
      if (_imageFile == null) return null;
    }

    try {
      final uri = Uri.https(
        'api.cloudinary.com',
        '/v1_1/$_cloudName/image/upload',
        {'upload_preset': _uploadPreset},
      );

      var request = http.MultipartRequest('POST', uri);
      
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          _webImage!,
          filename: 'book_cover.jpg',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file', 
          _imageFile!.path,
        ));
      }

      var response = await http.Response.fromStream(await request.send());
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData['secure_url'] as String?;
      } else {
        throw Exception('Upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Image upload failed: ${e.toString()}');
    }
  }

  Future<void> _submitBook() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar('Please fill all required fields correctly');
      return;
    }

    if ((kIsWeb && _webImage == null) || (!kIsWeb && _imageFile == null)) {
      _showErrorSnackbar('Please upload a book cover image');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
      _uploadProgress = null;
    });

    try {
      final imageUrl = await _uploadImageToCloudinary();
      if (imageUrl == null) throw Exception('Image upload returned null URL');

      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user == null) throw Exception('User not authenticated');

      final newBook = BookPost(
        id: '',
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        price: _isForTrade ? 'For Trade' : _priceController.text.trim(),
        condition: _conditionController.text.trim(),
        sellerId: user.uid,
        sellerName: user.displayName ?? 'Anonymous',
        imageUrl: imageUrl,
        location: 'Your Location',
        uploadTime: DateTime.now(),
        categories: _selectedCategory != null ? [_selectedCategory!] : [],
        isForTrade: _isForTrade,
        description: _descriptionController.text.trim(),
        memberSince: DateTime.now(),
        gcashNumber: _gcashController.text.trim().isNotEmpty 
            ? _gcashController.text.trim() 
            : null,
      );

      final bookRepo = Provider.of<BookRepository>(context, listen: false);
      await bookRepo.addBookPost(newBook);

      if (mounted) {
        _showSuccessSnackbar('Book listed successfully!');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _uploadError = e.toString());
      _showErrorSnackbar('Failed to list book: ${e.toString().split(':').first}');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List a New Book'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 28),
            onPressed: _isUploading ? null : _submitBook,
            tooltip: 'Submit Book',
          ),
        ],
      ),
      body: _isUploading
          ? _buildUploadProgress()
          : _buildFormContent(),
    );
  }

  Widget _buildUploadProgress() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: _uploadProgress,
                  strokeWidth: 8,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              if (_uploadProgress != null)
                Text(
                  '${(_uploadProgress! * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _uploadError ?? 'Uploading your book...',
              style: TextStyle(
                color: _uploadError != null ? Colors.red[800] : Colors.black87,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_uploadError != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {
                _isUploading = false;
                _uploadError = null;
              }),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageUploadSection(),
            const SizedBox(height: 24),

            _buildFormField(
              controller: _titleController,
              label: 'Title *',
              icon: Icons.title,
              hint: 'Enter book title',
              validator: (value) => value!.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            _buildFormField(
              controller: _authorController,
              label: 'Author *',
              icon: Icons.person,
              hint: 'Enter author name',
              validator: (value) => value!.trim().isEmpty ? 'Author is required' : null,
            ),
            const SizedBox(height: 16),

            _buildPriceTradeSection(),
            const SizedBox(height: 16),

            _buildCategoryDropdown(),
            const SizedBox(height: 16),

            _buildFormField(
              controller: _conditionController,
              label: 'Condition *',
              icon: Icons.star,
              hint: 'e.g., Like New, Good, Fair',
              validator: (value) => value!.trim().isEmpty ? 'Condition is required' : null,
            ),
            const SizedBox(height: 16),

            _buildFormField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              hint: 'Describe the book\'s condition and any details',
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            _buildFormField(
              controller: _gcashController,
              label: 'GCash Number (Optional)',
              icon: Icons.phone,
              hint: '09XXXXXXXXX',
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value!.trim().isNotEmpty && !RegExp(r'^09\d{9}$').hasMatch(value.trim())) {
                  return 'Please enter a valid GCash number';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _submitBook,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'LIST BOOK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BOOK COVER *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (kIsWeb ? _webImage == null : _imageFile == null) 
                    ? Colors.grey[300]! 
                    : Colors.green,
                width: 2,
              ),
            ),
            child: (kIsWeb ? _webImage == null : _imageFile == null)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo, 
                        size: 50, 
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to upload book cover',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: kIsWeb
                        ? Image.memory(
                            _webImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                  ),
          ),
        ),
        if (kIsWeb ? _webImage == null : _imageFile == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Cover image is required',
              style: TextStyle(
                color: Colors.red[800],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceTradeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRICING',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price *',
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  hintText: '0.00',
                  filled: true,
                  fillColor: _isForTrade ? Colors.grey[200] : Colors.grey[50],
                ),
                keyboardType: TextInputType.number,
                enabled: !_isForTrade,
                validator: (value) {
                  if (_isForTrade) return null;
                  if (value!.trim().isEmpty) return 'Price is required';
                  if (double.tryParse(value.trim()) == null) return 'Enter valid price';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'For Trade', 
                      style: TextStyle(
                        color: Colors.grey[800],
                      ),
                    ),
                    Switch(
                      value: _isForTrade,
                      onChanged: (value) => setState(() => _isForTrade = value),
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          items: _categories
              .map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
          decoration: InputDecoration(
            labelText: 'Select Category',
            prefixIcon: Icon(Icons.category, color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (value) => value == null ? 'Please select a category' : null,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.arrow_drop_down),
          borderRadius: BorderRadius.circular(12),
        ),
      ],
    );
  }
}