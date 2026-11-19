import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/session_storage.dart';
import '../../data/models/visitor_model.dart';
import '../../data/repositories/visitor_repository.dart';

class AuthState {
  final VisitorModel? visitor;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.visitor,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => visitor != null;

  AuthState copyWith({
    VisitorModel? visitor,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      visitor: visitor ?? this.visitor,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final VisitorRepository _repository;
  final SessionStorage _storage;

  AuthNotifier({
    VisitorRepository? repository,
    SessionStorage? storage,
    bool autoLoad = true,
  })  : _repository = repository ?? VisitorRepository(),
        _storage = storage ?? SessionStorage(),
        super(const AuthState()) {
    if (autoLoad) {
      _loadExistingSession();
    }
  }

  /// Automatically checks for an existing saved session on startup.
  Future<void> _loadExistingSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final savedVisitor = await _storage.getVisitorProfile();
      if (savedVisitor != null) {
        state = state.copyWith(visitor: savedVisitor, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Registers visitor and securely saves session.
  Future<bool> register({
    required String name,
    String? email,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final visitor = await _repository.registerVisitor(name: name, email: email);
      await _storage.saveVisitorSession(visitor);
      state = state.copyWith(visitor: visitor, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Clears stored session.
  Future<void> logout() async {
    await _storage.clearSession();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
