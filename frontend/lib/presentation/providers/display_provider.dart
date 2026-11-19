import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/display_models.dart';
import '../../data/repositories/display_repository.dart';

class DisplayState {
  final List<DisplayPhotoModel> photos;
  final DisplaySettingsModel settings;
  final int currentIndex;
  final bool isLoading;
  final bool isBackgroundRefreshing;
  final bool isPaused;
  final String? errorMessage;

  const DisplayState({
    this.photos = const [],
    this.settings = const DisplaySettingsModel(),
    this.currentIndex = 0,
    this.isLoading = false,
    this.isBackgroundRefreshing = false,
    this.isPaused = false,
    this.errorMessage,
  });

  bool get isEmpty => photos.isEmpty;
  bool get isEnabled => settings.slideshowEnabled;
  DisplayPhotoModel? get currentPhoto =>
      photos.isNotEmpty && currentIndex < photos.length ? photos[currentIndex] : null;

  DisplayState copyWith({
    List<DisplayPhotoModel>? photos,
    DisplaySettingsModel? settings,
    int? currentIndex,
    bool? isLoading,
    bool? isBackgroundRefreshing,
    bool? isPaused,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DisplayState(
      photos: photos ?? this.photos,
      settings: settings ?? this.settings,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isBackgroundRefreshing: isBackgroundRefreshing ?? this.isBackgroundRefreshing,
      isPaused: isPaused ?? this.isPaused,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DisplayNotifier extends StateNotifier<DisplayState> {
  final DisplayRepository _repository;
  Timer? _rotationTimer;
  Timer? _pollingTimer;

  DisplayNotifier({
    DisplayRepository? repository,
    bool autoStart = true,
  })  : _repository = repository ?? DisplayRepository(),
        super(const DisplayState()) {
    if (autoStart) {
      loadInitial();
    }
  }

  /// Initial load of display settings and photo queue.
  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final settings = await _repository.getDisplaySettings();
      final feed = await _repository.getDisplayPhotos();

      List<DisplayPhotoModel> initialPhotos = List.from(feed.photos);
      if (settings.shufflePlayback && initialPhotos.length > 1) {
        initialPhotos.shuffle();
      }

      state = state.copyWith(
        settings: settings,
        photos: initialPhotos,
        currentIndex: 0,
        isLoading: false,
        clearError: true,
      );

      _setupRotationTimer();
      _setupPollingTimer();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      // Even if initial load fails, set up polling to auto-recover when backend becomes reachable
      _setupPollingTimer();
    }
  }

  /// Sets up rotation timer based on slide duration.
  void _setupRotationTimer() {
    _rotationTimer?.cancel();

    if (!state.settings.slideshowAutoplay ||
        state.isPaused ||
        state.photos.length <= 1 ||
        !state.settings.slideshowEnabled) {
      return;
    }

    final durationSec = state.settings.slideDurationSeconds.clamp(3, 120);
    _rotationTimer = Timer.periodic(Duration(seconds: durationSec), (_) {
      nextPhoto();
    });
  }

  /// Advances to next photo in the queue.
  void nextPhoto() {
    if (state.photos.isEmpty) return;
    final nextIdx = (state.currentIndex + 1) % state.photos.length;
    state = state.copyWith(currentIndex: nextIdx);
  }

  /// Navigates to previous photo in the queue.
  void previousPhoto() {
    if (state.photos.isEmpty) return;
    final prevIdx = (state.currentIndex - 1 + state.photos.length) % state.photos.length;
    state = state.copyWith(currentIndex: prevIdx);
    _setupRotationTimer(); // reset rotation interval after manual interaction
  }

  /// Sets active photo directly.
  void setIndex(int index) {
    if (index >= 0 && index < state.photos.length) {
      state = state.copyWith(currentIndex: index);
      _setupRotationTimer();
    }
  }

  /// Toggles pause/play state for slideshow rotation.
  void togglePause() {
    final newPaused = !state.isPaused;
    state = state.copyWith(isPaused: newPaused);
    if (newPaused) {
      _rotationTimer?.cancel();
    } else {
      _setupRotationTimer();
    }
  }

  /// Background polling timer for real-time synchronization.
  void _setupPollingTimer() {
    _pollingTimer?.cancel();
    final interval = state.settings.refreshIntervalSeconds.clamp(5, 300);
    _pollingTimer = Timer.periodic(Duration(seconds: interval), (_) {
      _pollUpdates();
    });
  }

  /// Periodically checks backend for newly approved or deleted photos, and settings changes.
  Future<void> _pollUpdates() async {
    state = state.copyWith(isBackgroundRefreshing: true);
    try {
      final newSettings = await _repository.getDisplaySettings();
      final newFeed = await _repository.getDisplayPhotos();

      final currentPhotoId = state.currentPhoto?.id;
      final newPhotos = newFeed.photos;

      // Determine new index to prevent jump or out-of-bounds if current photo was deleted
      int newIndex = state.currentIndex;
      if (newPhotos.isNotEmpty) {
        final existingIdx = newPhotos.indexWhere((p) => p.id == currentPhotoId);
        if (existingIdx != -1) {
          newIndex = existingIdx;
        } else {
          // Current photo was removed/deleted; safely stay within bounds
          newIndex = state.currentIndex % newPhotos.length;
        }
      } else {
        newIndex = 0;
      }

      final durationChanged =
          newSettings.slideDurationSeconds != state.settings.slideDurationSeconds;
      final autoplayChanged =
          newSettings.slideshowAutoplay != state.settings.slideshowAutoplay;
      final enabledChanged =
          newSettings.slideshowEnabled != state.settings.slideshowEnabled;
      final refreshIntervalChanged =
          newSettings.refreshIntervalSeconds != state.settings.refreshIntervalSeconds;

      state = state.copyWith(
        settings: newSettings,
        photos: newPhotos,
        currentIndex: newIndex,
        isBackgroundRefreshing: false,
        clearError: true, // clear any transient error
      );

      // Reconfigure rotation if timing or control settings changed
      if (durationChanged || autoplayChanged || enabledChanged) {
        _setupRotationTimer();
      }
      if (refreshIntervalChanged) {
        _setupPollingTimer();
      }
    } catch (e) {
      // Retain existing photos on network blip, show subtle error indicator
      state = state.copyWith(
        isBackgroundRefreshing: false,
        errorMessage: 'Network interrupted. Retrying...',
      );
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final displayProvider = StateNotifierProvider<DisplayNotifier, DisplayState>((ref) {
  return DisplayNotifier();
});
