import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/photo_provider.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _consentGiven = false; // Unchecked by default per strict requirement

  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2560,
        maxHeight: 2560,
      );
      if (!mounted) return;
      if (picked.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(picked);
          // Limit to max 10
          if (_selectedImages.length > 10) {
            _selectedImages.removeRange(10, _selectedImages.length);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 10 photos can be selected at once.')),
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _handleUpload() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one photo to upload.')),
      );
      return;
    }

    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must agree to the public display consent to upload.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final success = await ref.read(photoProvider.notifier).uploadPhotos(
          files: _selectedImages,
          consentGiven: _consentGiven,
        );

    if (mounted && success) {
      setState(() {
        _selectedImages.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photos uploaded successfully! Waiting for host review.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final photoState = ref.watch(photoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Event Photos'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/my-photos'),
            icon: const Icon(Icons.collections, size: 20),
            label: const Text('My Photos'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User greeting banner
            if (authState.visitor != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryLight.withAlpha(50),
                    child: Text(
                      authState.visitor!.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uploading as ${authState.visitor!.name}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const Text(
                          'Your name will accompany your approved photos on screen.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
            ],

            // Admin Review Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade800, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Photos require host approval before going live on the Smart TV slideshow. Inappropriate or blurry photos will be declined.',
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pick Image Area
            InkWell(
              onTap: photoState.isUploading ? null : _pickImages,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withAlpha(80),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tap to select photos from gallery',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Supports JPEG, PNG, WebP (up to 10 photos)',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Selected Images Preview Grid
            if (_selectedImages.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Photos (${_selectedImages.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton(
                    onPressed: photoState.isUploading
                        ? null
                        : () => setState(() => _selectedImages.clear()),
                    child: const Text('Clear All', style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedImages.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final xfile = _selectedImages[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: kIsWeb
                            ? Image.network(xfile.path, fit: BoxFit.cover)
                            : Image.file(File(xfile.path), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: photoState.isUploading ? null : () => _removeImage(index),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // Explicit Public Display Consent Checkbox (unchecked by default)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _consentGiven ? AppTheme.primaryColor : Colors.grey.shade300,
                  width: _consentGiven ? 1.5 : 1.0,
                ),
              ),
              child: CheckboxListTile(
                value: _consentGiven,
                activeColor: AppTheme.primaryColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: const Text(
                  'Public Display Consent (Required)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'I consent for these photos to be presented on the public event slideshow. I understand I can delete my photos at any time to remove them from display.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                onChanged: photoState.isUploading
                    ? null
                    : (val) {
                        setState(() {
                          _consentGiven = val ?? false;
                        });
                      },
              ),
            ),
            const SizedBox(height: 20),

            // Progress Bar / Messages
            if (photoState.isUploading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: photoState.uploadProgress > 0 ? photoState.uploadProgress : null,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    photoState.uploadProgress > 0
                        ? 'Uploading: ${(photoState.uploadProgress * 100).toInt()}%'
                        : 'Processing & validating file signatures...',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (photoState.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        photoState.errorMessage!,
                        style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_selectedImages.isEmpty || !_consentGiven || photoState.isUploading)
                    ? null
                    : _handleUpload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  photoState.isUploading
                      ? 'Uploading Photos...'
                      : 'Upload ${_selectedImages.length} Photo(s)',
                ),
              ),
            ),
            const SizedBox(height: 12),

            Center(
              child: TextButton.icon(
                onPressed: () => context.go('/my-photos'),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('View My Previously Uploaded Photos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
