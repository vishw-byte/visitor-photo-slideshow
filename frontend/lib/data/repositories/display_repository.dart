import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/display_models.dart';

class DisplayRepository {
  final DioClient _dioClient;

  DisplayRepository({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  /// Fetches approved public photos for the Smart TV display.
  Future<DisplayFeedModel> getDisplayPhotos() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.displayPhotosEndpoint);
      return DisplayFeedModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to load slideshow photos.');
    }
  }

  /// Fetches public display settings (duration, transitions, toggles).
  Future<DisplaySettingsModel> getDisplaySettings() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.displaySettingsEndpoint);
      return DisplaySettingsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Failed to load slideshow display settings.');
    }
  }
}
