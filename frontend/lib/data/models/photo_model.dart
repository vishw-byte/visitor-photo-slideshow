import '../../core/constants/api_constants.dart';

enum PhotoStatus {
  pending,
  approved,
  rejected;

  static PhotoStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'APPROVED':
        return PhotoStatus.approved;
      case 'REJECTED':
        return PhotoStatus.rejected;
      case 'PENDING':
      default:
        return PhotoStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case PhotoStatus.pending:
        return 'In Review';
      case PhotoStatus.approved:
        return 'Approved for Slideshow';
      case PhotoStatus.rejected:
        return 'Not Displayed';
    }
  }
}

class PhotoModel {
  final String id;
  final String? visitorId;
  final String originalFilename;
  final String thumbnailUrl;
  final String photoUrl;
  final PhotoStatus status;
  final bool consentGiven;
  final DateTime? consentGivenAt;
  final String? consentPolicyVersion;
  final bool isDeleted;
  final String? rejectionReason;
  final DateTime createdAt;
  final int? width;
  final int? height;

  PhotoModel({
    required this.id,
    this.visitorId,
    required this.originalFilename,
    required this.thumbnailUrl,
    required this.photoUrl,
    required this.status,
    required this.consentGiven,
    this.consentGivenAt,
    this.consentPolicyVersion,
    this.isDeleted = false,
    this.rejectionReason,
    required this.createdAt,
    this.width,
    this.height,
  });

  /// Constructs absolute URL from relative backend path
  String get absoluteThumbnailUrl {
    if (thumbnailUrl.startsWith('http')) return thumbnailUrl;
    return '${ApiConstants.baseUrl}$thumbnailUrl';
  }

  String get absolutePhotoUrl {
    if (photoUrl.startsWith('http')) return photoUrl;
    return '${ApiConstants.baseUrl}$photoUrl';
  }

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'] as String,
      visitorId: json['visitor_id'] as String?,
      originalFilename: json['original_filename'] as String? ?? 'photo.jpg',
      thumbnailUrl: json['thumbnail_url'] as String,
      photoUrl: json['photo_url'] as String,
      status: PhotoStatus.fromString(json['status'] as String? ?? 'PENDING'),
      consentGiven: json['consent_given'] as bool? ?? false,
      consentGivenAt: json['consent_given_at'] != null
          ? DateTime.parse(json['consent_given_at'] as String)
          : null,
      consentPolicyVersion: json['consent_policy_version'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}
