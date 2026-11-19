import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/photo_model.dart';
import '../providers/photo_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/status_badge.dart';

class MyPhotosScreen extends ConsumerStatefulWidget {
  const MyPhotosScreen({super.key});

  @override
  ConsumerState<MyPhotosScreen> createState() => _MyPhotosScreenState();
}

class _MyPhotosScreenState extends ConsumerState<MyPhotosScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(photoProvider.notifier).loadMyPhotos());
  }

  Future<void> _confirmDelete(PhotoModel photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: Text(
          photo.status == PhotoStatus.approved
              ? 'This photo is currently approved. Deleting it will immediately remove it from the public TV slideshow. Are you sure?'
              : 'Are you sure you want to delete this photo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(photoProvider.notifier).deletePhoto(photo.id);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo deleted and removed from slideshow.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoState = ref.watch(photoProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Uploaded Photos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/upload'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Statuses',
            onPressed: () => ref.read(photoProvider.notifier).loadMyPhotos(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/upload'),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
        label: const Text('Upload More', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(photoProvider.notifier).loadMyPhotos(),
        child: photoState.isLoading && photoState.photos.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : photoState.photos.isEmpty
                ? _buildEmptyState()
                : _buildPhotoList(photoState.photos, authState.visitor?.name),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Photos Uploaded Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have not uploaded any photos for this event yet. Take some great shots and share them on the big screen!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/upload'),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Upload Your First Photo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoList(List<PhotoModel> photos, String? visitorName) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: photos.length,
      separatorBuilder: (_, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final photo = photos[index];
        final formattedDate = DateFormat('MMM d, h:mm a').format(photo.createdAt);

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Header: Visitor Name & Status Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    StatusBadge(status: photo.status),
                  ],
                ),
              ),

              // Image Thumbnail Container
              SizedBox(
                height: 220,
                width: double.infinity,
                child: Image.network(
                  photo.absoluteThumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            SizedBox(height: 6),
                            Text('Thumbnail processing...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Rejection notice if rejected
              if (photo.status == PhotoStatus.rejected && photo.rejectionReason != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.errorColor.withAlpha(20),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppTheme.errorColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Moderation note: ${photo.rejectionReason}',
                          style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Card Actions Footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      photo.originalFilename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                      onPressed: () => _confirmDelete(photo),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete Photo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
