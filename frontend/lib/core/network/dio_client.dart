import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/session_storage.dart';

class DioClient {
  late final Dio dio;
  final SessionStorage _sessionStorage = SessionStorage();

  DioClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isAdminEndpoint = options.path.contains('/admin');

          if (isAdminEndpoint) {
            // Admin endpoints only receive Bearer JWT token
            final adminToken = await _sessionStorage.getAdminToken();
            if (adminToken != null && adminToken.isNotEmpty && !options.headers.containsKey('Authorization')) {
              options.headers['Authorization'] = 'Bearer $adminToken';
            }
          } else {
            // Visitor endpoints receive X-Visitor-Token
            final token = await _sessionStorage.getSessionToken();
            if (token != null && token.isNotEmpty) {
              options.headers['X-Visitor-Token'] = token;
            }

            // For media endpoints, if viewed in admin mode, attach Bearer token
            if (options.path.contains('/media/')) {
              final adminToken = await _sessionStorage.getAdminToken();
              if (adminToken != null && adminToken.isNotEmpty && !options.headers.containsKey('Authorization')) {
                options.headers['Authorization'] = 'Bearer $adminToken';
              }
            }
          }

          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Format user-friendly error messages
          String errorMessage = 'A network error occurred. Please try again.';
          if (error.response?.data is Map) {
            final data = error.response?.data as Map;
            if (data.containsKey('detail')) {
              errorMessage = data['detail'].toString();
            } else if (data.containsKey('error') && data['error'] is Map) {
              errorMessage = data['error']['message'] ?? errorMessage;
            }
          } else if (error.type == DioExceptionType.connectionTimeout) {
            errorMessage = 'Connection timed out. Please check your internet connection.';
          } else if (error.type == DioExceptionType.connectionError) {
            errorMessage = 'Unable to connect to server. Please verify backend is running.';
          }
          return handler.next(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: errorMessage,
            ),
          );
        },
      ),
    );
  }
}
