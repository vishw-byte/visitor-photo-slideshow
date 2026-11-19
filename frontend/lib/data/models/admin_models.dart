class AdminSessionModel {
  final String accessToken;
  final String tokenType;
  final String username;

  const AdminSessionModel({
    required this.accessToken,
    required this.tokenType,
    required this.username,
  });

  factory AdminSessionModel.fromJson(Map<String, dynamic> json) {
    return AdminSessionModel(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      username: json['username'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'username': username,
      };
}

class DashboardStatsModel {
  final int totalPhotos;
  final int pendingPhotos;
  final int approvedPhotos;
  final int rejectedPhotos;
  final int totalVisitors;

  const DashboardStatsModel({
    required this.totalPhotos,
    required this.pendingPhotos,
    required this.approvedPhotos,
    required this.rejectedPhotos,
    required this.totalVisitors,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalPhotos: json['total_photos'] as int? ?? 0,
      pendingPhotos: json['pending_photos'] as int? ?? 0,
      approvedPhotos: json['approved_photos'] as int? ?? 0,
      rejectedPhotos: json['rejected_photos'] as int? ?? 0,
      totalVisitors: json['total_visitors'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_photos': totalPhotos,
        'pending_photos': pendingPhotos,
        'approved_photos': approvedPhotos,
        'rejected_photos': rejectedPhotos,
        'total_visitors': totalVisitors,
      };
}

class AdminPhotoDetailModel {
  final String id;
  final String filename;
  final String originalFilename;
  final int fileSizeBytes;
  final String mimeType;
  final String status;
  final String visitorId;
  final String visitorName;
  final String? visitorEmail;
  final bool consentGiven;
  final String? consentPolicyVersion;
  final String? consentGivenAt;
  final String? rejectionReason;
  final String? reviewedByAdminId;
  final String? reviewedAt;
  final String createdAt;
  final String? url;
  final String? thumbnailUrl;

  const AdminPhotoDetailModel({
    required this.id,
    required this.filename,
    required this.originalFilename,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.status,
    required this.visitorId,
    required this.visitorName,
    this.visitorEmail,
    required this.consentGiven,
    this.consentPolicyVersion,
    this.consentGivenAt,
    this.rejectionReason,
    this.reviewedByAdminId,
    this.reviewedAt,
    required this.createdAt,
    this.url,
    this.thumbnailUrl,
  });

  factory AdminPhotoDetailModel.fromJson(Map<String, dynamic> json) {
    return AdminPhotoDetailModel(
      id: json['id'] as String,
      filename: json['filename'] as String? ?? '',
      originalFilename: json['original_filename'] as String? ?? '',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      mimeType: json['mime_type'] as String? ?? 'image/jpeg',
      status: json['status'] as String? ?? 'PENDING',
      visitorId: json['visitor_id'] as String? ?? '',
      visitorName: json['visitor_name'] as String? ?? 'Anonymous Visitor',
      visitorEmail: json['visitor_email'] as String?,
      consentGiven: json['consent_given'] as bool? ?? false,
      consentPolicyVersion: json['consent_policy_version'] as String?,
      consentGivenAt: json['consent_given_at'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      reviewedByAdminId: (json['reviewed_by_admin_id'] ?? json['reviewed_by']) as String?,
      reviewedAt: json['reviewed_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class SlideshowSettingsModel {
  final int slideDurationSeconds;
  final String transitionEffect;
  final bool displayVisitorName;
  final bool shuffleMode;
  final bool slideshowAutoplay;
  final bool slideshowEnabled;
  final bool showQrCode;
  final String? visitorPortalUrl;
  final String? updatedAt;

  const SlideshowSettingsModel({
    required this.slideDurationSeconds,
    required this.transitionEffect,
    required this.displayVisitorName,
    required this.shuffleMode,
    required this.slideshowAutoplay,
    required this.slideshowEnabled,
    this.showQrCode = true,
    this.visitorPortalUrl,
    this.updatedAt,
  });

  factory SlideshowSettingsModel.fromJson(Map<String, dynamic> json) {
    return SlideshowSettingsModel(
      slideDurationSeconds: json['slide_duration_seconds'] as int? ?? 5,
      transitionEffect: json['transition_effect'] as String? ?? 'fade',
      displayVisitorName: json['display_visitor_name'] as bool? ?? true,
      shuffleMode: json['shuffle_mode'] as bool? ?? false,
      slideshowAutoplay: json['slideshow_autoplay'] as bool? ?? true,
      slideshowEnabled: json['slideshow_enabled'] as bool? ?? true,
      showQrCode: json['show_qr_code'] as bool? ?? true,
      visitorPortalUrl: json['visitor_portal_url'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'slide_duration_seconds': slideDurationSeconds,
        'transition_effect': transitionEffect,
        'display_visitor_name': displayVisitorName,
        'shuffle_mode': shuffleMode,
        'slideshow_autoplay': slideshowAutoplay,
        'slideshow_enabled': slideshowEnabled,
        'show_qr_code': showQrCode,
        'visitor_portal_url': visitorPortalUrl,
      };

  SlideshowSettingsModel copyWith({
    int? slideDurationSeconds,
    String? transitionEffect,
    bool? displayVisitorName,
    bool? shuffleMode,
    bool? slideshowAutoplay,
    bool? slideshowEnabled,
    bool? showQrCode,
    String? visitorPortalUrl,
  }) {
    return SlideshowSettingsModel(
      slideDurationSeconds: slideDurationSeconds ?? this.slideDurationSeconds,
      transitionEffect: transitionEffect ?? this.transitionEffect,
      displayVisitorName: displayVisitorName ?? this.displayVisitorName,
      shuffleMode: shuffleMode ?? this.shuffleMode,
      slideshowAutoplay: slideshowAutoplay ?? this.slideshowAutoplay,
      slideshowEnabled: slideshowEnabled ?? this.slideshowEnabled,
      showQrCode: showQrCode ?? this.showQrCode,
      visitorPortalUrl: visitorPortalUrl ?? this.visitorPortalUrl,
      updatedAt: updatedAt,
    );
  }
}
