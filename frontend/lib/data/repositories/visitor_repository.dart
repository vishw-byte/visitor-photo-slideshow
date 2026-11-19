import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/visitor_model.dart';
import '../models/photo_model.dart';

class VisitorRepository {
  final DioClient _client;

  VisitorRepository([DioClient? client]) : _client = client ?? DioClient();

  /// Registers visitor and returns profile with session token.
  Future<VisitorModel> registerVisitor({
    required String name,
    String? email,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.registerEndpoint,
        data: {
          'name': name.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        },
      );
      return VisitorModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to register visitor');
    }
  }

  /// Uploads one or multiple photos with explicit public display consent.
  Future<List<PhotoModel>> uploadPhotos({
    required List<XFile> files,
    required bool consentGiven,
    String consentPolicyVersion = 'v1.0',
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      final formData = FormData();

      for (final file in files) {
        final bytes = await file.readAsBytes();
        formData.files.add(
          MapEntry(
            'files',
            MultipartFile.fromBytes(
              bytes,
              filename: file.name.isNotEmpty ? file.name : 'photo.jpg',
            ),
          ),
        );
      }

      formData.fields.add(MapEntry('consent_given', consentGiven ? 'true' : 'false'));
      formData.fields.add(MapEntry('consent_policy_version', consentPolicyVersion));

      final response = await _client.dio.post(
        ApiConstants.uploadEndpoint,
        data: formData,
        onSendProgress: onProgress,
      );

      final data = response.data as Map<String, dynamic>;
      final list = (data['photos'] as List)
          .map((item) => PhotoModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Upload failed');
    }
  }

  /// Fetches the authenticated visitor's previously uploaded photos.
  Future<List<PhotoModel>> getMyPhotos() async {
    try {
      final response = await _client.dio.get(ApiConstants.myPhotosEndpoint);
      final list = (response.data as List)
          .map((item) => PhotoModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to load photos');
    }
  }

  /// Deletes an uploaded photo owned by the visitor.
  Future<bool> deletePhoto(String photoId) async {
    try {
      final response = await _client.dio.delete('${ApiConstants.deletePhotoEndpoint}/$photoId');
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to delete photo');
    }
  }
}
