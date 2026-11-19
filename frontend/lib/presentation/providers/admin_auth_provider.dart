import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/session_storage.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';

class AdminAuthState {
  final AdminSessionModel? session;
  final bool isLoading;
  final String? errorMessage;

  const AdminAuthState({
    this.session,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => session != null && session!.accessToken.isNotEmpty;
  String? get username => session?.username;
  String? get token => session?.accessToken;

  AdminAuthState copyWith({
    AdminSessionModel? session,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AdminAuthState(
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final AdminRepository _repository;
  final SessionStorage _storage;

  AdminAuthNotifier({
    AdminRepository? repository,
    SessionStorage? storage,
    bool autoLoad = true,
  })  : _repository = repository ?? AdminRepository(),
        _storage = storage ?? SessionStorage(),
        super(const AdminAuthState()) {
    if (autoLoad) {
      _loadExistingSession();
    }
  }

  /// Automatically validates saved admin token on startup.
  Future<void> _loadExistingSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.getAdminToken();
      final username = await _storage.getAdminUsername();

      if (token != null && token.isNotEmpty && username != null) {
        state = state.copyWith(
          session: AdminSessionModel(
            accessToken: token,
            tokenType: 'bearer',
            username: username,
          ),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Authenticates administrator and stores session securely.
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _repository.login(
        username: username.trim(),
        password: password,
      );
      await _storage.saveAdminSession(
        token: session.accessToken,
        username: session.username,
      );
      state = state.copyWith(session: session, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Logs out administrator and clears stored session.
  Future<void> logout() async {
    await _storage.clearAdminSession();
    state = const AdminAuthState();
  }
}

final adminAuthProvider = StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) {
  return AdminAuthNotifier();
});
