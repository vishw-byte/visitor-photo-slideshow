import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/admin_auth_provider.dart';
import '../../providers/moderation_provider.dart';
import '../../../data/models/admin_models.dart';

class PhotoModerationScreen extends ConsumerStatefulWidget {
  const PhotoModerationScreen({super.key});

  @override
  ConsumerState<PhotoModerationScreen> createState() => _PhotoModerationScreenState();
}

class _PhotoModerationScreenState extends ConsumerState<PhotoModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(moderationProvider.notifier).loadAllPhotos();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRejectDialog(AdminPhotoDetailModel photo) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.cancel_outlined, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Reject Photo'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting photo "${photo.originalFilename.isNotEmpty ? photo.originalFilename : photo.id}". Please specify a reason for moderation records.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('rejection_reason_field'),
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason *',
                  hintText: 'e.g., Inappropriate content, low quality, duplicate submission',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'A rejection reason is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_reject_button'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final reason = reasonController.text;
                Navigator.of(ctx).pop();
                await ref.read(moderationProvider.notifier).rejectPhoto(photo.id, reason);
              }
            },
            child: const Text('Reject Photo'),
          ),
        ],
      ),
    );
  }

  void _showConsentWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text('Approval Blocked'),
          ],
        ),
        content: const Text(
          'This photo cannot be approved because the visitor did not grant consent for public slideshow display.\n\nVisitor privacy rules strictly prevent approving non-consented photos.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showPhotoDetailsDialog(AdminPhotoDetailModel photo, String? token) {
    final authHeader = token != null ? {'Authorization': 'Bearer $token'} : null;
    final photoUrl = ApiConstants.fullPhotoUrl(photo.id);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        photo.originalFilename.isNotEmpty ? photo.originalFilename : 'Photo Preview',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Image view
              Flexible(
                child: Container(
                  color: Colors.black12,
                  child: Center(
                    child: Image.network(
                      photoUrl,
                      headers: authHeader,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.broken_image, size: 48, color: AppTheme.textSecondary),
                              SizedBox(height: 8),
                              Text('Image preview unavailable in secure sandbox'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Metadata & Status
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Visitor: ${photo.visitorName}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (photo.visitorEmail != null) ...[
                          const SizedBox(width: 8),
                          Text('(${photo.visitorEmail})', style: const TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          photo.consentGiven
                              ? 'Consent Granted (${photo.consentPolicyVersion ?? 'v1.0'})'
                              : 'No Public Display Consent',
                          style: TextStyle(
                            color: photo.consentGiven ? AppTheme.successColor : AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Size: ${photo.formattedSize}  |  Format: ${photo.mimeType}  |  Status: ${photo.status}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if (photo.rejectionReason != null && photo.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Rejection Reason: ${photo.rejectionReason}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.errorColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);
    final modState = ref.watch(moderationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Moderation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Photos',
            onPressed: () => ref.read(moderationProvider.notifier).loadAllPhotos(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending'),
                  const SizedBox(width: 6),
                  _CountBadge(
                    count: modState.pendingPhotos.length,
                    color: AppTheme.warningColor,
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Approved'),
                  const SizedBox(width: 6),
                  _CountBadge(
                    count: modState.approvedPhotos.length,
                    color: AppTheme.successColor,
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Rejected'),
                  const SizedBox(width: 6),
                  _CountBadge(
                    count: modState.rejectedPhotos.length,
                    color: AppTheme.errorColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: modState.isLoadingPhotos &&
              modState.pendingPhotos.isEmpty &&
              modState.approvedPhotos.isEmpty &&
              modState.rejectedPhotos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Feedback message banner
                if (modState.successMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppTheme.successColor.withAlpha(25),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.successColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            modState.successMessage!,
                            style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => ref.read(moderationProvider.notifier).clearMessages(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (modState.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppTheme.errorColor.withAlpha(25),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            modState.errorMessage!,
                            style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => ref.read(moderationProvider.notifier).clearMessages(),
                        ),
                      ],
                    ),
                  ),
                ],

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Pending Tab
                      _PhotoListView(
                        photos: modState.pendingPhotos,
                        emptyText: 'No pending photos to moderate. All clear!',
                        emptyIcon: Icons.task_alt_rounded,
                        adminToken: authState.token,
                        actionLoadingId: modState.actionLoadingPhotoId,
                        onPreview: (photo) => _showPhotoDetailsDialog(photo, authState.token),
                        onApprove: (photo) {
                          if (!photo.consentGiven) {
                            _showConsentWarningDialog();
                          } else {
                            ref.read(moderationProvider.notifier).approvePhoto(photo.id);
                          }
                        },
                        onReject: (photo) => _showRejectDialog(photo),
                      ),

                      // Approved Tab
                      _PhotoListView(
                        photos: modState.approvedPhotos,
                        emptyText: 'No approved photos in slideshow rotation.',
                        emptyIcon: Icons.photo_library_outlined,
                        adminToken: authState.token,
                        actionLoadingId: modState.actionLoadingPhotoId,
                        onPreview: (photo) => _showPhotoDetailsDialog(photo, authState.token),
                        onReject: (photo) => _showRejectDialog(photo),
                      ),

                      // Rejected Tab
                      _PhotoListView(
                        photos: modState.rejectedPhotos,
                        emptyText: 'No rejected photos.',
                        emptyIcon: Icons.check_circle_outline,
                        adminToken: authState.token,
                        actionLoadingId: modState.actionLoadingPhotoId,
                        onPreview: (photo) => _showPhotoDetailsDialog(photo, authState.token),
                        onApprove: (photo) {
                          if (!photo.consentGiven) {
                            _showConsentWarningDialog();
                          } else {
                            ref.read(moderationProvider.notifier).approvePhoto(photo.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PhotoListView extends StatelessWidget {
  final List<AdminPhotoDetailModel> photos;
  final String emptyText;
  final IconData emptyIcon;
  final String? adminToken;
  final String? actionLoadingId;
  final void Function(AdminPhotoDetailModel) onPreview;
  final void Function(AdminPhotoDetailModel)? onApprove;
  final void Function(AdminPhotoDetailModel)? onReject;

  const _PhotoListView({
    required this.photos,
    required this.emptyText,
    required this.emptyIcon,
    required this.adminToken,
    required this.actionLoadingId,
    required this.onPreview,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: AppTheme.textSecondary.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              emptyText,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final authHeader = adminToken != null ? {'Authorization': 'Bearer $adminToken'} : null;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: photos.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final photo = photos[index];
        final isBusy = actionLoadingId == photo.id;
        final thumbUrl = ApiConstants.thumbnailUrl(photo.id);

        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail preview
                InkWell(
                  onTap: () => onPreview(photo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 90,
                      height: 90,
                      color: Colors.black12,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            thumbUrl,
                            headers: authHeader,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.image_outlined, color: AppTheme.textSecondary),
                              );
                            },
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.zoom_in, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Details & Controls
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visitor info & size
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              photo.visitorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            photo.formattedSize,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Filename & Upload Date
                      Text(
                        'File: ${photo.originalFilename.isNotEmpty ? photo.originalFilename : photo.filename}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Uploaded: ${photo.createdAt}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),

                      // Consent & Rejection badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: photo.consentGiven
                                  ? AppTheme.successColor.withAlpha(20)
                                  : AppTheme.errorColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              photo.consentGiven ? 'Consent Granted' : 'No Consent',
                              style: TextStyle(
                                color: photo.consentGiven ? AppTheme.successColor : AppTheme.errorColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (photo.rejectionReason != null && photo.rejectionReason!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withAlpha(15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Reason: ${photo.rejectionReason}',
                                style: const TextStyle(
                                  color: AppTheme.errorColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action Buttons
                      if (isBusy)
                        const SizedBox(
                          height: 36,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            if (onApprove != null) ...[
                              ElevatedButton.icon(
                                key: Key('approve_button_${photo.id}'),
                                icon: const Icon(Icons.check, size: 16),
                                label: Text(photo.isRejected ? 'Re-Approve' : 'Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: photo.consentGiven ? AppTheme.successColor : Colors.grey,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => onApprove!(photo),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (onReject != null) ...[
                              OutlinedButton.icon(
                                key: Key('reject_button_${photo.id}'),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                  side: const BorderSide(color: AppTheme.errorColor),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => onReject!(photo),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
