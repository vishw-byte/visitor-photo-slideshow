import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';

class SettingsState {
  final SlideshowSettingsModel? settings;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const SettingsState({
    this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  SettingsState copyWith({
    SlideshowSettingsModel? settings,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final AdminRepository _repository;

  SettingsNotifier({AdminRepository? repository})
      : _repository = repository ?? AdminRepository(),
        super(const SettingsState());

  /// Loads current slideshow configuration from backend.
  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final settings = await _repository.getSettings();
      state = state.copyWith(settings: settings, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Updates slideshow configuration.
  Future<bool> updateSettings(SlideshowSettingsModel newSettings) async {
    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);
    try {
      final updated = await _repository.updateSettings(newSettings);
      state = state.copyWith(
        settings: updated,
        isSaving: false,
        successMessage: 'Slideshow settings updated successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
