class DisplayPhotoModel {
  final String id;
  final String url;
  final String visitorName;
  final String? createdAt;
  final int? width;
  final int? height;

  const DisplayPhotoModel({
    required this.id,
    required this.url,
    required this.visitorName,
    this.createdAt,
    this.width,
    this.height,
  });

  factory DisplayPhotoModel.fromJson(Map<String, dynamic> json) {
    return DisplayPhotoModel(
      id: json['id'] as String,
      url: json['url'] as String,
      visitorName: json['visitor_name'] as String? ?? 'Event Visitor',
      createdAt: json['created_at'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'visitor_name': visitorName,
        'created_at': createdAt,
        'width': width,
        'height': height,
      };
}

class DisplayFeedModel {
  final List<DisplayPhotoModel> photos;
  final int totalCount;
  final bool slideshowEnabled;

  const DisplayFeedModel({
    required this.photos,
    required this.totalCount,
    required this.slideshowEnabled,
  });

  factory DisplayFeedModel.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? [];
    return DisplayFeedModel(
      photos: rawPhotos
          .map((p) => DisplayPhotoModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int? ?? rawPhotos.length,
      slideshowEnabled: json['slideshow_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'photos': photos.map((p) => p.toJson()).toList(),
        'total_count': totalCount,
        'slideshow_enabled': slideshowEnabled,
      };
}

class DisplaySettingsModel {
  final int slideDurationSeconds;
  final String transitionEffect;
  final bool showVisitorName;
  final bool shufflePlayback;
  final bool slideshowAutoplay;
  final bool slideshowEnabled;
  final int refreshIntervalSeconds;
  final bool showQrCode;
  final String? visitorPortalUrl;
  final String? portalUrl;
  final String? qrCodeUrl;

  const DisplaySettingsModel({
    this.slideDurationSeconds = 10,
    this.transitionEffect = 'FADE',
    this.showVisitorName = true,
    this.shufflePlayback = false,
    this.slideshowAutoplay = true,
    this.slideshowEnabled = true,
    this.refreshIntervalSeconds = 15,
    this.showQrCode = true,
    this.visitorPortalUrl,
    this.portalUrl,
    this.qrCodeUrl,
  });

  factory DisplaySettingsModel.fromJson(Map<String, dynamic> json) {
    return DisplaySettingsModel(
      slideDurationSeconds: json['slide_duration_seconds'] as int? ?? 10,
      transitionEffect: (json['transition_effect'] as String? ?? 'FADE').toUpperCase(),
      showVisitorName: json['show_visitor_name'] as bool? ?? true,
      shufflePlayback: json['shuffle_playback'] as bool? ?? false,
      slideshowAutoplay: json['slideshow_autoplay'] as bool? ?? true,
      slideshowEnabled: json['slideshow_enabled'] as bool? ?? true,
      refreshIntervalSeconds: json['refresh_interval_seconds'] as int? ?? 15,
      showQrCode: json['show_qr_code'] as bool? ?? true,
      visitorPortalUrl: json['visitor_portal_url'] as String?,
      portalUrl: json['portal_url'] as String? ?? json['visitor_portal_url'] as String?,
      qrCodeUrl: json['qr_code_url'] as String? ?? '/api/v1/display/qr-code',
    );
  }

  Map<String, dynamic> toJson() => {
        'slide_duration_seconds': slideDurationSeconds,
        'transition_effect': transitionEffect,
        'show_visitor_name': showVisitorName,
        'shuffle_playback': shufflePlayback,
        'slideshow_autoplay': slideshowAutoplay,
        'slideshow_enabled': slideshowEnabled,
        'refresh_interval_seconds': refreshIntervalSeconds,
        'show_qr_code': showQrCode,
        'visitor_portal_url': visitorPortalUrl,
        'portal_url': portalUrl,
        'qr_code_url': qrCodeUrl,
      };
}
