import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/admin_models.dart';

class AdminRepository {
  final DioClient _dioClient;

  AdminRepository({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  /// Authenticates an admin and retrieves JWT Bearer token.
  Future<AdminSessionModel> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.adminLoginEndpoint,
        data: {
          'username': username,
          'password': password,
        },
      );
      return AdminSessionModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Admin login failed.');
    }
  }

  /// Fetches system metrics for dashboard.
  Future<DashboardStatsModel> getDashboardStats() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.adminDashboardEndpoint);
      return DashboardStatsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to fetch dashboard statistics.');
    }
  }

  /// Fetches all photos awaiting moderation.
  Future<List<AdminPhotoDetailModel>> getPendingPhotos() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.adminPendingPhotosEndpoint);
      final list = response.data as List<dynamic>;
      return list.map((json) => AdminPhotoDetailModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to load pending photos.');
    }
  }

  /// Fetches all approved photos.
  Future<List<AdminPhotoDetailModel>> getApprovedPhotos() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.adminApprovedPhotosEndpoint);
      final list = response.data as List<dynamic>;
      return list.map((json) => AdminPhotoDetailModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to load approved photos.');
    }
  }

  /// Fetches all rejected photos.
  Future<List<AdminPhotoDetailModel>> getRejectedPhotos() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.adminRejectedPhotosEndpoint);
      final list = response.data as List<dynamic>;
      return list.map((json) => AdminPhotoDetailModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to load rejected photos.');
    }
  }

  /// Approves a photo for public slideshow display.
  Future<AdminPhotoDetailModel> approvePhoto(String photoId) async {
    try {
      final response = await _dioClient.dio.patch(
        ApiConstants.adminApprovePhotoEndpoint(photoId),
      );
      return AdminPhotoDetailModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to approve photo.');
    }
  }

  /// Rejects a photo with a required explanation.
  Future<AdminPhotoDetailModel> rejectPhoto(String photoId, String reason) async {
    try {
      final response = await _dioClient.dio.patch(
        ApiConstants.adminRejectPhotoEndpoint(photoId),
        data: {
          'rejection_reason': reason,
          'reason': reason,
        },
      );
      return AdminPhotoDetailModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to reject photo.');
    }
  }

  /// Retrieves active slideshow settings.
  Future<SlideshowSettingsModel> getSettings() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.adminSettingsEndpoint);
      return SlideshowSettingsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to fetch slideshow settings.');
    }
  }

  /// Updates slideshow configuration settings.
  Future<SlideshowSettingsModel> updateSettings(SlideshowSettingsModel settings) async {
    try {
      final response = await _dioClient.dio.put(
        ApiConstants.adminSettingsEndpoint,
        data: settings.toJson(),
      );
      return SlideshowSettingsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to update slideshow settings.');
    }
  }
}
