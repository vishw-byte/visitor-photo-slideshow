import 'package:flutter/foundation.dart';

class ApiConstants {
  // Allow overriding via --dart-define=API_BASE_URL=...
  // In Flutter Web, dynamically detects the host and targets the backend port (default 8000)
  // so scanning a LAN QR code on a mobile device works seamlessly without hardcoding any IP address.
  static String get baseUrl {
    const String envBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    if (kIsWeb) {
      try {
        final uri = Uri.base;
        final host = uri.host;
        if (host.isNotEmpty) {
          // If accessing via development web server on port 3000, target port 8000 on the same host/IP
          if (uri.port == 3000) {
            return '${uri.scheme}://$host:8000';
          }
          // If behind a standard reverse proxy (e.g. Nginx on port 80 or 443)
          if (uri.port == 80 || uri.port == 443) {
            return uri.origin;
          }
          // Default fallback for custom web ports
          return '${uri.scheme}://$host:8000';
        }
      } catch (_) {}
    }

    return 'http://127.0.0.1:8000';
  }

  // Default visitor portal URL (fallback when not configured on server)
  static String get defaultPortalUrl {
    const String envPortalUrl = String.fromEnvironment('PUBLIC_PORTAL_URL');
    if (envPortalUrl.isNotEmpty) {
      return envPortalUrl;
    }

    if (kIsWeb) {
      try {
        final uri = Uri.base;
        if (uri.host.isNotEmpty) {
          return uri.origin;
        }
      } catch (_) {}
    }

    return 'http://127.0.0.1:3000';
  }

  static const String registerEndpoint = '/api/v1/visitors/register';
  static const String uploadEndpoint = '/api/v1/photos/upload';
  static const String myPhotosEndpoint = '/api/v1/photos/my-photos';
  static const String deletePhotoEndpoint = '/api/v1/photos'; // + /{photo_id}
  static const String healthEndpoint = '/api/v1/health';

  // Admin Portal Endpoints
  static const String adminLoginEndpoint = '/api/v1/admin/login';
  static const String adminDashboardEndpoint = '/api/v1/admin/dashboard';
  static const String adminPendingPhotosEndpoint = '/api/v1/admin/photos/pending';
  static const String adminApprovedPhotosEndpoint = '/api/v1/admin/photos/approved';
  static const String adminRejectedPhotosEndpoint = '/api/v1/admin/photos/rejected';
  static String adminApprovePhotoEndpoint(String photoId) => '/api/v1/admin/photos/$photoId/approve';
  static String adminRejectPhotoEndpoint(String photoId) => '/api/v1/admin/photos/$photoId/reject';
  static const String adminSettingsEndpoint = '/api/v1/admin/settings';

  // Smart TV Display Endpoints (Phase 4)
  static const String displayPhotosEndpoint = '/api/v1/display/photos';
  static const String displaySettingsEndpoint = '/api/v1/display/settings';
  static String displayMediaUrl(String photoId) => '$baseUrl/api/v1/media/slideshow/$photoId';

  // Media URLs prefix
  static String fullPhotoUrl(String photoId) => '$baseUrl/api/v1/media/photos/$photoId';
  static String thumbnailUrl(String photoId) => '$baseUrl/api/v1/media/thumbnails/$photoId';
}
